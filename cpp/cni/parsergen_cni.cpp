#include <covscript/cni.hpp>
#include <covscript/dll.hpp>

#include <parsergen/parsergen.hpp>
#include <parsergen/pcre2_inline.hpp>

using syntax_t    = std::shared_ptr<pg::syntax_impl>;
using grammar_t   = std::shared_ptr<pg::grammar>;
using token_t     = std::shared_ptr<pg::token_type>;
using lexerr_t    = std::shared_ptr<pg::lex_error>;
using tree_t      = std::shared_ptr<pg::syntax_tree>;
using perr_t      = std::shared_ptr<pg::parse_error>;
using lexer_t     = std::shared_ptr<pg::lexer_type>;
using parser_t    = std::shared_ptr<pg::parser_type>;
using rparser_t   = std::shared_ptr<pg::recovering_parser_type>;
using generator_t = std::shared_ptr<pg::generator>;

static cs::namespace_t syntax_impl_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t grammar_ext                = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t token_type_ext             = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t lex_error_ext              = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t syntax_tree_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t parse_error_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t lexer_type_ext             = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t parser_type_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t recovering_parser_type_ext = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t generator_ext              = cs::make_shared_namespace<cs::name_space>();

namespace cs_impl {
	template <> cs::namespace_t &get_ext<syntax_t>()    { return syntax_impl_ext; }
	template <> cs::namespace_t &get_ext<grammar_t>()   { return grammar_ext; }
	template <> cs::namespace_t &get_ext<token_t>()     { return token_type_ext; }
	template <> cs::namespace_t &get_ext<lexerr_t>()    { return lex_error_ext; }
	template <> cs::namespace_t &get_ext<tree_t>()      { return syntax_tree_ext; }
	template <> cs::namespace_t &get_ext<perr_t>()      { return parse_error_ext; }
	template <> cs::namespace_t &get_ext<lexer_t>()     { return lexer_type_ext; }
	template <> cs::namespace_t &get_ext<parser_t>()    { return parser_type_ext; }
	template <> cs::namespace_t &get_ext<rparser_t>()   { return recovering_parser_type_ext; }
	template <> cs::namespace_t &get_ext<generator_t>() { return generator_ext; }

	template <> constexpr const char *get_name_of_type<syntax_t>()    { return "parsergen::syntax_impl"; }
	template <> constexpr const char *get_name_of_type<grammar_t>()   { return "parsergen::grammar"; }
	template <> constexpr const char *get_name_of_type<token_t>()     { return "parsergen::token_type"; }
	template <> constexpr const char *get_name_of_type<lexerr_t>()    { return "parsergen::lex_error"; }
	template <> constexpr const char *get_name_of_type<tree_t>()      { return "parsergen::syntax_tree"; }
	template <> constexpr const char *get_name_of_type<perr_t>()      { return "parsergen::parse_error"; }
	template <> constexpr const char *get_name_of_type<lexer_t>()     { return "parsergen::lexer_type"; }
	template <> constexpr const char *get_name_of_type<parser_t>()    { return "parsergen::parser_type"; }
	template <> constexpr const char *get_name_of_type<rparser_t>()   { return "parsergen::recovering_parser_type"; }
	template <> constexpr const char *get_name_of_type<generator_t>() { return "parsergen::generator"; }
} // namespace cs_impl

namespace parsergen_cni {
	using namespace cs;

	// ---- helpers ----

	static pg::syntax_seq to_syntax_seq(const array &arr)
	{
		pg::syntax_seq seq;
		for (auto &elem : arr)
			seq.push_back(elem.const_val<syntax_t>());
		return seq;
	}

	static cs::array tree_nodes_to_array(const pg::syntax_tree &tree)
	{
		cs::array arr;
		for (auto &node : tree.nodes) {
			if (auto *tok = std::get_if<pg::token_type>(&node)) {
				auto t = std::make_shared<pg::token_type>(*tok);
				arr.push_back(var::make<token_t>(std::move(t)));
			}
			else if (auto *sub = std::get_if<std::shared_ptr<pg::syntax_tree>>(&node)) {
				arr.push_back(var::make<tree_t>(*sub));
			}
		}
		return arr;
	}

	// ---- syntax:: factory functions ----

	syntax_t syntax_token(const string &data)
	{
		return pg::syntax::token(data);
	}

	syntax_t syntax_term(const string &data)
	{
		return pg::syntax::term(data);
	}

