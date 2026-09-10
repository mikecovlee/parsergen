#pragma once
#include <parsergen/parsergen.hpp>

namespace ecs_parser {

using namespace pg;
namespace S = pg::syntax;

inline lexical_t get_lexical()
{
	return {
		{"endl", "^\\n+$"},
		{"id", "^[A-Za-z_\\p{Han}](\\w|\\p{Han})*$"},
		{"num", "^[0-9]+\\.?([0-9]+)?$"},
		{"str", "^(\"|\"([^\"]|\\\\\")*\"?)$"},
		{"char", "^(\'|\'([^\']|\\\\(0|\\\\|\'|\"|\\w))\'?)$"},
		{"bsig", "^(;|:=?|::|\\?|\\.\\.?|\\.\\.\\.)$"},
		{"msig", "^(\\+(\\+|=)?|-(-|=|>)?|\\*=?|/=?|%=?|\\^=?)$"},
		{"lsig", "^(>|<|&|(\\|)|&&|(\\|\\|)|!|=(=|>)?|!=?|>=?|<=?)$"},
		{"brac", "^(\\(|\\)|\\[|\\]|\\{|\\}|,)$"},
		{"prep", "^@.*$"},
		{"err", "^(\"|\'|(\\|)|\\.\\.)$"},
		{"ign", "^([ \\f\\r\\t]+|#.*)$"},
	};
}

inline syntax_map_t get_syntax()
{
	syntax_map_t stx;

	stx["begin"] = {S::ref("stmts")};

	stx["endline"] = {S::cond_or({{S::token("endl")}, {S::term(";")}})};

	stx["stmts"] = {
		S::repeat({S::nlook({S::ref("endblock")}), S::ref("statement"), S::repeat({S::token("endl")})})
	};

	stx["decl-stmts"] = {
		S::repeat({S::nlook({S::ref("endblock")}), S::ref("declaration"), S::repeat({S::token("endl")})})
	};

	stx["endblock"] = {S::cond_or({
			{S::ref("end-stmt")},
			{S::ref("else-stmt")},
			{S::ref("until-stmt")},
			{S::ref("catch-stmt")},
		})
	};

	stx["statement"] = {S::cond_or({
			{S::ref("prep-stmt")},
			{S::ref("package-stmt")},
			{S::ref("import-stmt")},
			{S::ref("var-stmt")},
			{S::ref("block-stmt")},
			{S::ref("namespace-stmt")},
			{S::ref("using-stmt")},
			{S::ref("if-stmt")},
			{S::ref("switch-stmt")},
			{S::ref("while-stmt")},
			{S::ref("loop-stmt")},
			{S::ref("for-stmt")},
			{S::ref("foreach-stmt")},
			{S::ref("async-function-stmt")},
			{S::ref("control-stmt")},
			{S::ref("function-stmt")},
			{S::ref("yield-stmt")},
			{S::ref("return-stmt")},
			{S::ref("try-stmt")},
			{S::ref("throw-stmt")},
			{S::ref("class-stmt")},
			{S::ref("expr-stmt")},
		})
	};

	stx["declaration"] = {S::cond_or({
			{S::ref("prep-stmt")},
			{S::ref("namespace-stmt")},
			{S::ref("var-stmt")},
			{S::ref("using-stmt")},
			{S::ref("async-function-stmt")},
			{S::ref("function-stmt")},
			{S::ref("class-stmt")},
		})
	};

	stx["prep-stmt"] = {S::token("prep"), S::token("endl")};
	stx["package-stmt"] = {S::term("package"), S::token("id"), S::ref("endline")};
	stx["import-stmt"] = {S::term("import"), S::ref("import-list"), S::ref("endline")};
	stx["module-list"] = {S::token("id"), S::optional({S::term("."), S::cond_or({{S::term("*")}, {S::ref("module-list")}})})};
	stx["import-list"] = {S::ref("module-list"), S::optional({S::term("as"), S::token("id")}), S::optional({S::term(","), S::ref("import-list")})};

	stx["var-def"] = {S::cond_or({
			{S::ref("var-bind"), S::term("="), S::ref("basic-expr")},
			{S::ref("var-list")},
		})
	};
	stx["var-stmt"] = {S::cond_or({{S::term("var")}, {S::term("link")}, {S::term("constant")}}), S::ref("var-def"), S::ref("endline")};
	stx["var-bind"] = {S::term("("), S::ref("var-bind-list"), S::repeat({S::term(","), S::ref("var-bind-list")}), S::term(")")};
	stx["var-bind-list"] = {S::cond_or({{S::token("id")}, {S::term("...")}, {S::ref("var-bind")}})};
	stx["var-list"] = {S::token("id"), S::cond_or({
			{S::term("="), S::ref("basic-expr")},
			{S::term("as"), S::ref("unary-expr"), S::optional({S::ref("array")})},
		}), S::optional({S::term(","), S::ref("var-list")})
	};

	stx["block-stmt"] = {S::term("block"), S::token("endl"), S::ref("stmts"), S::term("end"), S::token("endl")};
	stx["namespace-stmt"] = {S::term("namespace"), S::token("id"), S::token("endl"), S::ref("decl-stmts"), S::term("end"), S::token("endl")};
	stx["using-stmt"] = {S::term("using"), S::ref("using-list"), S::ref("endline")};
	stx["using-list"] = {S::ref("module-list"), S::optional({S::term(","), S::ref("using-list")})};

	stx["if-stmt"] = {S::term("if"), S::ref("basic-expr"), S::token("endl"), S::ref("stmts"), S::repeat({S::ref("else-stmt"), S::ref("stmts")}), S::term("end"), S::token("endl")};
	stx["else-stmt"] = {S::term("else"), S::optional({S::nlook({S::token("endl")}), S::term("if"), S::ref("basic-expr")}), S::token("endl")};

	stx["switch-stmt"] = {S::term("switch"), S::ref("basic-expr"), S::token("endl"), S::ref("switch-stmts"), S::term("end"), S::token("endl")};
	stx["switch-stmts"] = {S::repeat({S::cond_or({{S::ref("switch-case")}, {S::ref("switch-default")}}), S::repeat({S::token("endl")})})};
	stx["switch-case"] = {S::term("case"), S::ref("logic-or-expr"), S::token("endl"), S::ref("stmts"), S::term("end"), S::token("endl")};
	stx["switch-default"] = {S::term("default"), S::token("endl"), S::ref("stmts"), S::term("end"), S::token("endl")};

	stx["while-stmt"] = {S::term("while"), S::ref("basic-expr"), S::token("endl"), S::ref("stmts"), S::term("end"), S::token("endl")};
	stx["loop-stmt"] = {S::term("loop"), S::token("endl"), S::ref("stmts"), S::cond_or({{S::ref("until-stmt")}, {S::term("end"), S::token("endl")}})};
	stx["until-stmt"] = {S::term("until"), S::ref("basic-expr"), S::token("endl")};

	stx["for-stmt"] = {S::term("for"), S::optional({S::ref("var-def")}), S::cond_or({{S::term(";")}, {S::term(",")}}), S::optional({S::ref("basic-expr")}), S::cond_or({{S::term(";")}, {S::term(",")}}), S::optional({S::ref("basic-expr")}), S::ref("for-body")};
	stx["foreach-stmt"] = {S::term("foreach"), S::optional({S::nlook({S::term("in")}), S::token("id")}), S::term("in"), S::ref("basic-expr"), S::ref("for-body")};
	stx["for-body"] = {S::cond_or({
			{S::term("do"), S::ref("basic-expr"), S::ref("endline")},
			{S::token("endl"), S::ref("stmts"), S::term("end"), S::token("endl")},
		})
	};

	stx["function-stmt"] = {S::term("function"), S::token("id"), S::term("("), S::optional({S::ref("argument-list")}), S::term(")"), S::optional({S::term("override")}), S::ref("function-body")};
	stx["function-body"] = {S::cond_or({
			{S::term("{"), S::ref("stmts"), S::term("}")},
			{S::token("endl"), S::ref("stmts"), S::term("end"), S::token("endl")},
		})
	};

	stx["return-stmt"] = {S::term("return"), S::optional({S::nlook({S::token("endl")}), S::ref("expr")}), S::ref("endline")};
	stx["try-stmt"] = {S::term("try"), S::token("endl"), S::ref("stmts"), S::repeat({S::ref("catch-stmt"), S::ref("stmts")}), S::term("end"), S::token("endl")};
	stx["catch-stmt"] = {S::term("catch"), S::token("id"), S::optional({S::term(":"), S::ref("visit-expr")}), S::token("endl")};
	stx["throw-stmt"] = {S::term("throw"), S::optional({S::nlook({S::token("endl")}), S::ref("expr")}), S::ref("endline")};

	stx["class-stmt"] = {S::cond_or({{S::term("class")}, {S::term("struct")}}), S::token("id"), S::optional({S::term("extends"), S::ref("visit-expr")}), S::token("endl"), S::ref("decl-stmts"), S::term("end"), S::token("endl")};

	stx["async-function-stmt"] = {S::term("async"), S::term("function"), S::token("id"), S::term("("), S::optional({S::ref("argument-list")}), S::term(")"), S::optional({S::term("override")}), S::ref("function-body")};
	stx["yield-stmt"] = {S::term("yield"), S::optional({S::nlook({S::token("endl")}), S::ref("expr")}), S::ref("endline")};
	stx["control-stmt"] = {S::cond_or({{S::term("break")}, {S::term("continue")}}), S::ref("endline")};
	stx["expr-stmt"] = {S::ref("expr"), S::ref("endline")};
	stx["end-stmt"] = {S::term("end"), S::token("endl")};

	stx["expr"] = {S::ref("basic-expr"), S::optional({S::term(","), S::ref("expr")})};
	stx["basic-expr"] = {S::cond_or({
			{S::ref("bind-expr"), S::term("="), S::ref("cond-expr")},
			{S::ref("cond-expr"), S::optional({S::ref("asi-op"), S::ref("basic-expr")})},
		})
	};
	stx["bind-expr"] = {S::term("("), S::ref("bind-list"), S::repeat({S::term(","), S::ref("bind-list")}), S::term(")")};
	stx["bind-list"] = {S::cond_or({{S::token("id")}, {S::term("...")}, {S::ref("bind-expr")}})};

	stx["asi-op"] = {S::cond_or({
			{S::term("=")}, {S::term(":=")}, {S::term("+=")}, {S::term("-=")},
			{S::term("*=")}, {S::term("/=")}, {S::term("%=")}, {S::term("^=")},
		})
	};

	stx["async-lambda-expr"] = {S::term("async"), S::term("["), S::optional({S::ref("capture-list")}), S::term("]"), S::term("("), S::optional({S::ref("argument-list")}), S::term(")"), S::ref("lambda-body")};
	stx["lambda-expr"] = {S::term("["), S::optional({S::ref("capture-list")}), S::term("]"), S::term("("), S::optional({S::ref("argument-list")}), S::term(")"), S::ref("lambda-body")};
	stx["capture-list"] = {S::optional({S::term("=")}), S::token("id"), S::repeat({S::term(","), S::ref("capture-list")})};
	stx["argument-list"] = {S::cond_or({
			{S::term("..."), S::token("id")},
			{S::optional({S::term("=")}), S::token("id"), S::optional({S::term(":"), S::ref("visit-expr")}), S::repeat({S::term(","), S::ref("argument-list")})},
		})
	};
	stx["lambda-body"] = {S::cond_or({
			{S::term("{"), S::ref("stmts"), S::term("}")},
			{S::term("->"), S::ref("cond-expr")},
		})
	};

	stx["cond-expr"] = {S::cond_or({
			{S::ref("async-lambda-expr")},
			{S::ref("lambda-expr")},
			{S::ref("logic-or-expr"), S::optional({S::ref("cond-postfix")})},
		})
	};
	stx["cond-postfix"] = {S::cond_or({
			{S::term("?"), S::ref("value-expr"), S::term(":"), S::ref("cond-expr")},
			{S::term(":"), S::ref("value-expr")},
		})
	};
	stx["value-expr"] = {S::cond_or({
			{S::ref("async-lambda-expr")},
			{S::ref("lambda-expr")},
			{S::ref("logic-or-expr")},
		})
	};

	stx["logic-or-expr"] = {S::ref("logic-and-expr"), S::optional({S::cond_or({{S::term("||")}, {S::term("or")}}), S::ref("logic-or-expr")})};
	stx["logic-and-expr"] = {S::ref("equal-expr"), S::optional({S::cond_or({{S::term("&&")}, {S::term("and")}}), S::ref("logic-and-expr")})};
	stx["equal-expr"] = {S::ref("relat-expr"), S::optional({S::cond_or({{S::term("==")}, {S::term("!=")}, {S::term("is")}, {S::term("not")}}), S::ref("equal-expr")})};
	stx["relat-expr"] = {S::ref("add-expr"), S::optional({S::cond_or({{S::term(">")}, {S::term("<")}, {S::term(">=")}, {S::term("<=")}}), S::ref("relat-expr")})};
	stx["add-expr"] = {S::ref("mul-expr"), S::optional({S::cond_or({{S::term("+")}, {S::term("-")}}), S::ref("add-expr")})};
	stx["mul-expr"] = {S::ref("conv-expr"), S::optional({S::nlook({S::token("endl")}), S::cond_or({{S::term("*")}, {S::term("/")}, {S::term("%")}, {S::term("^")}}), S::ref("mul-expr")})};
	stx["conv-expr"] = {S::ref("unary-expr"), S::optional({S::nlook({S::token("endl")}), S::cond_or({{S::term("=>")}, {S::term("as")}}), S::ref("visit-expr")})};

	stx["unary-expr"] = {S::cond_or({
			{S::ref("unary-op"), S::ref("unary-expr")},
			{S::cond_or({{S::term("new")}, {S::term("gcnew")}}), S::ref("visit-expr"), S::optional({S::ref("array")})},
			{S::ref("prim-expr"), S::optional({S::nlook({S::token("endl")}), S::ref("postfix-expr")})},
		})
	};
	stx["unary-op"] = {S::cond_or({
			{S::term("typeid")}, {S::term("++")}, {S::term("--")}, {S::term("*")},
			{S::term("&")}, {S::term("-")}, {S::term("!")}, {S::term("not")},
		})
	};
	stx["postfix-expr"] = {S::cond_or({{S::term("++")}, {S::term("--")}, {S::term("...")}}), S::optional({S::ref("postfix-expr")})};
	stx["await-expr"] = {S::term("await"), S::ref("unary-expr")};

	stx["prim-expr"] = {S::cond_or({
			{S::ref("await-expr")},
			{S::ref("visit-expr")},
			{S::ref("constant")},
		})
	};
	stx["visit-expr"] = {S::ref("object"), S::optional({S::cond_or({{S::term("->")}, {S::term(".")}}), S::ref("visit-expr")})};
	stx["object"] = {S::cond_or({
			{S::ref("array"), S::optional({S::ref("index")})},
			{S::token("str"), S::optional({S::ref("index")})},
			{S::term("local")},
			{S::term("global")},
			{S::ref("ecsx-extend")},
			{S::ref("element")},
			{S::token("char")},
		})
	};
	stx["ecsx-extend"] = {S::token("id"), S::nlook({S::token("endl")}), S::term("::"), S::token("id"), S::term("("), S::optional({S::ref("basic-expr")}), S::term(")")};
	stx["element"] = {S::cond_or({{S::token("id")}, {S::term("("), S::ref("basic-expr"), S::term(")")}}), S::repeat({S::nlook({S::token("endl")}), S::cond_or({{S::ref("fcall")}, {S::ref("index")}})})};
	stx["constant"] = {S::cond_or({{S::token("num")}, {S::term("null")}, {S::term("true")}, {S::term("false")}})};
	stx["array"] = {S::term("{"), S::optional({S::ref("expr")}), S::term("}")};
	stx["fcall"] = {S::term("("), S::optional({S::ref("expr")}), S::term(")")};
	stx["index"] = {S::cond_or({
			{S::term("["), S::optional({S::ref("add-expr")}), S::optional({S::term(":"), S::optional({S::ref("add-expr")}), S::optional({S::term(":"), S::optional({S::ref("add-expr")})})}), S::term("]")},
			{S::term("["), S::term("::"), S::term("]")},
		})
	};

	stx["ignore"] = {S::repeat({S::token("endl")})};

	return stx;
}

inline grammar make_grammar()
{
	grammar gram;
	gram.ext = ".*\\.(csp|csc|ecs|ecsx)";
	gram.lex = get_lexical();
	gram.stx = get_syntax();
	return gram;
}

} // namespace ecs_parser
