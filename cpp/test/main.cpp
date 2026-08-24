#include <parsergen/parsergen.hpp>

#include <cassert>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <map>

static int pass_count = 0;
static int fail_count = 0;

static void check(const std::string &name, bool cond)
{
	if (cond) {
		++pass_count;
	}
	else {
		++fail_count;
		std::cout << "[FAIL] " << name << "\n";
	}
}

static pg::lexical_t make_json_lex()
{
	return {
		{"id", "^[a-z]+$"},
		{"num", "^[0-9]+\\.?([0-9]+)?$"},
		{"str", "^(\"|\"([^\"]|\\\\\")*\"?)$"},
		{"sig", "^(:|,|\\[|\\]|\\{|\\})$"},
		{"ign", "^\\s+$"},
		{"err", "^\"$"},
	};
}

static pg::syntax_map_t make_json_stx()
{
	using namespace pg;
	using namespace pg::syntax;
	syntax_map_t stx;
	stx["begin"] = {cond_or({{ref("object")}, {ref("array")}})};
	stx["object"] = {term("{"), optional({ref("members")}), term("}")};
	stx["members"] = {ref("pair"), repeat({term(","), ref("pair")})};
	stx["pair"] = {token("str"), term(":"), ref("value")};
	stx["array"] = {term("["), optional({ref("elements")}), term("]")};
	stx["elements"] = {ref("value"), repeat({term(","), ref("value")})};
	stx["value"] = {cond_or({
			{token("str")},
			{token("num")},
			{ref("object")},
			{ref("array")},
			{term("true")},
			{term("false")},
			{term("null")},
		})
	};
	return stx;
}

static void test_json_parse()
{
	std::cout << "--- JSON parse ---\n";
	pg::grammar gram;
	gram.lex = make_json_lex();
	gram.stx = make_json_stx();

	pg::generator gen;
	gen.show_prompt = false;
	gen.add_grammar("json", std::move(gram));

	check("valid json", gen.from_string("json", R"({"a": 1, "b": [2, 3]})"));
	check("ast not null", gen.ast() != nullptr);
	check("ast root", gen.ast() && gen.ast()->root == "begin");

	check("invalid json", !gen.from_string("json", R"({"a": })"));
	check("empty obj", gen.from_string("json", "{}"));
	check("empty arr", gen.from_string("json", "[]"));
	check("nested", gen.from_string("json", R"({"a": {"b": [1, "x", null]}})"));
}

static void test_tiny_parse()
{
	std::cout << "--- TINY parse ---\n";
	using namespace pg;
	using namespace pg::syntax;

	grammar gram;
	gram.lex = {
		{"id", "^[A-Za-z_]\\w*$"},
		{"num", "^[0-9]+$"},
		{"sig", "^(\\+|-|\\*|/|=|\\(|\\)|;)$"},
		{"ign", "^\\s+$"},
		{"err", "^:$"},
	};
	gram.stx["begin"] = {ref("stmts")};
	gram.stx["stmts"] = {ref("statement"), repeat({term(";"), ref("statement")}),
	                     optional({term(";")})
	                    };
	gram.stx["statement"] = {cond_or({{ref("assign-stmt")}})};
	gram.stx["assign-stmt"] = {token("id"), term("="), ref("expr")};
	gram.stx["expr"] = {ref("term"),
	repeat({cond_or({{term("+")}, {term("-")}}), ref("term")})
	};
	gram.stx["term"] = {ref("fact"),
	repeat({cond_or({{term("*")}, {term("/")}}), ref("fact")})
	};
	gram.stx["fact"] = {cond_or({
			{term("("), ref("expr"), term(")")},
			{token("num")},
			{token("id")},
		})
	};
	gram.stx["ignore"] = {repeat({token("ign")})};

	generator gen;
	gen.show_prompt = false;
	gen.add_grammar("tiny", std::move(gram));

	check("assign", gen.from_string("tiny", "x = 1 + 2 * 3;"));
	check("paren", gen.from_string("tiny", "y = (1 + 2) * 3;"));
	check("multi stmt", gen.from_string("tiny", "x = 1; y = 2;"));
	check("fail", !gen.from_string("tiny", "= 1;"));
}

static void test_empty_input()
{
	std::cout << "--- empty input ---\n";
	using namespace pg;
	using namespace pg::syntax;

	grammar gram;
	gram.lex = {{"id", "^[a-z]+$"}, {"ign", "^\\s+$"}};
	gram.stx["begin"] = {optional({token("id")})};
	gram.stx["ignore"] = {repeat({token("ign")})};

	generator gen;
	gen.show_prompt = false;
	gen.add_grammar("test", std::move(gram));

	check("empty optional", gen.from_string("test", ""));
}

