#include <covscript/cni.hpp>
#include <covscript/dll.hpp>
#include <typeindex>

#include <parsergen/parsergen.hpp>

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

struct partial_parser_wrapper {
	pg::partial_parser_type parser;
	pg::token_list_t token_buff;
	pg::token_list_t pending_tokens;
	cs::var eof_hook;
	bool has_hook = false;
};
using pparser_wrapper_t = std::shared_ptr<partial_parser_wrapper>;

static cs::namespace_t syntax_impl_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t grammar_ext                = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t token_type_ext             = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t lex_error_ext              = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t syntax_tree_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t parse_error_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t lexer_type_ext             = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t parser_type_ext            = cs::make_shared_namespace<cs::name_space>();
static cs::namespace_t partial_parser_type_ext    = cs::make_shared_namespace<cs::name_space>();
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
	template <> cs::namespace_t &get_ext<pparser_wrapper_t>() { return partial_parser_type_ext; }
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
	template <> constexpr const char *get_name_of_type<pparser_wrapper_t>() { return "parsergen::partial_parser_type"; }
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
		case pg::syntax_type::cond:
		case pg::syntax_type::cond_p: {
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
			g->lex[name] = val.const_val<string>();
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
				g->lex[name] = val.const_val<string>();
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

	token_t make_token(const array &pos, const string &type, const string &data)
	{
		auto t = std::make_shared<pg::token_type>();
		t->pos = {static_cast<std::size_t>(pos.at(0).const_val<numeric>().as_integer()),
		          static_cast<std::size_t>(pos.at(1).const_val<numeric>().as_integer())};
		t->type = type;
		t->data = data;
		return t;
	}

	array token_pos(const token_t &t) { return {numeric(t->pos[0]), numeric(t->pos[1])}; }
	string token_type_name(const token_t &t) { return t->type; }
	string token_data(const token_t &t) { return t->data; }

	// ---- lex_error ----

	string lexerr_text(const lexerr_t &e) { return e->text; }
	array lexerr_pos(const lexerr_t &e) { return {numeric(e->pos[0]), numeric(e->pos[1])}; }

	// ---- syntax_tree ----

	string tree_root(const tree_t &t)
	{
		if (!t)
			throw cs::lang_error("Null pointer accessed.");
		return t->root;
	}

	array tree_nodes(const tree_t &t)
	{
		if (!t)
			throw cs::lang_error("Null pointer accessed.");
		return tree_nodes_to_array(*t);
	}

	// ---- parse_error ----

	numeric perr_cursor(const perr_t &e) { return e->cursor; }
	string perr_text(const perr_t &e) { return e->text; }
	array perr_pos(const perr_t &e) { return {numeric(e->pos[0]), numeric(e->pos[1])}; }

	// ---- lexer_type ----

	array lexer_run(lexer_t &lex, const hash_map &lexical, const string &text)
	{
		pg::lexical_t cxx_lex;
		for (auto &[key, val] : lexical) {
			string name = key.const_val<string>();
			cxx_lex[name] = val.const_val<string>();
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

	var parser_production(parser_t &p)
	{
		auto prod = p->production();
		if (!prod)
			return null_pointer;
		return var::make<tree_t>(std::move(prod));
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

	// ---- partial_parser_type ----

	var make_pparser_var()
	{
		return var::make<pparser_wrapper_t>(std::make_shared<partial_parser_wrapper>());
	}

	bool pparser_run(pparser_wrapper_t &w, const hash_map &stx, const array &tokens)
	{
		pg::syntax_map_t gram;
		for (auto &[key, val] : stx) {
			string name = key.const_val<string>();
			gram[name] = to_syntax_seq(val.const_val<array>());
		}
		w->token_buff.clear();
		for (auto &t : tokens)
			w->token_buff.push_back(*t.const_val<token_t>());

		// Always install the wrapper so pending_tokens are drained on every
		// EOF retry (parity with the CovScript impl where push_tokens writes
		// the token stream directly). The user hook is only invoked when set.
		std::weak_ptr<partial_parser_wrapper> weak_w = w;
		w->parser.on_eof_hook = [weak_w](pg::partial_parser_type &) {
			auto w = weak_w.lock();
			if (!w) return;
			w->pending_tokens.clear();
			if (w->has_hook)
				cs::invoke(w->eof_hook, var::make<pparser_wrapper_t>(w));
			for (auto &t : w->pending_tokens)
				w->token_buff.push_back(std::move(t));
			w->pending_tokens.clear();
		};
		return w->parser.run(gram, w->token_buff);
	}

	var pparser_production(pparser_wrapper_t &w)
	{
		auto prod = w->parser.production();
		if (!prod)
			return null_pointer;
		return var::make<tree_t>(std::move(prod));
	}

	array pparser_get_log(pparser_wrapper_t &w, numeric n)
	{
		auto errors = w->parser.get_log(n.as_integer());
		array arr;
		for (auto &e : errors)
			arr.push_back(var::make<perr_t>(std::make_shared<pg::parse_error>(e)));
		return arr;
	}

	var pparser_log(vector &args)
	{
		auto w = args.at(0).const_val<pparser_wrapper_t>();
		if (args.size() > 1) { w->parser.log = args.at(1).const_val<bool>(); return args.at(0); }
		return var::make<bool>(w->parser.log);
	}

	void pparser_set_eof_hook(pparser_wrapper_t &w, const var &hook)
	{
		w->eof_hook = hook;
		w->has_hook = true;
	}

	void pparser_push_token(pparser_wrapper_t &w, const token_t &tok)
	{
		w->pending_tokens.push_back(*tok);
	}

	void pparser_push_tokens(pparser_wrapper_t &w, const array &tokens)
	{
		for (auto &t : tokens)
			w->pending_tokens.push_back(*t.const_val<token_t>());
	}

	// Parity with the CovScript impl: set_eof_hook(null) clears the hook
	void pparser_clear_eof_hook(pparser_wrapper_t &w)
	{
		w->eof_hook = null_pointer;
		w->has_hook = false;
	}

	// ---- lex_error factory ----

	lexerr_t make_lex_error(const string &text, const array &pos)
	{
		auto e = std::make_shared<pg::lex_error>();
		e->text = text;
		e->pos = {static_cast<std::size_t>(pos.at(0).const_val<numeric>().as_integer()),
		          static_cast<std::size_t>(pos.at(1).const_val<numeric>().as_integer())};
		return e;
	}

	// ---- generator ----

	bool gen_from_string(generator_t &g, const string &lang, const string &str)
	{
		return g->from_string(lang, str);
	}

	bool gen_from_file(generator_t &g, const string &path)
	{
		return g->from_file(path);
	}

	var gen_get_ast(generator_t &g)
	{
		auto ast = g->ast();
		if (!ast)
			return null_pointer;
		return var::make<tree_t>(std::move(ast));
	}

	array gen_get_errors(generator_t &g)
	{
		auto errors = g->get_errors();
		array arr;
		for (auto &e : errors)
			arr.push_back(var::make<perr_t>(std::make_shared<pg::parse_error>(e)));
		return arr;
	}

	string gen_get_file_path(generator_t &g) { return g->path(); }

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

	void gen_add_language(generator_t &g, const string &lang, const string &coding, const grammar_t &gram)
	{
		g->add_language(lang, coding, *gram);
	}

	var gen_lex_string(generator_t &g, const string &lang, const string &text, numeric start_line)
	{
		auto tokens = g->lex_string(lang, text, start_line.as_integer());
		if (!tokens)
			return null_pointer;
		array arr;
		for (auto &tok : *tokens)
			arr.push_back(var::make<token_t>(std::make_shared<pg::token_type>(tok)));
		return var::make<array>(std::move(arr));
	}

	array gen_get_lex_errors(generator_t &g)
	{
		auto errors = g->get_lex_errors();
		array arr;
		for (auto &e : errors)
			arr.push_back(var::make<lexerr_t>(std::make_shared<pg::lex_error>(e)));
		return arr;
	}

	array gen_get_tokens(generator_t &g)
	{
		array arr;
		for (auto &tok : g->tokens())
			arr.push_back(var::make<token_t>(std::make_shared<pg::token_type>(tok)));
		return arr;
	}

	bool gen_from_stream(generator_t &g, const string &lang, const cs::istream &stream)
	{
		return g->from_stream(lang, *stream);
	}

	// ---- lex_error setters ----

	void lexerr_set_text(lexerr_t &e, const string &text) { e->text = text; }
	void lexerr_set_pos(lexerr_t &e, const array &pos)
	{
		e->pos = {static_cast<std::size_t>(pos.at(0).const_val<numeric>().as_integer()),
		          static_cast<std::size_t>(pos.at(1).const_val<numeric>().as_integer())};
	}

	// ---- utility functions ----

	void print_error(const string &file, const array &code, const array &err)
	{
		std::vector<std::string> code_vec;
		for (auto &line : code)
			code_vec.push_back(line.const_val<string>());
		std::vector<pg::parse_error> err_vec;
		for (auto &e : err) {
			pg::parse_error pe;
			if (e.type() == typeid(lexerr_t)) {
				auto le = e.const_val<lexerr_t>();
				pe.text = le->text;
				pe.pos = le->pos;
			}
			else {
				auto p = e.const_val<perr_t>();
				pe = *p;
			}
			err_vec.push_back(pe);
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
	    .add_var("grammar", var::make_constant<type_t>(
	        std::function<var()>([]() { return make_grammar_var(); }),
	        type_id(typeid(grammar_t)), grammar_ext))
	    .add_var("make_grammar_from", make_cni(make_grammar_from))
	    .add_var("make_token", make_cni(make_token))
	    .add_var("make_lex_error", make_cni(make_lex_error))
	    .add_var("lexer_type", var::make_constant<type_t>(
	        std::function<var()>([]() { return make_lexer_var(); }),
	        type_id(typeid(lexer_t)), lexer_type_ext))
	    .add_var("parser_type", var::make_constant<type_t>(
	        std::function<var()>([]() { return make_parser_var(); }),
	        type_id(typeid(parser_t)), parser_type_ext))
	    .add_var("partial_parser_type", var::make_constant<type_t>(
	        std::function<var()>([]() { return make_pparser_var(); }),
	        type_id(typeid(pparser_wrapper_t)), partial_parser_type_ext))
	    .add_var("recovering_parser_type", var::make_constant<type_t>(
	        std::function<var()>([]() { return make_rparser_var(); }),
	        type_id(typeid(rparser_t)), recovering_parser_type_ext))
	    .add_var("generator", var::make_constant<type_t>(
	        std::function<var()>([]() { return make_generator_var(); }),
	        type_id(typeid(generator_t)), generator_ext))
	    .add_var("print_error", make_cni(print_error))
	    .add_var("print_ast", make_cni(print_ast))
	    // syntax_tree / token_type are registered as instances, not constructible
	    // types: scripts only use them as `typeid` tokens
	    // (`typeid it == typeid parsergen.syntax_tree`), never to construct values
	    .add_var("syntax_tree", var::make<tree_t>(std::make_shared<pg::syntax_tree>()))
	    .add_var("token_type", var::make<token_t>(std::make_shared<pg::token_type>()))
	    .add_var("lex_error", var::make_constant<type_t>(
	        std::function<var()>([]() { return var::make<lexerr_t>(std::make_shared<pg::lex_error>()); }),
	        type_id(typeid(lexerr_t)), lex_error_ext));

		// syntax_impl type extensions
		(*syntax_impl_ext)
		    .add_var("type", make_cni(syntax_impl_type, callable::types::member_visitor))
		    .add_var("data", make_cni(syntax_impl_data, callable::types::member_visitor));

		// grammar type extensions
		(*grammar_ext)
		    .add_var("ext", make_property_cni(grammar_ext_fn))
		    .add_var("lex", make_property_cni(grammar_lex_fn))
		    .add_var("stx", make_property_cni(grammar_stx_fn));

		// token_type extensions
		(*token_type_ext)
		    .add_var("pos", make_cni(token_pos, callable::types::member_visitor))
		    .add_var("type", make_cni(token_type_name, callable::types::member_visitor))
		    .add_var("data", make_cni(token_data, callable::types::member_visitor));

		// lex_error extensions
		(*lex_error_ext)
		    .add_var("text", make_cni(lexerr_text, callable::types::member_visitor))
		    .add_var("pos", make_cni(lexerr_pos, callable::types::member_visitor))
		    .add_var("set_text", make_cni(lexerr_set_text))
		    .add_var("set_pos", make_cni(lexerr_set_pos));

		// syntax_tree extensions
		(*syntax_tree_ext)
		    .add_var("root", make_cni(tree_root, callable::types::member_visitor))
		    .add_var("nodes", make_cni(tree_nodes, callable::types::member_visitor));

		// parse_error extensions
		(*parse_error_ext)
		    .add_var("cursor", make_cni(perr_cursor, callable::types::member_visitor))
		    .add_var("text", make_cni(perr_text, callable::types::member_visitor))
		    .add_var("pos", make_cni(perr_pos, callable::types::member_visitor));

		// lexer_type extensions
		(*lexer_type_ext)
		    .add_var("run", make_cni(lexer_run))
		    .add_var("get_error_log", make_cni(lexer_error_log));

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

		// partial_parser_type extensions
		(*partial_parser_type_ext)
		    .add_var("run", make_cni(pparser_run))
		    .add_var("production", make_cni(pparser_production))
		    .add_var("get_log", make_cni(pparser_get_log))
		    .add_var("log", make_property_cni(pparser_log))
		    .add_var("set_eof_hook", make_cni(pparser_set_eof_hook))
		    .add_var("clear_eof_hook", make_cni(pparser_clear_eof_hook))
		    .add_var("append_token", make_cni(pparser_push_token))
		    .add_var("push_tokens", make_cni(pparser_push_tokens));

		// generator extensions
		(*generator_ext)
		    .add_var("add_language", make_cni(gen_add_language))
		    .add_var("from_string", make_cni(gen_from_string))
		    .add_var("from_file", make_cni(gen_from_file))
		    .add_var("from_stream", make_cni(gen_from_stream))
		    .add_var("get_ast", make_cni(gen_get_ast))
		    .add_var("get_errors", make_cni(gen_get_errors))
		    .add_var("get_lex_errors", make_cni(gen_get_lex_errors))
		    .add_var("get_tokens", make_cni(gen_get_tokens))
		    .add_var("get_code_buff", make_cni(gen_get_code_buff))
		    .add_var("get_file_path", make_cni(gen_get_file_path))
		    .add_var("lex_string", make_cni(gen_lex_string))
		    .add_var("set_stop_on_error", make_cni(gen_set_stop_on_error))
		    .add_var("set_show_prompt", make_cni(gen_set_show_prompt))
		    .add_var("set_enable_log", make_cni(gen_set_enable_log));
	}
} // namespace parsergen_cni

void cs_extension_main(cs::name_space *ns)
{
	cs_impl::get_ext<syntax_t>();
	cs_impl::get_ext<grammar_t>();
	cs_impl::get_ext<token_t>();
	cs_impl::get_ext<lexerr_t>();
	cs_impl::get_ext<tree_t>();
	cs_impl::get_ext<perr_t>();
	cs_impl::get_ext<lexer_t>();
	cs_impl::get_ext<parser_t>();
	cs_impl::get_ext<pparser_wrapper_t>();
	cs_impl::get_ext<rparser_t>();
	cs_impl::get_ext<generator_t>();
	parsergen_cni::init(ns);
}