	syntax_t syntax_ref(const string &name)
	{
		return pg::syntax::ref(name);
	}

	static pg::syntax_seq args_to_seq(vector &args)
	{
		pg::syntax_seq seq;
		for (auto &elem : args)
			seq.push_back(elem.const_val<syntax_t>());
		return seq;
	}

	var variadic_nlook(vector &args)
	{
		return var::make<syntax_t>(pg::syntax::nlook(args_to_seq(args)));
	}

	var variadic_repeat(vector &args)
	{
		return var::make<syntax_t>(pg::syntax::repeat(args_to_seq(args)));
	}

	var variadic_optional(vector &args)
	{
		return var::make<syntax_t>(pg::syntax::optional(args_to_seq(args)));
	}

	var variadic_cond_or(vector &args)
	{
		std::vector<pg::syntax_seq> alternatives;
		for (auto &elem : args)
			alternatives.push_back(to_syntax_seq(elem.const_val<array>()));
		return var::make<syntax_t>(pg::syntax::cond_or(std::move(alternatives)));
	}

	static var make_variadic_cni(std::function<var(vector &)> fn)
	{
		return var::make_protect<callable>(callable(std::move(fn), callable::types::normal));
	}

	static var make_property_cni(std::function<var(vector &)> fn)
	{
		return var::make_protect<callable>(callable(std::move(fn), callable::types::member_visitor));
	}

	// ---- syntax_impl accessors ----

	numeric syntax_impl_type(const syntax_t &s)
	{
		return static_cast<int>(s->type);
	}

	var syntax_impl_data(const syntax_t &s)
	{
		switch (s->type) {
		case pg::syntax_type::token:
		case pg::syntax_type::term:
		case pg::syntax_type::ref:
			return var::make<string>(std::any_cast<std::string>(s->data));
		case pg::syntax_type::nlook:
		case pg::syntax_type::repeat:
		case pg::syntax_type::opt: {
			auto &seq = std::any_cast<pg::syntax_seq &>(s->data);
			array arr;
			for (auto &it : seq)
				arr.push_back(var::make<syntax_t>(it));
			return var::make<array>(std::move(arr));
		}
		case pg::syntax_type::cond: {
			auto &seq = std::any_cast<pg::syntax_seq &>(s->data);
			array arr;
			for (auto &it : seq)
				arr.push_back(var::make<syntax_t>(it));
			return var::make<array>(std::move(arr));
		}
		default:
			return var::make<array>(array{});
		}
	}

	// ---- grammar ----

	var make_grammar_var()
	{
		return var::make<grammar_t>(std::make_shared<pg::grammar>());
	}

	grammar_t make_grammar_from(const string &ext, const hash_map &lex, const hash_map &stx)
	{
		auto g = std::make_shared<pg::grammar>();
		g->ext = ext;
		for (auto &[key, val] : lex) {
			string name = key.const_val<string>();
			auto reg = val.const_val<pcre2_regex_t>();
			g->lex[name] = reg->pattern;
		}
		for (auto &[key, val] : stx) {
			string name = key.const_val<string>();
			g->stx[name] = to_syntax_seq(val.const_val<array>());
		}
		return g;
	}

	var make_lexer_var()
	{
		return var::make<lexer_t>(std::make_shared<pg::lexer_type>());
	}

	var make_parser_var()
	{
		return var::make<parser_t>(std::make_shared<pg::parser_type>());
	}

	var make_rparser_var()
	{
		return var::make<rparser_t>(std::make_shared<pg::recovering_parser_type>());
	}

	var make_generator_var()
	{
		return var::make<generator_t>(std::make_shared<pg::generator>());
	}

	var grammar_ext_fn(vector &args)
	{
		auto g = args.at(0).const_val<grammar_t>();
		if (args.size() > 1) {
			g->ext = args.at(1).const_val<string>();
			return args.at(0);
		}
		return var::make<string>(g->ext);
	}

	var grammar_lex_fn(vector &args)
	{
		auto g = args.at(0).const_val<grammar_t>();
		if (args.size() > 1) {
			auto &lex = args.at(1).const_val<hash_map>();
			g->lex.clear();
			for (auto &[key, val] : lex) {
				string name = key.const_val<string>();
				auto reg = val.const_val<pcre2_regex_t>();
				g->lex[name] = reg->pattern;
			}
			return args.at(0);
		}
		hash_map result;
		for (auto &[name, pattern] : g->lex)
			result[var::make<string>(name)] = var::make<string>(pattern);
		return var::make<hash_map>(std::move(result));
	}

