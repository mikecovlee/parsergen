import parsergen, regex

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

function assert_false(name, cond)
    if !cond
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name)
    end
end

function assert_eq(name, actual, expected)
    if actual == expected
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name + ": expected " + expected + ", got " + actual)
    end
end

@begin
var test_lex = {
    "id"  : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+$"),
    "op"  : regex.build("^(\\+|-|\\*|/|=|;|\\(|\\))$"),
    "endl": regex.build("^\\n+$"),
    "ign" : regex.build("^[ \\t]+$"),
    "err" : regex.build("^@$")
}.to_hash_map()
@end

system.out.println("=== Core Semantics Tests ===")

system.out.println("--- nlook ---")

@begin
var nlook_syntax = {
    "begin" : {syntax.ref("items"), syntax.term("end")},
    "items" : {syntax.repeat(syntax.nlook(syntax.term("end")), syntax.token("id"))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "a b c end")
    var p = new parsergen.parser_type
    assert_true("nlook: stops before 'end'", p.run(nlook_syntax, tokens))
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "end")
    var p = new parsergen.parser_type
    assert_true("nlook: zero items before 'end' ok", p.run(nlook_syntax, tokens))
end

@begin
var nlook_reject_syntax = {
    "begin" : {syntax.nlook(syntax.token("num")), syntax.token("id")},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "5")
    var p = new parsergen.parser_type
    assert_false("nlook: rejects when lookahead matches", p.run(nlook_reject_syntax, tokens))
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "hello")
    var p = new parsergen.parser_type
    assert_true("nlook: accepts when lookahead fails", p.run(nlook_reject_syntax, tokens))
end

system.out.println("--- repeat ---")

@begin
var repeat_syntax = {
    "begin" : {syntax.ref("list")},
    "list" : {syntax.repeat(syntax.token("num"))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "1 2 3")
    var p = new parsergen.parser_type
    assert_true("repeat: multiple matches", p.run(repeat_syntax, tokens))
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "")
    var p = new parsergen.parser_type
    assert_true("repeat: zero matches ok", p.run(repeat_syntax, tokens))
end

system.out.println("--- repeat epsilon eof ---")

# A repeat whose item may match epsilon (an optional) used to loop forever
# at EOF: the repeat boot set contains epsilon, so predict() kept accepting
# while the item consumed no token. The repeat must stop after such an item.
@begin
var repeat_eps_syntax = {
    "begin" : {syntax.repeat(syntax.optional(syntax.token("id")))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "x")
    var p = new parsergen.parser_type
    assert_true("repeat: epsilon item at eof terminates", p.run(repeat_eps_syntax, tokens))
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "")
    var p = new parsergen.parser_type
    assert_true("repeat: epsilon item at eof (empty input)", p.run(repeat_eps_syntax, tokens))
end

system.out.println("--- optional ---")

@begin
var opt_syntax = {
    "begin" : {syntax.token("id"), syntax.optional(syntax.term("="), syntax.token("num"))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "x = 5")
    var p = new parsergen.parser_type
    assert_true("optional: present", p.run(opt_syntax, tokens))
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "x")
    var p = new parsergen.parser_type
    assert_true("optional: absent", p.run(opt_syntax, tokens))
end

system.out.println("--- ignore ---")

@begin
var ign_syntax = {
    "begin" : {syntax.token("id"), syntax.token("num")},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "x\n\n\n5")
    var p = new parsergen.parser_type
    assert_true("ignore: skips endl between tokens", p.run(ign_syntax, tokens))
end

system.out.println("--- cond_or ---")

@begin
var cond_syntax = {
    "begin" : {syntax.ref("value")},
    "value" : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.token("id")},
        {syntax.term("("), syntax.ref("value"), syntax.term(")")}
    )},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "42")
    var p = new parsergen.parser_type
    assert_true("cond_or: first alt", p.run(cond_syntax, tokens))
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "hello")
    var p = new parsergen.parser_type
    assert_true("cond_or: second alt", p.run(cond_syntax, tokens))
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "(99)")
    var p = new parsergen.parser_type
    assert_true("cond_or: third alt", p.run(cond_syntax, tokens))
end

system.out.println("--- empty input ---")

@begin
var empty_ok_syntax = {
    "begin" : {syntax.optional(syntax.token("id"))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "")
    var p = new parsergen.parser_type
    assert_true("empty input: optional accepts", p.run(empty_ok_syntax, tokens))
end

@begin
var empty_fail_syntax = {
    "begin" : {syntax.token("id")},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "")
    var p = new parsergen.parser_type
    assert_false("empty input: required token fails", p.run(empty_fail_syntax, tokens))
end

system.out.println("--- lexer errors ---")

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "hello # world")
    assert_false("lexer: unknown char produces error", lexer.error_log.empty())
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "hello world")
    assert_true("lexer: valid input no error", lexer.error_log.empty())
    assert_eq("lexer: token count", tokens.size, 2)
end

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "   \t  ")
    assert_true("lexer: pure whitespace ignored", tokens.empty())
    assert_true("lexer: no error on whitespace", lexer.error_log.empty())
end

system.out.println("--- AST structure ---")

block
    var lexer = new parsergen.lexer_type
    var tokens = lexer.run(test_lex, "x = 5")
    var p = new parsergen.parser_type
    p.run(opt_syntax, tokens)
    var ast = p.production()
    assert_eq("ast: root is begin", ast.root, "begin")
    assert_true("ast: has nodes", !ast.nodes.empty())
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