static void test_error_recovery()
{
	std::cout << "--- error recovery ---\n";
	using namespace pg;
	using namespace pg::syntax;

	syntax_map_t stx;
	stx["begin"] = {repeat({ref("stmt")})};
	stx["stmt"] = {token("id"), term("="), token("num"), token("endl")};
	stx["ignore"] = {repeat({token("endl")})};

	lexer_type lexer;
	lexical_t lex = {
		{"id", "^[a-z]+$"},
		{"num", "^[0-9]+$"},
		{"sig", "^(=)$"},
		{"endl", "^\\n+$"},
		{"ign", "^[ \\t]+$"},
	};
	auto tokens = lexer.run(lex, "x = 1\ny = \nz = 3\n");

	recovering_parser_type parser;
	parser.init(stx);
	bool ok = parser.parse_with_recovery(tokens);
	check("recovery has errors", !ok);
	check("recovery found errors", !parser.get_all_errors().empty());
}

static void test_recovery_success()
{
	std::cout << "--- error recovery (success) ---\n";
	using namespace pg;
	using namespace pg::syntax;

	syntax_map_t stx;
	stx["begin"] = {repeat({ref("stmt")})};
	stx["stmt"] = {token("id"), term("="), token("num"), token("endl")};
	stx["ignore"] = {repeat({token("endl")})};

	lexer_type lexer;
	lexical_t lex = {
		{"id", "^[a-z]+$"},
		{"num", "^[0-9]+$"},
		{"sig", "^(=)$"},
		{"endl", "^\\n+$"},
		{"ign", "^[ \\t]+$"},
		{"bad", "^@$"},
	};
	// First stmt is broken ("a @"), the rest recovers at the next endl sync point
	auto tokens = lexer.run(lex, "x = 1\na @\ny = 2\nz = 3\n");

	recovering_parser_type parser;
	parser.init(stx);
	bool ok = parser.parse_with_recovery(tokens);
	check("recovery ok", ok);
	check("recovery recorded errors", !parser.get_all_errors().empty());
	auto ast = parser.production();
	check("recovery ast not null", ast != nullptr);
	check("recovery ast root", ast && ast->root == "begin");
}

static void test_from_file_deterministic()
{
	std::cout << "--- from_file deterministic ---\n";
	using namespace pg;
	using namespace pg::syntax;

	// Both languages match any path (".*"); "a" is the lexicographic winner
	grammar gram_a;
	gram_a.ext = ".*";
	gram_a.lex = {{"id", "^[a-z]+$"}, {"ign", "^[ \\t\\n]+$"}};
	gram_a.stx["begin"] = {token("id")};

	grammar gram_b;
	gram_b.ext = ".*";
	gram_b.lex = {{"id", "^[a-z]+$"}, {"ign", "^[ \\t\\n]+$"}};
	gram_b.stx["begin"] = {token("id"), token("id")};

	// Sanity: "b" cannot parse a single-id file, "a" can
	generator alone;
	alone.show_prompt = false;
	alone.add_grammar("b", grammar(gram_b));
	check("premise: b fails on single id", !alone.from_string("b", "x"));

	std::ofstream ofs("det_test.tmp");
	ofs << "x\n";
	ofs.close();

	generator gen;
	gen.show_prompt = false;
	gen.add_grammar("b", std::move(gram_b));
	gen.add_grammar("a", std::move(gram_a));

	bool ok1 = gen.from_file("det_test.tmp");
	bool ok2 = gen.from_file("det_test.tmp");
	bool ok3 = gen.from_file("det_test.tmp");
	std::remove("det_test.tmp");

	check("from_file picks smallest lang", ok1);
	check("from_file deterministic (2nd)", ok2);
	check("from_file deterministic (3rd)", ok3);
	check("from_file ast single id", gen.ast() && gen.ast()->nodes.size() == 1);
}

static void test_repeat_epsilon_eof()
{
	std::cout << "--- repeat epsilon eof ---\n";
	using namespace pg;
	using namespace pg::syntax;

	// A repeat whose item may match epsilon (an optional) must terminate at
	// EOF: the repeat boot set contains epsilon, so a progress-less iteration
	// would make predict() accept forever.
	grammar gram;
	gram.lex = {{"id", "^[a-z]+$"}, {"ign", "^[ \\t\\n]+$"}};
	gram.stx["begin"] = {repeat({optional({token("id")})})};

	generator gen;
	gen.show_prompt = false;
	gen.add_grammar("rep", std::move(gram));

	check("repeat epsilon item at eof", gen.from_string("rep", "x"));
	check("repeat epsilon item at eof (empty input)", gen.from_string("rep", ""));
}

int main()
{
	std::cout << "=== ParserGen C++ Tests ===\n\n";

	test_json_parse();
	test_tiny_parse();
	test_empty_input();
	test_error_recovery();
	test_recovery_success();
	test_from_file_deterministic();
	test_repeat_epsilon_eof();

	std::cout << "\nPassed: " << pass_count << ", Failed: " << fail_count << "\n";
	return fail_count > 0 ? 1 : 0;
}
