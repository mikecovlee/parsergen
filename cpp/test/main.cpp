#include <parsergen/parsergen.hpp>

#include <cassert>
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

int main()
{
	std::cout << "=== ParserGen C++ Tests ===\n\n";

	test_json_parse();
	test_tiny_parse();
	test_empty_input();
	test_error_recovery();

	std::cout << "\nPassed: " << pass_count << ", Failed: " << fail_count << "\n";
	return fail_count > 0 ? 1 : 0;
}
