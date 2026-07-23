import parsergen_codegen, parsergen, regex

constant syntax = parsergen.syntax

# --- Tiny lex regex pattern strings (for codegen) ---
@begin
var tiny_lex_regexes = {
    "id"  : "^[A-Za-z_]\\w*$",
    "num" : "^[0-9]+$",
    "sig" : "^(\\+|-|\\*|/|%|=|<|>|\\(|\\)|;|:=?)$",
    "ign" : "^(\\s+|\\{[^\\}]*\\}?)$",
    "err" : "^:$"
}.to_hash_map()
@end

# --- Tiny lex (compiled regex) ---
@begin
var tiny_lex = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|-|\\*|/|%|=|<|>|\\(|\\)|;|:=?)$"),
    "ign" : regex.build("^(\\s+|\\{[^\\}]*\\}?)$"),
    "err" : regex.build("^:$")
}.to_hash_map()
@end

# --- Tiny syntax ---
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

# --- Cminus lex regex pattern strings (for codegen) ---
@begin
var cminus_lex_regexes = {
    "id"  : "^[A-Za-z_]\\w*$",
    "num" : "^[0-9]+$",
    "sig" : "^(\\+|-|\\*|/|<|<=|>|>=|=|~=?|==|;|,|\\(|\\)|\\[|\\]|\\{|\\})$",
    "ign" : "^(\\s+|/|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$",
    "err" : "^~$"
}.to_hash_map()
@end

# --- Cminus lex (compiled regex) ---
@begin
var cminus_lex = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|-|\\*|/|<|<=|>|>=|=|~=?|==|;|,|\\(|\\)|\\[|\\]|\\{|\\})$"),
    "ign" : regex.build("^(\\s+|/|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$"),
    "err" : regex.build("^~$")
}.to_hash_map()
@end

# --- Cminus syntax ---
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

# Generate tiny parser
var tgram = new parsergen.grammar
tgram.ext = ".*\\.tny"
tgram.lex = tiny_lex
tgram.stx = tiny_stx

var tgen = new parsergen_codegen.code_generator
tgen.generate("tiny_gen_parser", tgram, tiny_lex_regexes, "./unit_tests/tiny_gen_parser.csp")
system.out.println("Generated: unit_tests/tiny_gen_parser.csp")

# Generate cminus parser
var cgram = new parsergen.grammar
cgram.ext = ".*\\.c-"
cgram.lex = cminus_lex
cgram.stx = cminus_stx

var cgen = new parsergen_codegen.code_generator
cgen.generate("cminus_gen_parser", cgram, cminus_lex_regexes, "./unit_tests/cminus_gen_parser.csp")
system.out.println("Generated: unit_tests/cminus_gen_parser.csp")
