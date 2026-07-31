import parsergen_cxx as parsergen

context.import(runtime.get_import_path(), "ecs_parser")
import ecs_parser

constant syntax = parsergen.syntax

var test_pass = 0
var test_fail = 0

function check(name, cond)
    if cond
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name)
    end
end

# === Tiny grammar ===
@begin
var tiny_lex = {
    "id"  : "^[A-Za-z_]\\w*$",
    "num" : "^[0-9]+$",
    "sig" : "^(\\+|-|\\*|/|%|=|<|>|\\(|\\)|;|:=?)$",
    "ign" : "^(\\s+|\\{[^\\}]*\\}?)$",
    "err" : "^:$"
}.to_hash_map()
@end

@begin
var tiny_stx = {
    "begin" : {syntax.ref("stmts")},
    "stmts" : {syntax.ref("statement"), syntax.repeat(syntax.term(";"), syntax.ref("statement")), syntax.optional(syntax.term(";"))},
    "statement" : {syntax.cond_or(
        {syntax.ref("if-stmt")},
        {syntax.ref("repeat-stmt")},
        {syntax.ref("assign-stmt")},
        {syntax.ref("read-stmt")},
        {syntax.ref("write-stmt")}
    )},
    "if-stmt" : {
        syntax.term("if"), syntax.ref("expr"), syntax.term("then"), syntax.ref("stmts"),
        syntax.optional(syntax.term("else"), syntax.ref("stmts")), syntax.term("end")
    },
    "repeat-stmt" : {
        syntax.term("repeat"), syntax.ref("stmts"), syntax.term("until"), syntax.ref("expr")
    },
    "assign-stmt" : {syntax.token("id"), syntax.term(":="), syntax.ref("expr")},
    "read-stmt" : {syntax.term("read"), syntax.token("id")},
    "write-stmt" : {syntax.term("write"), syntax.ref("expr")},
    "expr" : {syntax.ref("sexp"), syntax.optional(syntax.ref("cmp-op"), syntax.ref("sexp"))},
    "cmp-op" : {syntax.cond_or({syntax.term("<")}, {syntax.term(">")}, {syntax.term("=")})},
    "sexp" : {syntax.ref("term"), syntax.repeat(syntax.ref("add-op"), syntax.ref("term"))},
    "add-op" : {syntax.cond_or({syntax.term("+")}, {syntax.term("-")})},
    "term" : {syntax.ref("fact"), syntax.repeat(syntax.ref("mul-op"), syntax.ref("fact"))},
    "mul-op" : {syntax.cond_or({syntax.term("*")}, {syntax.term("/")}, {syntax.term("%")})},
    "fact" : {syntax.cond_or(
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")},
        {syntax.token("num")}, {syntax.token("id")}
    )}
}.to_hash_map()
@end

# === C- grammar ===
@begin
var cminus_lex = {
    "id"  : "^[A-Za-z_]\\w*$",
    "num" : "^[0-9]+$",
    "sig" : "^(\\+|-|\\*|/|<|<=|>|>=|=|~=?|==|;|,|\\(|\\)|\\[|\\]|\\{|\\})$",
    "ign" : "^(\\s+|/|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$",
    "err" : "^~$"
}.to_hash_map()
@end

@begin
var cminus_stx = {
    "begin" : {
        syntax.ref("declaration"), syntax.repeat(syntax.ref("declaration"))
    },
    "declaration" : {
        syntax.ref("type_specifier"), syntax.token("id"), syntax.ref("declaration_s")
    },
    "declaration_s" : {syntax.cond_or(
        {syntax.term("["), syntax.token("num"), syntax.term("]"), syntax.term(";")},
        {syntax.term("("), syntax.ref("params"), syntax.term(")"), syntax.ref("compound_stmt")}
    )},
    "type_specifier" : {syntax.cond_or(
        {syntax.term("int")},
        {syntax.term("void")}
    )},
    "params" : {syntax.cond_or(
        {syntax.term("void")},
        {syntax.ref("param_list")}
    )},
    "param_list" : {
        syntax.ref("param"), syntax.repeat(syntax.term(","), syntax.ref("param"))
    },
    "param" : {
        syntax.ref("type_specifier"), syntax.token("id"), syntax.optional(syntax.term("["), syntax.term("]"))
    },
    "compound_stmt" : {
        syntax.term("{"),
        syntax.repeat(syntax.cond_or(
            {syntax.ref("var_declaration")},
            {syntax.ref("statement")}
        )),
        syntax.term("}")
    },
    "var_declaration" : {
        syntax.ref("type_specifier"), syntax.token("id"),
        syntax.optional(syntax.term("["), syntax.token("num"), syntax.term("]")),
        syntax.term(";")
    },
    "statement" : {syntax.cond_or(
        {syntax.ref("expression_stmt")},
        {syntax.ref("compound_stmt")},
        {syntax.ref("selection_stmt")},
        {syntax.ref("iteration_stmt")},
        {syntax.ref("return_stmt")}
    )},
    "expression_stmt" : {syntax.cond_or(
        {syntax.term(";")},
        {syntax.ref("expression"), syntax.term(";")}
    )},
    "selection_stmt" : {
        syntax.term("if"), syntax.term("("), syntax.ref("expression"), syntax.term(")"), syntax.ref("statement"),
        syntax.optional(syntax.term("else"), syntax.ref("statement"))
    },
    "iteration_stmt" : {
        syntax.term("while"), syntax.term("("), syntax.ref("expression"), syntax.term(")"), syntax.ref("statement")
    },
    "return_stmt" : {
        syntax.term("return"), syntax.optional(syntax.ref("expression")), syntax.term(";")
    },
    "expression" : {syntax.cond_or(
        {syntax.ref("var"), syntax.term("="), syntax.ref("expression")},
        {syntax.ref("simple_expression")}
    )},
    "var" : {
        syntax.token("id"), syntax.optional(syntax.term("["), syntax.ref("expression"), syntax.term("]"))
    },
    "simple_expression" : {
        syntax.ref("additive_expression"), syntax.optional(syntax.ref("relop"), syntax.ref("additive_expression"))
    },
    "relop" : {syntax.cond_or(
        {syntax.term("<=")},
        {syntax.term("<")},
        {syntax.term(">=")},
        {syntax.term(">")},
        {syntax.term("==")},
        {syntax.term("~=")}
    )},
    "additive_expression" : {
        syntax.ref("term"), syntax.repeat(syntax.ref("addop"), syntax.ref("term"))
    },
    "addop" : {syntax.cond_or(
        {syntax.term("+")},
        {syntax.term("-")}
    )},
    "term" : {
        syntax.ref("factor"), syntax.repeat(syntax.ref("mulop"), syntax.ref("term"))
    },
    "mulop" : {syntax.cond_or(
        {syntax.term("*")},
        {syntax.term("/")}
    )},
    "factor" : {syntax.cond_or(
        {syntax.term("("), syntax.ref("expression"), syntax.term(")")},
        {syntax.token("id"), syntax.optional(syntax.ref("factor_s"))},
        {syntax.token("num")}
    )},
    "factor_s" : {syntax.cond_or(
        {syntax.term("["), syntax.ref("expression"), syntax.term("]")},
        {syntax.term("("), syntax.optional(syntax.ref("args")), syntax.term(")")}
    )},
    "args" : {
        syntax.ref("expression"), syntax.repeat(syntax.term(","), syntax.ref("expression"))
    }
}.to_hash_map()
@end

