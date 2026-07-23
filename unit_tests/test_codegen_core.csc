import parsergen, parsergen_codegen, regex, test_nlook_parser, test_repeat_bt_parser, test_nested_parser, test_condor_parser, test_opt_complex_parser

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

function flatten_ast(tree, out)
    if tree == null
        return
    end
    out.push_back("<" + tree.root + ">")
    foreach it in tree.nodes
        if typeid it == typeid parsergen.syntax_tree
            flatten_ast(it, out)
        else
            out.push_back(it.type + ":" + it.data)
        end
    end
    out.push_back("</" + tree.root + ">")
end

function compare_ast(name, a, b)
    var a_nodes = new array
    var b_nodes = new array
    flatten_ast(a, a_nodes)
    flatten_ast(b, b_nodes)
    assert_eq(name + " node count", a_nodes.size, b_nodes.size)
    var ok = true
    for i = 0, i < a_nodes.size && i < b_nodes.size, ++i
        if a_nodes[i] != b_nodes[i]
            system.out.println("  DIFF at " + i + ": '" + a_nodes[i] + "' vs '" + b_nodes[i] + "'")
            ok = false
        end
    end
    assert_true(name + " AST match", ok)
end

# ======== Test Lex ========
@begin
var test_lex = {
    "id"  : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+$"),
    "op"  : regex.build("^(\\+|-|\\*|/|=|;|\\(|\\)|,)$"),
    "endl": regex.build("^\\n+$"),
    "ign" : regex.build("^[ \\t]+$"),
    "err" : regex.build("^@$")
}.to_hash_map()
@end

@begin
var nested_lex = {
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\(|\\)|,)$"),
    "ign" : regex.build("^\\s+$"),
    "err" : regex.build("^@$")
}.to_hash_map()
@end

@begin
var condor_lex = {
    "id" : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+$"),
    "ign" : regex.build("^\\s+$"),
    "err" : regex.build("^@$")
}.to_hash_map()
@end

system.out.println("=== Codegen Core Semantics Tests ===")

# ======== Test 1: nlook (negative lookahead) ========
system.out.println("--- nlook ---")

