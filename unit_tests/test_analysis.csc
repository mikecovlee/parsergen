import parsergen_analysis, parsergen, regex

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

function assert_eq(name, actual, expected)
    if actual == expected
        ++test_pass
    else
        ++test_fail
        system.out.println("[FAIL] " + name + ": expected " + expected + ", got " + actual)
    end
end

function str_contains(str, sub)
    return !regex.build(".*" + sub + ".*").match(str).empty()
end

system.out.println("=== Grammar Analysis Tests ===")

@begin
var clean_syntax = {
    "begin" : {syntax.ref("stmts")},
    "stmts" : {syntax.repeat(syntax.ref("stmt"))},
    "stmt" : {syntax.cond_or(
        {syntax.ref("assign")},
        {syntax.ref("print")}
    )},
    "assign" : {syntax.token("id"), syntax.term("="), syntax.ref("expr")},
    "print" : {syntax.term("print"), syntax.ref("expr")},
    "expr" : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.token("id")}
    )}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(clean_syntax)
    assert_eq("clean grammar: no issues", report.size, 0)
end

@begin
var left_rec_syntax = {
    "begin" : {syntax.ref("expr")},
    "expr" : {syntax.ref("expr"), syntax.term("+"), syntax.token("num")}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(left_rec_syntax)
    var has_left_rec = false
    foreach it in report
        if str_contains(it, "\\[LEFT_RECURSION\\]")
            has_left_rec = true
        end
    end
    assert_true("left recursion detected", has_left_rec)
end

@begin
var unreachable_syntax = {
    "begin" : {syntax.ref("a")},
    "a" : {syntax.token("id")},
    "dead_rule" : {syntax.term("never"), syntax.term("used")}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(unreachable_syntax)
    var has_unreachable = false
    foreach it in report
        if str_contains(it, "\\[UNREACHABLE\\]")
            has_unreachable = true
        end
    end
    assert_true("unreachable rule detected", has_unreachable)
end

@begin
var overlap_syntax = {
    "begin" : {syntax.ref("stmt")},
    "stmt" : {syntax.cond_or(
        {syntax.term("foo"), syntax.token("id")},
        {syntax.term("foo"), syntax.token("num")}
    )}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(overlap_syntax)
    var has_overlap = false
    foreach it in report
        if str_contains(it, "\\[OVERLAP\\]")
            has_overlap = true
        end
    end
    assert_true("FIRST overlap detected", has_overlap)
end

@begin
var right_rec_syntax = {
    "begin" : {syntax.ref("expr")},
    "expr" : {syntax.token("num"), syntax.optional(syntax.term("+"), syntax.ref("expr"))}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(right_rec_syntax)
    var has_left_rec = false
    foreach it in report
        if str_contains(it, "\\[LEFT_RECURSION\\]")
            has_left_rec = true
        end
    end
    assert_true("right recursion is OK", !has_left_rec)
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