# === JSON grammar ===
@begin
var json_lex = {
    "val" : "^\\w+$",
    "num" : "^[0-9]+\\.?([0-9]+)?$",
    "sig" : "^(:|,|\\[|\\]|\\{|\\})$",
    "str" : "^(\"|\"([^\"]|\\\\\")*\"?)$",
    "ign" : "^\\s+$",
    "err" : "^\"$"
}.to_hash_map()
@end

@begin
var json_stx = {
    "begin" : {syntax.cond_or(
        {syntax.ref("object")},
        {syntax.ref("array")}
    )},
    "object" : {
        syntax.term("{"), syntax.optional(syntax.ref("members")), syntax.term("}")
    },
    "members" : {
        syntax.ref("pair"), syntax.repeat(syntax.term(","), syntax.ref("pair"))
    },
    "pair" : {
        syntax.token("str"), syntax.term(":"), syntax.ref("value")
    },
    "array" : {
        syntax.term("["), syntax.optional(syntax.ref("elements")), syntax.term("]")
    },
    "elements" : {
        syntax.ref("value"), syntax.repeat(syntax.term(","), syntax.ref("value"))
    },
    "value" : {syntax.cond_or(
        {syntax.token("str")},
        {syntax.token("num")},
        {syntax.ref("object")},
        {syntax.ref("array")},
        {syntax.term("true")},
        {syntax.term("false")},
        {syntax.term("null")}
    )}
}.to_hash_map()
@end

# === Setup generator ===
var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.set_stop_on_error(false)
gen.add_language("tiny", "ascii", parsergen.make_grammar_from(".*\\.tny", tiny_lex, tiny_stx))
gen.add_language("c-", "ascii", parsergen.make_grammar_from(".*\\.c-", cminus_lex, cminus_stx))
gen.add_language("json", "ascii", parsergen.make_grammar_from(".*\\.json", json_lex, json_stx))
gen.add_language("ecs-lang", "ascii", ecs_parser.grammar)

# === Run all test cases ===
var base = "../../tests/test_cases/"

check("tiny/t1.tny", gen.from_file(base + "tiny/t1.tny"))
check("tiny/t2.tny", gen.from_file(base + "tiny/t2.tny"))
check("tiny/t3.tny", gen.from_file(base + "tiny/t3.tny"))
check("cminus/c1.c-", gen.from_file(base + "cminus/c1.c-"))
check("cminus/c2.c-", gen.from_file(base + "cminus/c2.c-"))
check("cminus/c3.c-", gen.from_file(base + "cminus/c3.c-"))
check("json/j1.json", gen.from_file(base + "json/j1.json"))
check("json/j2.json", gen.from_file(base + "json/j2.json"))
check("json/j3.json", gen.from_file(base + "json/j3.json"))
check("ecs/v1.ecs", gen.from_file(base + "ecs/v1.ecs"))
check("ecs/v2.ecs", gen.from_file(base + "ecs/v2.ecs"))
check("ecs/v3.ecs", gen.from_file(base + "ecs/v3.ecs"))
check("ecs/v4.ecs", gen.from_file(base + "ecs/v4.ecs"))

system.out.println("")
system.out.println("Drop-in replace: Passed " + test_pass + ", Failed " + test_fail)
if test_fail > 0
    system.exit(1)
end