	var grammar_stx_fn(vector &args)
	{
		auto g = args.at(0).const_val<grammar_t>();
		if (args.size() > 1) {
			auto &stx = args.at(1).const_val<hash_map>();
			g->stx.clear();
			for (auto &[key, val] : stx) {
				string name = key.const_val<string>();
				g->stx[name] = to_syntax_seq(val.const_val<array>());
			}
			return args.at(0);
		}
		hash_map result;
		for (auto &[name, seq] : g->stx) {
			array arr;
			for (auto &it : seq)
				arr.push_back(var::make<syntax_t>(it));
			result[var::make<string>(name)] = var::make<array>(std::move(arr));
		}
		return var::make<hash_map>(std::move(result));
	}

	// ---- token_type ----

	array token_pos(const token_t &t) { return {t->pos[0], t->pos[1]}; }
	string token_type_name(const token_t &t) { return t->type; }
	string token_data(const token_t &t) { return t->data; }

	// ---- lex_error ----

	string lexerr_text(const lexerr_t &e) { return e->text; }
	array lexerr_pos(const lexerr_t &e) { return {e->pos[0], e->pos[1]}; }

	// ---- syntax_tree ----

	string tree_root(const tree_t &t) { return t->root; }
	array tree_nodes(const tree_t &t) { return tree_nodes_to_array(*t); }

	// ---- parse_error ----

	numeric perr_cursor(const perr_t &e) { return e->cursor; }
	string perr_text(const perr_t &e) { return e->text; }
	array perr_pos(const perr_t &e) { return {e->pos[0], e->pos[1]}; }

	// ---- lexer_type ----

	array lexer_run(lexer_t &lex, const hash_map &lexical, const string &text)
	{
		pg::lexical_t cxx_lex;
		for (auto &[key, val] : lexical) {
			string name = key.const_val<string>();
			try {
				auto reg = val.const_val<pcre2_regex_t>();
				cxx_lex[name] = reg->pattern;
			}
			catch (...) {}
		}
		auto tokens = lex->run(cxx_lex, text);
		array arr;
		for (auto &tok : tokens)
			arr.push_back(var::make<token_t>(std::make_shared<pg::token_type>(tok)));
		return arr;
	}

	array lexer_error_log(const lexer_t &lex)
	{
		array arr;
		for (auto &e : lex->error_log)
			arr.push_back(var::make<lexerr_t>(std::make_shared<pg::lex_error>(e)));
		return arr;
	}

	// ---- parser_type ----

	void parser_init(parser_t &p, const hash_map &stx)
	{
		auto gram = std::make_shared<pg::syntax_map_t>();
		for (auto &[key, val] : stx) {
			string name = key.const_val<string>();
			(*gram)[name] = to_syntax_seq(val.const_val<array>());
		}
		p->init(*gram);
	}

	bool parser_run(parser_t &p, const hash_map &stx, const array &tokens)
	{
		auto gram = std::make_shared<pg::syntax_map_t>();
		for (auto &[key, val] : stx) {
			string name = key.const_val<string>();
			(*gram)[name] = to_syntax_seq(val.const_val<array>());
		}
		pg::token_list_t tok_list;
		for (auto &t : tokens)
			tok_list.push_back(*t.const_val<token_t>());
		return p->run(*gram, tok_list);
	}

	tree_t parser_production(parser_t &p)
	{
		return p->production();
	}

	array parser_get_log(parser_t &p, numeric n)
	{
		auto errors = p->get_log(n.as_integer());
		array arr;
		for (auto &e : errors)
			arr.push_back(var::make<perr_t>(std::make_shared<pg::parse_error>(e)));
		return arr;
	}

	var parser_log(vector &args)
	{
		auto p = args.at(0).const_val<parser_t>();
		if (args.size() > 1) { p->log = args.at(1).const_val<bool>(); return args.at(0); }
		return var::make<bool>(p->log);
	}

	// ---- recovering_parser_type ----

	void rparser_init(rparser_t &p, const hash_map &stx)
	{
		auto gram = std::make_shared<pg::syntax_map_t>();
		for (auto &[key, val] : stx) {
			string name = key.const_val<string>();
			(*gram)[name] = to_syntax_seq(val.const_val<array>());
		}
		p->init(*gram);
	}