@begin
var nlook_stx = {
    "begin" : {syntax.ref("items"), syntax.term("end")},
    "items" : {syntax.repeat(syntax.nlook(syntax.term("end")), syntax.token("id"))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var dyn_gen = new parsergen.generator
    var gram = new parsergen.grammar
    gram.lex = test_lex
    gram.stx = nlook_stx
    dyn_gen.add_grammar("test", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    
    assert_true("nlook dyn: 'a b c end'", dyn_gen.from_string("test", "a b c end"))
    
    var gen_gen = new test_nlook_parser.generator
    assert_true("nlook gen: 'a b c end'", gen_gen.from_string("a b c end"))
    compare_ast("nlook: 'a b c end'", dyn_gen.ast, gen_gen.ast)
end

block
    var dyn_gen = new parsergen.generator
    var gram = new parsergen.grammar
    gram.lex = test_lex
    gram.stx = nlook_stx
    dyn_gen.add_grammar("test", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    
    assert_true("nlook dyn: 'end'", dyn_gen.from_string("test", "end"))
    
    var gen_gen = new test_nlook_parser.generator
    assert_true("nlook gen: 'end'", gen_gen.from_string("end"))
    compare_ast("nlook: 'end'", dyn_gen.ast, gen_gen.ast)
end

# ======== Test 2: Complex repeat with backtracking ========
system.out.println("--- repeat backtracking ---")

@begin
var repeat_bt_stx = {
    "begin" : {syntax.ref("stmts")},
    "stmts" : {syntax.repeat(syntax.ref("stmt"))},
    "stmt" : {syntax.token("id"), syntax.term("="), syntax.token("num"), syntax.term(";")},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var dyn_gen = new parsergen.generator
    var gram = new parsergen.grammar
    gram.lex = test_lex
    gram.stx = repeat_bt_stx
    dyn_gen.add_grammar("test", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    
    assert_true("repeat_bt dyn: 'x=1; y=2; z=3;'", dyn_gen.from_string("test", "x=1; y=2; z=3;"))
    
    var gen_gen = new test_repeat_bt_parser.generator
    assert_true("repeat_bt gen: 'x=1; y=2; z=3;'", gen_gen.from_string("x=1; y=2; z=3;"))
    compare_ast("repeat_bt: 'x=1; y=2; z=3;'", dyn_gen.ast, gen_gen.ast)
end

# ======== Test 3: Deeply nested structures ========
system.out.println("--- deep nesting ---")

@begin
var nested_stx = {
    "begin" : {syntax.ref("expr")},
    "expr" : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.term("("), syntax.ref("expr_list"), syntax.term(")")},
        {syntax.term("("), syntax.term(")")}
    )},
    "expr_list" : {syntax.ref("expr"), syntax.repeat(syntax.term(","), syntax.ref("expr"))}
}.to_hash_map()
@end

block
    var dyn_gen = new parsergen.generator
    var gram = new parsergen.grammar
    gram.lex = nested_lex
    gram.stx = nested_stx
    dyn_gen.add_grammar("test", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    
    var deep_input = "((1, (2, 3)), (4, (5, (6, 7))))"
    assert_true("nested dyn: deep", dyn_gen.from_string("test", deep_input))
    
    var gen_gen = new test_nested_parser.generator
    assert_true("nested gen: deep", gen_gen.from_string(deep_input))
    compare_ast("nested: deep", dyn_gen.ast, gen_gen.ast)
end

# ======== Test 4: Multiple cond_or branches ========
system.out.println("--- cond_or branches ---")

@begin
var condor_stx = {
    "begin" : {syntax.ref("value")},
    "value" : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.token("id")},
        {syntax.term("true")},
        {syntax.term("false")},
        {syntax.term("null")}
    )}
}.to_hash_map()
@end

block
    var dyn_gen = new parsergen.generator
    var gram = new parsergen.grammar
    gram.lex = condor_lex
    gram.stx = condor_stx
    dyn_gen.add_grammar("test", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    
    var tests = {"123", "hello", "true", "false", "null"}
    foreach input in tests
        assert_true("condor dyn: '" + input + "'", dyn_gen.from_string("test", input))
        
        var gen_gen = new test_condor_parser.generator
        assert_true("condor gen: '" + input + "'", gen_gen.from_string(input))
        compare_ast("condor: '" + input + "'", dyn_gen.ast, gen_gen.ast)
    end
end

# ======== Test 5: Optional with complex content ========
system.out.println("--- optional complex ---")

@begin
var opt_complex_stx = {
    "begin" : {syntax.ref("func")},
    "func" : {syntax.term("function"), syntax.token("id"), syntax.term("("), syntax.optional(syntax.ref("params")), syntax.term(")")},
    "params" : {syntax.ref("param"), syntax.repeat(syntax.term(","), syntax.ref("param"))},
    "param" : {syntax.token("id"), syntax.optional(syntax.term("="), syntax.token("num"))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var dyn_gen = new parsergen.generator
    var gram = new parsergen.grammar
    gram.lex = test_lex
    gram.stx = opt_complex_stx
    dyn_gen.add_grammar("test", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    
    var tests = new array
    tests.push_back("function foo()")
    tests.push_back("function bar(x)")
    tests.push_back("function baz(x = 5)")
    tests.push_back("function qux(a, b, c = 10)")
    foreach input in tests
        assert_true("opt_complex dyn: '" + input + "'", dyn_gen.from_string("test", input))
        
        var gen_gen = new test_opt_complex_parser.generator
        assert_true("opt_complex gen: '" + input + "'", gen_gen.from_string(input))
        compare_ast("opt_complex: '" + input + "'", dyn_gen.ast, gen_gen.ast)
    end
end

# ======== SUMMARY ========
system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
