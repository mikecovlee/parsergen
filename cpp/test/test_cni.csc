import parsergen
import regex

constant syntax = parsergen.syntax

@begin
var json_lex = {
    "id"  : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+\\.?([0-9]+)?$"),
    "str" : regex.build("^(\"|\"([^\"]|\\\\\")*\"?)$"),
    "sig" : regex.build("^(:|,|\\[|\\]|\\{|\\})$"),
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
    "object" : {syntax.term("{"), syntax.optional(syntax.ref("members")), syntax.term("}")},
    "members" : {syntax.ref("pair"), syntax.repeat(syntax.term(","), syntax.ref("pair"))},
    "pair" : {syntax.token("str"), syntax.term(":"), syntax.ref("value")},
    "array" : {syntax.term("["), syntax.optional(syntax.ref("elements")), syntax.term("]")},
    "elements" : {syntax.ref("value"), syntax.repeat(syntax.term(","), syntax.ref("value"))},
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
gram.set_lex(json_lex)
gram.set_stx(json_stx)

var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_grammar("json", gram)

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

check("valid json", gen.from_string("json", "{\"a\": 1, \"b\": [2, 3]}"))
check("ast not null", gen.ast() != null)
check("empty obj", gen.from_string("json", "{}"))
check("empty arr", gen.from_string("json", "[]"))
check("nested", gen.from_string("json", "{\"a\": {\"b\": [1, \"x\", null]}}"))
check("invalid", !gen.from_string("json", "{\"a\": }"))

system.out.println("CNI Passed: " + pass + ", Failed: " + fail)
if fail > 0
    system.exit(1)
end