	bool rparser_parse_with_recovery(rparser_t &p, const array &tokens)
	{
		pg::token_list_t tok_list;
		for (auto &t : tokens)
			tok_list.push_back(*t.const_val<token_t>());
		return p->parse_with_recovery(tok_list);
	}

	array rparser_get_all_errors(rparser_t &p)
	{
		array arr;
		for (auto &e : p->get_all_errors())
			arr.push_back(var::make<perr_t>(std::make_shared<pg::parse_error>(e)));
		return arr;
	}

	// ---- generator ----

	void gen_add_grammar(generator_t &g, const string &lang, const grammar_t &gram)
	{
		g->add_grammar(lang, *gram);
	}

	bool gen_from_string(generator_t &g, const string &lang, const string &str)
	{
		return g->from_string(lang, str);
	}

	bool gen_from_file(generator_t &g, const string &path)
	{
		return g->from_file(path);
	}

	tree_t gen_get_ast(generator_t &g)
	{
		return g->ast();
	}

	array gen_get_errors(generator_t &g)
	{
		auto errors = g->get_errors();
		array arr;
		for (auto &e : errors)
			arr.push_back(var::make<perr_t>(std::make_shared<pg::parse_error>(e)));
		return arr;
	}

	bool gen_get_stop_on_error(generator_t &g) { return g->stop_on_error; }
	bool gen_get_show_prompt(generator_t &g) { return g->show_prompt; }
	bool gen_get_enable_log(generator_t &g) { return g->enable_log; }
	string gen_get_file_path(generator_t &g) { return g->path(); }

	var gen_stop_on_error(vector &args)
	{
		auto g = args.at(0).const_val<generator_t>();
		if (args.size() > 1) { g->stop_on_error = args.at(1).const_val<bool>(); return args.at(0); }
		return var::make<bool>(g->stop_on_error);
	}

	var gen_show_prompt(vector &args)
	{
		auto g = args.at(0).const_val<generator_t>();
		if (args.size() > 1) { g->show_prompt = args.at(1).const_val<bool>(); return args.at(0); }
		return var::make<bool>(g->show_prompt);
	}

	var gen_enable_log(vector &args)
	{
		auto g = args.at(0).const_val<generator_t>();
		if (args.size() > 1) { g->enable_log = args.at(1).const_val<bool>(); return args.at(0); }
		return var::make<bool>(g->enable_log);
	}

	void gen_set_stop_on_error(generator_t &g, bool v) { g->stop_on_error = v; }
	void gen_set_show_prompt(generator_t &g, bool v) { g->show_prompt = v; }
	void gen_set_enable_log(generator_t &g, bool v) { g->enable_log = v; }

	array gen_get_code_buff(generator_t &g)
	{
		array arr;
		for (auto &line : g->code())
			arr.push_back(var::make<string>(line));
		return arr;
	}

	// ---- utility functions ----

	void print_error(const string &file, const array &code, const array &err)
	{
		std::vector<std::string> code_vec;
		for (auto &line : code)
			code_vec.push_back(line.const_val<string>());
		std::vector<pg::parse_error> err_vec;
		for (auto &e : err) {
			auto pe = e.const_val<perr_t>();
			err_vec.push_back(*pe);
		}
		pg::print_error(file, code_vec, err_vec);
	}

	void print_ast(const tree_t &tree)
	{
		pg::print_ast(tree);
	}

	// ---- init ----

