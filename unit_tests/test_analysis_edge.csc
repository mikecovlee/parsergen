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

function report_contains(report, tag)
    foreach it in report
        if str_contains(it, tag)
            return true
        end
    end
    return false
end

system.out.println("=== Analysis Edge Cases ===")

system.out.println("--- indirect left recursion ---")

@begin
var indirect_lr = {
    "begin" : {syntax.ref("a")},
    "a" : {syntax.ref("b"), syntax.token("id")},
    "b" : {syntax.ref("c"), syntax.term("x")},
    "c" : {syntax.ref("a"), syntax.term("y")}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(indirect_lr)
    assert_true("indirect LR: a detected", report_contains(report, "\\[LEFT_RECURSION\\].*\"a\""))
    assert_true("indirect LR: b detected", report_contains(report, "\\[LEFT_RECURSION\\].*\"b\""))
    assert_true("indirect LR: c detected", report_contains(report, "\\[LEFT_RECURSION\\].*\"c\""))
end

system.out.println("--- left recursion through optional ---")

@begin
var opt_lr = {
    "begin" : {syntax.ref("a")},
    "a" : {syntax.optional(syntax.ref("a")), syntax.token("id")}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(opt_lr)
    assert_true("optional LR detected", report_contains(report, "\\[LEFT_RECURSION\\].*\"a\""))
end

system.out.println("--- left recursion through repeat ---")

@begin
var rep_lr = {
    "begin" : {syntax.ref("a")},
    "a" : {syntax.repeat(syntax.ref("a")), syntax.token("id")}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(rep_lr)
    assert_true("repeat LR detected", report_contains(report, "\\[LEFT_RECURSION\\].*\"a\""))
end

system.out.println("--- no LR when terminal first ---")

@begin
var safe_rec = {
    "begin" : {syntax.ref("a")},
    "a" : {syntax.token("id"), syntax.optional(syntax.term("+"), syntax.ref("a"))}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(safe_rec)
    assert_true("terminal-first: no LR", !report_contains(report, "\\[LEFT_RECURSION\\]"))
end

system.out.println("--- ignore excluded from unreachable ---")

@begin
var ign_unreach = {
    "begin" : {syntax.token("id")},
    "ignore" : {syntax.repeat(syntax.token("endl"))},
    "dead" : {syntax.term("x")}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(ign_unreach)
    assert_true("ignore not flagged", !report_contains(report, "\\[UNREACHABLE\\].*\"ignore\""))
    assert_true("dead flagged", report_contains(report, "\\[UNREACHABLE\\].*\"dead\""))
end

system.out.println("--- token type overlap ---")

@begin
var token_overlap = {
    "begin" : {syntax.ref("stmt")},
    "stmt" : {syntax.cond_or(
        {syntax.token("id"), syntax.term("=")},
        {syntax.token("id"), syntax.term("(")}
    )}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(token_overlap)
    assert_true("token overlap detected", report_contains(report, "\\[OVERLAP\\]"))
end

system.out.println("--- no overlap when disjoint ---")

@begin
var no_overlap = {
    "begin" : {syntax.ref("stmt")},
    "stmt" : {syntax.cond_or(
        {syntax.token("id"), syntax.term("=")},
        {syntax.token("num"), syntax.term("(")}
    )}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(no_overlap)
    assert_true("disjoint: no overlap", !report_contains(report, "\\[OVERLAP\\]"))
end

system.out.println("--- nlook skipped in left-ref collection ---")

@begin
var nlook_safe = {
    "begin" : {syntax.ref("a")},
    "a" : {syntax.nlook(syntax.ref("a")), syntax.token("id")}
}.to_hash_map()
@end

block
    var report = parsergen_analysis.analyze(nlook_safe)
    assert_true("nlook not counted as left-ref", !report_contains(report, "\\[LEFT_RECURSION\\]"))
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
