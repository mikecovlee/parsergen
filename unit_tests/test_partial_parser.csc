import parsergen, parsergen_debug, regex

constant syntax = parsergen.syntax
constant dsyntax = parsergen_debug.syntax

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
var lex_compiled = {
    "num" : regex.build("^[0-9]+$"),
    "ign" : regex.build("^\\s+$")
}.to_hash_map()
@end

@begin
var two_nums = {
    "begin" : {syntax.token("num"), syntax.token("num")}
}.to_hash_map()
@end

@begin
var two_nums_d = {
    "begin" : {dsyntax.token("num"), dsyntax.token("num")}
}.to_hash_map()
@end

@begin
var lex_patterns = {
    "num" : "^[0-9]+$",
    "ign" : "^\\s+$"
}.to_hash_map()
@end

var hooks_main = 0
function on_eof_main(pp)
    ++hooks_main
    pp.append_token(parsergen.make_token({1, 1}, "num", "2"))
end

var hooks_debug = 0
function on_eof_debug(pp)
    ++hooks_debug
    pp.append_token(parsergen_debug.make_token({1, 1}, "num", "2"))
end

system.out.println("=== Partial Parser Tests ===")

block
    var lexf = new parsergen.lexer_type
    var p = new parsergen.partial_parser_type
    p.set_eof_hook(on_eof_main)
    var ok = p.run(two_nums, lexf.run(lex_compiled, "1"))
    assert_true("hook: incomplete input recovered", ok)
    assert_eq("hook: called exactly once", hooks_main, 1)
end

block
    hooks_main = 0
    var lexf = new parsergen.lexer_type
    var p = new parsergen.partial_parser_type
    p.set_eof_hook(on_eof_main)
    var ok = p.run(two_nums, lexf.run(lex_compiled, "1"))
    assert_true("hook: recovery produces a production", p.production() != null)
    p.clear_eof_hook()
    var ok2 = p.run(two_nums, lexf.run(lex_compiled, "1"))
    assert_false("cleared: incomplete input fails", ok2)
    assert_eq("cleared: hook not re-invoked", hooks_main, 1)
end

block
    var lexf = new parsergen.lexer_type
    var p = new parsergen.partial_parser_type
    var ok = p.run(two_nums, lexf.run(lex_compiled, "1"))
    assert_false("no hook: incomplete input fails (no infinite retry)", ok)
end

block
    var lexf = new parsergen.lexer_type
    var p = new parsergen.partial_parser_type
    var ok = p.run(two_nums, lexf.run(lex_compiled, "1 2"))
    assert_true("complete input passes without hook", ok)
end

system.out.println("")
system.out.println("=== add_language Copy Semantics Tests ===")

block
    var gram = new parsergen.grammar
    gram.lex = lex_patterns
    gram.stx = two_nums
    var gen = new parsergen.generator
    gen.stop_on_error = true
    gen.show_prompt = false
    gen.add_language("l1", "ascii", gram)
    gen.add_language("l2", "ascii", gram)
    assert_true("reused grammar: l1 parses", gen.from_string("l1", "1 2"))
    assert_true("reused grammar: l2 parses", gen.from_string("l2", "3 4"))
    assert_eq("caller's grammar lex left untouched", gram.lex.at("num"), "^[0-9]+$")
end

system.out.println("")
system.out.println("=== Partial Parser (debug) Tests ===")

block
    var lexf = new parsergen_debug.lexer_type
    var p = new parsergen_debug.partial_parser_type
    p.set_eof_hook(on_eof_debug)
    var ok = p.run(two_nums_d, lexf.run(lex_compiled, "1"))
    assert_true("debug: hook recovers incomplete input", ok)
    assert_eq("debug: hook called once", hooks_debug, 1)
    p.clear_eof_hook()
    var ok2 = p.run(two_nums_d, lexf.run(lex_compiled, "1"))
    assert_false("debug: cleared hook fails", ok2)
    assert_eq("debug: hook not re-invoked", hooks_debug, 1)
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
