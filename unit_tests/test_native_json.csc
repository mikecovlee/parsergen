import json_native, parsergen, regex

constant syntax = parsergen.syntax

var test_pass = 0
var test_fail = 0

function assert_true(name, cond)
    if cond
        ++test_pass
    else
        ++test_fail
        system.out.println("  FAIL: " + name)
    end
end

function assert_false(name, cond)
    if !cond
        ++test_pass
    else
        ++test_fail
        system.out.println("  FAIL: " + name + " (expected fail)")
    end
end

system.out.println("=== Native JSON Parser Test ===")

var gen = new json_native.generator

assert_true("empty obj {}", gen.from_string("{}"))
assert_true("empty arr []", gen.from_string("[]"))
assert_true("simple {\"a\":1}", gen.from_string("{\"a\": 1}"))
assert_true("array [1,2,3]", gen.from_string("[1, 2, 3]"))
assert_true("nested", gen.from_string("{\"x\": true, \"y\": [null, false]}"))
assert_true("deep", gen.from_string("{\"a\": {\"b\": {\"c\": [1, 2]}}}"))
assert_false("reject bad", gen.from_string("{\"a\": }"))
assert_false("reject missing }", gen.from_string("{\"a\": 1"))

system.out.println("")
system.out.println("=== Performance vs Dynamic ===")

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
    "begin" : {syntax.cond_or({syntax.ref("object")},{syntax.ref("array")})},
    "object" : {syntax.term("{"),syntax.optional(syntax.ref("members")),syntax.term("}")},
    "members" : {syntax.ref("pair"),syntax.repeat(syntax.term(","),syntax.ref("pair"))},
    "pair" : {syntax.token("str"),syntax.term(":"),syntax.ref("value")},
    "array" : {syntax.term("["),syntax.optional(syntax.ref("elements")),syntax.term("]")},
    "elements" : {syntax.ref("value"),syntax.repeat(syntax.term(","),syntax.ref("value"))},
    "value" : {syntax.cond_or({syntax.token("str")},{syntax.token("num")},{syntax.ref("object")},{syntax.ref("array")},{syntax.term("true")},{syntax.term("false")},{syntax.term("null")})}
}.to_hash_map()
@end

var perf_input = "{\"widget\":{\"debug\":true,\"window\":{\"title\":\"Sample\",\"name\":\"main\",\"width\":500,\"height\":400},\"image\":{\"src\":\"Images/Sun.png\",\"name\":\"sun1\",\"hOffset\":250,\"vOffset\":100,\"alignment\":\"center\"},\"text\":{\"data\":\"Click Here\",\"size\":36,\"style\":\"bold\",\"name\":\"text1\",\"hOffset\":250,\"vOffset\":200,\"alignment\":\"center\",\"onMouseUp\":\"sun1.opacity = 50\"}}}"

# Dynamic
var dt = 0.0
for i = 0, i < 3, ++i
    var g = new parsergen.generator
    var gram = new parsergen.grammar
    gram.lex = json_lex
    gram.stx = json_stx
    g.add_grammar("json", gram)
    g.stop_on_error = true
    g.show_prompt = false
    var t = runtime.time()
    g.from_string("json", perf_input)
    dt += runtime.time() - t
end
system.out.println("Dynamic (avg 3): " + (dt/3) + " ms")

# Native
var nt = 0.0
for i = 0, i < 3, ++i
    var g = new json_native.generator
    var t = runtime.time()
    g.from_string(perf_input)
    nt += runtime.time() - t
end
system.out.println("Native (avg 3):  " + (nt/3) + " ms")
if nt < dt
    system.out.println("Speedup: " + (dt/nt) + "x")
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
