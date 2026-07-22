import parsergen, regex

constant syntax = parsergen.syntax

var test_pass = 0
var test_fail = 0

function assert_eq(name, actual, expected)
    if actual == expected
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name + ": expected \"" + expected + "\", got \"" + actual + "\"")
    end
end

function assert_true(name, cond)
    if cond
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name)
    end
end

function assert_false(name, cond)
    if !cond
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name)
    end
end

@begin
var json_lexical = {
    "num" : regex.build("^[0-9]+\\.?([0-9]+)?$"),
    "sig" : regex.build("^(:|,|\\[|\\]|\\{|\\})$"),
    "str" : regex.build("^(\"|\"([^\"]|\\\\\")*\"?)$"),
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "ign" : regex.build("^\\s+$"),
    "err" : regex.build("^\"$")
}.to_hash_map()
@end

@begin
var json_syntax = {
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
gram.lex = json_lexical
gram.stx = json_syntax

system.out.println("=== ParserGen Core Tests ===")

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    assert_true("parse valid object", gen.from_string("json", "{\"a\": 1}"))
end

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    assert_true("parse valid array", gen.from_string("json", "[1, 2, 3]"))
end

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    assert_true("parse nested", gen.from_string("json", "{\"a\": [1, {\"b\": true}]}"))
end

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    assert_false("reject invalid", gen.from_string("json", "{\"a\": }"))
end

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    assert_true("parse empty object", gen.from_string("json", "{}"))
end

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    assert_true("parse empty array", gen.from_string("json", "[]"))
end

system.out.println("")
system.out.println("=== Memoization Tests ===")

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    var input = "{\"x\": [1, 2], \"y\": [3, 4], \"z\": {\"a\": [5, 6]}}"
    assert_true("memo: complex nested", gen.from_string("json", input))
end

block
    var gen = new parsergen.generator
    gen.add_grammar("json", gram)
    gen.stop_on_error = true
    gen.show_prompt = false
    var input = "[[[[1]]]]"
    assert_true("memo: deep nesting", gen.from_string("json", input))
end

system.out.println("")
system.out.println("=== Error Recovery Tests ===")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(json_lexical, "{\"a\": 1}")
    parser.init(json_syntax)
    assert_true("recovery: valid input passes", parser.parse_with_recovery(tokens))
    assert_true("recovery: no errors on valid", parser.get_all_errors().empty())
end

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(json_lexical, "{\"a\": }")
    parser.init(json_syntax)
    assert_false("recovery: invalid input fails", parser.parse_with_recovery(tokens))
    assert_false("recovery: has errors on invalid", parser.get_all_errors().empty())
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