	void init(name_space *ns)
	{
		// syntax_type constants
		auto syntax_type_ns = make_shared_namespace<name_space>();
		(*syntax_type_ns)
		    .add_var("token", var::make_constant<numeric>(1))
		    .add_var("term", var::make_constant<numeric>(2))
		    .add_var("ref", var::make_constant<numeric>(3))
		    .add_var("nlook", var::make_constant<numeric>(4))
		    .add_var("repeat", var::make_constant<numeric>(5))
		    .add_var("opt", var::make_constant<numeric>(6))
		    .add_var("cond", var::make_constant<numeric>(7))
		    .add_var("cond_p", var::make_constant<numeric>(8));

		// parse_state constants
		auto parse_state_ns = make_shared_namespace<name_space>();
		(*parse_state_ns)
		    .add_var("accept", var::make_constant<numeric>(2))
		    .add_var("reject", var::make_constant<numeric>(1))
		    .add_var("eof", var::make_constant<numeric>(0));

		// syntax namespace
		auto syntax_ns = make_shared_namespace<name_space>();
		(*syntax_ns)
		    .add_var("token", make_cni(syntax_token))
		    .add_var("term", make_cni(syntax_term))
		    .add_var("ref", make_cni(syntax_ref))
		    .add_var("nlook", make_variadic_cni(variadic_nlook))
		    .add_var("repeat", make_variadic_cni(variadic_repeat))
		    .add_var("optional", make_variadic_cni(variadic_optional))
		    .add_var("cond_or", make_variadic_cni(variadic_cond_or));

		// root namespace
		(*ns)
		    .add_var("syntax_type", make_namespace(syntax_type_ns))
		    .add_var("parse_state", make_namespace(parse_state_ns))
		    .add_var("syntax", make_namespace(syntax_ns))
		    .add_var("grammar", make_cni(make_grammar_var))
		    .add_var("make_grammar_from", make_cni(make_grammar_from))
		    .add_var("lexer_type", make_cni(make_lexer_var))
		    .add_var("parser_type", make_cni(make_parser_var))
		    .add_var("recovering_parser_type", make_cni(make_rparser_var))
		    .add_var("generator", make_cni(make_generator_var))
		    .add_var("print_error", make_cni(print_error))
		    .add_var("print_ast", make_cni(print_ast));

		// syntax_impl type extensions
		(*syntax_impl_ext)
		    .add_var("type", make_cni(syntax_impl_type))
		    .add_var("data", make_cni(syntax_impl_data));

		// grammar type extensions
		(*grammar_ext)
		    .add_var("ext", make_property_cni(grammar_ext_fn))
		    .add_var("lex", make_property_cni(grammar_lex_fn))
		    .add_var("stx", make_property_cni(grammar_stx_fn));

		// token_type extensions
		(*token_type_ext)
		    .add_var("pos", make_cni(token_pos))
		    .add_var("type", make_cni(token_type_name))
		    .add_var("data", make_cni(token_data));

		// lex_error extensions
		(*lex_error_ext)
		    .add_var("text", make_cni(lexerr_text))
		    .add_var("pos", make_cni(lexerr_pos));

		// syntax_tree extensions
		(*syntax_tree_ext)
		    .add_var("root", make_cni(tree_root))
		    .add_var("nodes", make_cni(tree_nodes));

		// parse_error extensions
		(*parse_error_ext)
		    .add_var("cursor", make_cni(perr_cursor))
		    .add_var("text", make_cni(perr_text))
		    .add_var("pos", make_cni(perr_pos));

		// lexer_type extensions
		(*lexer_type_ext)
		    .add_var("run", make_cni(lexer_run))
		    .add_var("error_log", make_cni(lexer_error_log));

		// parser_type extensions
		(*parser_type_ext)
		    .add_var("init", make_cni(parser_init))
		    .add_var("run", make_cni(parser_run))
		    .add_var("production", make_cni(parser_production))
		    .add_var("get_log", make_cni(parser_get_log))
		    .add_var("log", make_property_cni(parser_log));

		// recovering_parser_type extensions
		(*recovering_parser_type_ext)
		    .add_var("init", make_cni(rparser_init))
		    .add_var("parse_with_recovery", make_cni(rparser_parse_with_recovery))
		    .add_var("get_all_errors", make_cni(rparser_get_all_errors));

		// generator extensions
		(*generator_ext)
		    .add_var("add_grammar", make_cni(gen_add_grammar))
		    .add_var("from_string", make_cni(gen_from_string))
		    .add_var("from_file", make_cni(gen_from_file))
		    .add_var("ast", make_cni(gen_get_ast))
		    .add_var("get_errors", make_cni(gen_get_errors))
		    .add_var("stop_on_error", make_variadic_cni(gen_stop_on_error))
		    .add_var("set_stop_on_error", make_cni(gen_set_stop_on_error))
		    .add_var("show_prompt", make_variadic_cni(gen_show_prompt))
		    .add_var("set_show_prompt", make_cni(gen_set_show_prompt))
		    .add_var("enable_log", make_variadic_cni(gen_enable_log))
		    .add_var("set_enable_log", make_cni(gen_set_enable_log))
		    .add_var("file_path", make_cni(gen_get_file_path))
		    .add_var("code_buff", make_cni(gen_get_code_buff));
	}
} // namespace parsergen_cni

void cs_extension_main(cs::name_space *ns)
{
	parsergen_cni::init(ns);
}
