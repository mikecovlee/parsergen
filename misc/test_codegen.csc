import parsergen_codegen, parsergen, regex

constant syntax = parsergen.syntax

@begin
var json_lex_regexes = {
    "num" : "^[0-9]+\\.?([0-9]+)?$",
    "sig" : "^(:|,|\\[|\\]|\\{|\\})$",
    "str" : "^(\"|\"([^\"]|\\\\\")*\"?)$",
    "id"  : "^[A-Za-z_]\\w*$",
    "ign" : "^\\s+$",
    "err" : "^\"$"
}.to_hash_map()
@end

@begin
var json_lex = {
    "num" : regex.build("^[0-9]+\\.?([0-9]+)?$"),
    "sig" : regex.build("^(:|,|\\[|\\]|\\{|\\})$"),
    "str" : regex.build("^(\"|\"([^\"]|\\\\\")*\"?)$"),
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "ign" : regex.build("^\\s+$"),
    "err" : regex.build("^\"$")
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

var gram = new parsergen.grammar
gram.ext = ".*\\.json"
gram.lex = json_lex
gram.stx = json_stx

var gen = new parsergen_codegen.code_generator
gen.generate("test_json_parser", gram, json_lex_regexes, "./unit_tests/test_json_parser.csp")
system.out.println("Generated: test_json_parser.csp")
