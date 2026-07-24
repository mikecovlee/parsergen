import ebnfigen, parsergen, regex

constant syntax = parsergen.syntax

var test_pass = 0
var test_fail = 0

function assert_true(name, cond)
    if cond
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name)
    end
end

function str_contains(str, pattern)
    return !regex.build(".*" + pattern + ".*").match(str).empty()
end

function output_contains(output, pattern)
    var lines = output.split({'\n'})
    foreach line in lines
        if !regex.build(".*" + pattern + ".*").match(line).empty()
            return true
        end
    end
    return false
end

function gen_to_string(stx)
    var path = "./ebnfigen_test_out.ebnf"
    block
        var ofs = iostream.ofstream(path)
        var gen = new ebnfigen.ebnf_generator
        gen.run(ofs, stx)
    end
    var ifs = iostream.ifstream(path)
    var lines = new array
    parsergen.read_stream(ifs, lines)
    var result = new string
    foreach line in lines do result += line + "\n"
    return move(result)
end

system.out.println("=== EBNF Generator Tests ===")

@begin
var test_syntax = {
    "begin" : {syntax.ref("expr")},
    "expr" : {syntax.ref("term"), syntax.optional(syntax.term("+"), syntax.ref("expr"))},
    "term" : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")}
    )}
}.to_hash_map()
@end

block
    var output = gen_to_string(test_syntax)
    assert_true("output not empty", output.size > 0)
    assert_true("contains begin rule", output_contains(output, "begin ="))
    assert_true("contains expr rule", output_contains(output, "expr ="))
    assert_true("contains term rule", output_contains(output, "term ="))
    assert_true("contains semicolons", output_contains(output, ";"))
    assert_true("contains token ref", output_contains(output, "<num>"))
    assert_true("contains quoted term", output_contains(output, "\"\\+\""))
    assert_true("contains optional", output_contains(output, "\\["))
    assert_true("contains alternation", output_contains(output, "\\|"))
end

@begin
var hyphen_syntax = {
    "begin" : {syntax.ref("my-rule")},
    "my-rule" : {syntax.token("id")}
}.to_hash_map()
@end

block
    var output = gen_to_string(hyphen_syntax)
    assert_true("hyphen replaced in rule name", output_contains(output, "my_rule ="))
    assert_true("hyphen replaced in ref", output_contains(output, "my_rule"))
    assert_true("no hyphen in identifiers", !output_contains(output, "my-rule"))
end

@begin
var nlook_syntax = {
    "begin" : {syntax.nlook(syntax.token("endl")), syntax.token("id")}
}.to_hash_map()
@end

block
    var output = gen_to_string(nlook_syntax)
    assert_true("nlook uses PEG syntax", output_contains(output, "!\\("))
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
