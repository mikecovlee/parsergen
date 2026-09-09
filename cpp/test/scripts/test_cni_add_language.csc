var parsergen = context.import(runtime.get_import_path(), "parsergen_cxx")

var syntax = parsergen.syntax

@begin
var ecs_lex = {
    "endl" : "^\\n+$",
    "id" :   "^[A-Za-z_\\p{Han}](\\w|\\p{Han})*$",
    "num" :  "^[0-9]+\\.?([0-9]+)?$",
    "str" :  "^(\"|\"([^\"]|\\\\\")*\"?)$",
    "char" : "^(\'|\'([^\']|\\\\(0|\\\\|\'|\"|\\w))\'?)$",
    "bsig" : "^(;|:=?|::|\\?|\\.\\.?|\\.\\.\\.)$",
    "msig" : "^(\\+(\\+|=)?|-(-|=|>)?|\\*=?|/=?|%=?|\\^=?)$",
    "lsig" : "^(>|<|&|(\\|)|&&|(\\|\\|)|!|=(=|>)?|!=?|>=?|<=?)$",
    "brac" : "^(\\(|\\)|\\[|\\]|\\{|\\}|,)$",
    "prep" : "^@.*$",
    "err" :  "^(\"|\'|(\\|)|\\.\\.)$",
    "ign" :  "^([ \\f\\r\\t]+|#.*)$"
}.to_hash_map()
@end

@begin
var ecs_stx = {
    "begin" : {syntax.ref("stmts")},
    "stmts" : {
        syntax.repeat(syntax.token("endl")),
        syntax.repeat(syntax.nlook(syntax.ref("endblock")), syntax.ref("statement"), syntax.repeat(syntax.token("endl")))
    },
    "endblock" : {syntax.cond_or(
        {syntax.ref("end-stmt")},
        {syntax.ref("else-stmt")},
        {syntax.ref("until-stmt")},
        {syntax.ref("catch-stmt")}
    )},
    "statement" : {syntax.cond_or(
        {syntax.ref("var-stmt")},
        {syntax.ref("expr-stmt")}
    )},
    "var-stmt" : {
        syntax.cond_or({syntax.term("var")}, {syntax.term("link")}, {syntax.term("constant")}),
        syntax.ref("var-def"), syntax.ref("endline")
    },
    "var-def" : {syntax.cond_or(
        {syntax.ref("var-list")}
    )},
    "var-list" : {
        syntax.token("id"), syntax.cond_or(
            {syntax.term("="), syntax.ref("basic-expr")},
            {syntax.term("as"), syntax.ref("unary-expr")}
        ), syntax.optional(syntax.term(","), syntax.ref("var-list"))
    },
    "endline" : {syntax.cond_or(
        {syntax.token("endl")},
        {syntax.term(";")}
    )},
    "end-stmt" : {syntax.term("end"), syntax.token("endl")},
    "else-stmt" : {syntax.term("else"), syntax.token("endl")},
    "until-stmt" : {syntax.term("until"), syntax.ref("basic-expr"), syntax.token("endl")},
    "catch-stmt" : {syntax.term("catch"), syntax.token("id"), syntax.token("endl")},
    "expr-stmt" : {syntax.ref("expr"), syntax.ref("endline")},
    "expr" : {
        syntax.ref("basic-expr"), syntax.optional(syntax.term(","), syntax.ref("expr"))
    },
    "basic-expr" : {syntax.cond_or(
        {syntax.ref("cond-expr")}
    )},
    "cond-expr" : {syntax.ref("logic-or-expr")},
    "logic-or-expr" : {
        syntax.ref("logic-and-expr"), syntax.optional(syntax.cond_or({syntax.term("||")}, {syntax.term("or")}), syntax.ref("logic-or-expr"))
    },
    "logic-and-expr" : {
        syntax.ref("equal-expr"), syntax.optional(syntax.cond_or({syntax.term("&&")}, {syntax.term("and")}), syntax.ref("logic-and-expr"))
    },
    "equal-expr" : {
        syntax.ref("relat-expr"), syntax.optional(syntax.cond_or({syntax.term("==")}, {syntax.term("!=")}), syntax.ref("equal-expr"))
    },
    "relat-expr" : {
        syntax.ref("add-expr"), syntax.optional(syntax.cond_or({syntax.term(">")}, {syntax.term("<")}, {syntax.term(">=")}, {syntax.term("<=")}), syntax.ref("relat-expr"))
    },
    "add-expr" : {
        syntax.ref("mul-expr"), syntax.optional(syntax.cond_or({syntax.term("+")}, {syntax.term("-")}), syntax.ref("add-expr"))
    },
    "mul-expr" : {
        syntax.ref("unary-expr"), syntax.optional(syntax.cond_or({syntax.term("*")}, {syntax.term("/")}, {syntax.term("%")}, {syntax.term("^")}), syntax.ref("mul-expr"))
    },
    "unary-expr" : {syntax.cond_or(
        {syntax.ref("unary-op"), syntax.ref("unary-expr")},
        {syntax.ref("prim-expr")}
    )},
    "unary-op" : {syntax.cond_or(
        {syntax.term("-")},
        {syntax.term("!")},
        {syntax.term("not")}
    )},
    "prim-expr" : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.token("str")},
        {syntax.token("char")},
        {syntax.token("id")},
        {syntax.term("null")},
        {syntax.term("true")},
        {syntax.term("false")},
        {syntax.term("("), syntax.ref("basic-expr"), syntax.term(")")}
    )},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

var gram = parsergen.make_grammar_from(".*\\.(csp|csc|ecs|ecsx)", ecs_lex, ecs_stx)

var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_language("ecs-lang", "ascii", gram)

var pass = 0
var fail = 0

function check(name, cond)
    if cond
        ++pass
    else
        ++fail
        system.out.println("[FAIL] " + name)
    end
end

check("var stmt", gen.from_string("ecs-lang", "var x = 1\n"))
check("var multi", gen.from_string("ecs-lang", "var x = 1, y = 2\n"))
check("expr stmt", gen.from_string("ecs-lang", "x + y\n"))
check("multi line", gen.from_string("ecs-lang", "var a = 1\nvar b = 2\na + b\n"))
check("invalid", !gen.from_string("ecs-lang", "var = \n"))

# Test lex_string
var tokens = gen.lex_string("ecs-lang", "var x = 1\n", 0)
check("lex_string", tokens != null && !tokens.empty())
check("lex_errors empty", gen.get_lex_errors().empty())
# unknown language -> null (parity with the CovScript reference)
check("lex_string unknown lang is null", gen.lex_string("no-such-lang", "var x = 1\n", 0) == null)

system.out.println("CNI add_language: Passed " + pass + ", Failed " + fail)
if fail > 0
    system.exit(1)
end
