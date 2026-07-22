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
var stmt_lex = {
    "id"  : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(=|;)$"),
    "endl": regex.build("^\\n+$"),
    "ign" : regex.build("^[ \\t]+$")
}.to_hash_map()
@end

@begin
var stmt_syntax = {
    "begin" : {syntax.repeat(syntax.ref("stmt"))},
    "stmt" : {syntax.token("id"), syntax.term("="), syntax.token("num"), syntax.term(";")},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

system.out.println("=== Error Recovery Tests ===")

system.out.println("--- valid input ---")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(stmt_lex, "x = 1; y = 2; z = 3;")
    parser.init(stmt_syntax)
    assert_true("valid: passes", parser.parse_with_recovery(tokens))
    assert_eq("valid: no errors", parser.get_all_errors().size, 0)
end

system.out.println("--- single error ---")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(stmt_lex, "x = ;")
    parser.init(stmt_syntax)
    assert_false("single error: fails", parser.parse_with_recovery(tokens))
    assert_true("single error: has errors", parser.get_all_errors().size > 0)
end

system.out.println("--- multiple errors ---")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(stmt_lex, "x = ; y = 2; z = ;")
    parser.init(stmt_syntax)
    assert_false("multi error: fails", parser.parse_with_recovery(tokens))
    assert_true("multi error: reports multiple", parser.get_all_errors().size >= 2)
end

system.out.println("--- recovery finds valid code after error ---")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(stmt_lex, "bad!; x = 1;")
    parser.init(stmt_syntax)
    parser.parse_with_recovery(tokens)
    var errors = parser.get_all_errors()
    assert_true("recovery: has errors", errors.size > 0)
    assert_true("recovery: error on line 1", errors[0].pos[1] == 0)
end

system.out.println("--- max_retries limit ---")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var input = new string
    for i = 0, i < 200, ++i
        input += "= ; "
    end
    var tokens = lexer.run(stmt_lex, input)
    parser.init(stmt_syntax)
    parser.parse_with_recovery(tokens)
    assert_true("max_retries: bounded errors", parser.get_all_errors().size <= 101)
end

system.out.println("--- empty input ---")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(stmt_lex, "")
    parser.init(stmt_syntax)
    assert_true("empty: passes (repeat zero)", parser.parse_with_recovery(tokens))
end

system.out.println("--- error positions are meaningful ---")

block
    var lexer = new parsergen.lexer_type
    var parser = new parsergen.recovering_parser_type
    var tokens = lexer.run(stmt_lex, "x = ;\ny = 2;")
    parser.init(stmt_syntax)
    parser.parse_with_recovery(tokens)
    var errors = parser.get_all_errors()
    assert_true("positions: has errors", errors.size > 0)
    var found_line1 = false
    foreach it in errors
        if it.pos[1] == 0
            found_line1 = true
        end
    end
    assert_true("positions: error on line 1", found_line1)
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
