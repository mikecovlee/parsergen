import parsergen, parsergen_codegen, regex, test_json_parser, ecs_gen_parser, ecs_parser, tiny_gen_parser, cminus_gen_parser

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

function collect_tokens(tree, out)
    if tree == null
        return
    end
    foreach it in tree.nodes
        if typeid it == typeid parsergen.syntax_tree
            out.push_back("(" + it.root)
            collect_tokens(it, out)
            out.push_back(")")
        end
        if typeid it == typeid parsergen.token_type
            out.push_back(it.type + ":" + it.data)
        end
    end
end

function ast_signature(ast)
    var sig = new array
    collect_tokens(ast, sig)
    var result = new string
    foreach it in sig
        if result.size > 0
            result += " "
        end
        result += it
    end
    return move(result)
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

# ======== GRAMMAR DEFINITIONS ========

# JSON lex (compiled regex for dynamic parser)
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

# JSON syntax
@begin
var json_stx = {
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

# Tiny lex regex pattern strings (for codegen)
@begin
var tiny_lex_regexes = {
    "id"  : "^[A-Za-z_]\\w*$",
    "num" : "^[0-9]+$",
    "sig" : "^(\\+|-|\\*|/|%|=|<|>|\\(|\\)|;|:=?)$",
    "ign" : "^(\\s+|\\{[^\\}]*\\}?)$",
    "err" : "^:$"
}.to_hash_map()
@end

# Tiny lex (compiled regex for dynamic parser)
@begin
var tiny_lex = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|-|\\*|/|%|=|<|>|\\(|\\)|;|:=?)$"),
    "ign" : regex.build("^(\\s+|\\{[^\\}]*\\}?)$"),
    "err" : regex.build("^:$")
}.to_hash_map()
@end

# Tiny syntax
@begin
var tiny_stx = {
    "begin" : {syntax.ref("stmts")},
    "stmts" : {syntax.ref("statement"), syntax.repeat(syntax.term(";"), syntax.ref("statement")), syntax.optional(syntax.term(";"))},
    "statement" : {syntax.cond_or(
        {syntax.ref("if-stmt")},
        {syntax.ref("repeat-stmt")},
        {syntax.ref("assign-stmt")},
        {syntax.ref("read-stmt")},
        {syntax.ref("write-stmt")}
    )},
    "if-stmt" : {
        syntax.term("if"), syntax.ref("expr"), syntax.term("then"), syntax.ref("stmts"),
        syntax.optional(syntax.term("else"), syntax.ref("stmts")), syntax.term("end")
    },
    "repeat-stmt" : {
        syntax.term("repeat"), syntax.ref("stmts"), syntax.term("until"), syntax.ref("expr")
    },
    "assign-stmt" : {syntax.token("id"), syntax.term(":="), syntax.ref("expr")},
    "read-stmt" : {syntax.term("read"), syntax.token("id")},
    "write-stmt" : {syntax.term("write"), syntax.ref("expr")},
    "expr" : {syntax.ref("sexp"), syntax.optional(syntax.ref("cmp-op"), syntax.ref("sexp"))},
    "cmp-op" : {syntax.cond_or({syntax.term("<")}, {syntax.term(">")}, {syntax.term("=")})},
    "sexp" : {syntax.ref("term"), syntax.repeat(syntax.ref("add-op"), syntax.ref("term"))},
    "add-op" : {syntax.cond_or({syntax.term("+")}, {syntax.term("-")})},
    "term" : {syntax.ref("fact"), syntax.repeat(syntax.ref("mul-op"), syntax.ref("fact"))},
    "mul-op" : {syntax.cond_or({syntax.term("*")}, {syntax.term("/")}, {syntax.term("%")})},
    "fact" : {syntax.cond_or(
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")},
        {syntax.token("num")}, {syntax.token("id")}
    )}
}.to_hash_map()
@end

# Cminus lex regex pattern strings (for codegen)
@begin
var cminus_lex_regexes = {
    "id"  : "^[A-Za-z_]\\w*$",
    "num" : "^[0-9]+$",
    "sig" : "^(\\+|-|\\*|/|<|<=|>|>=|=|~=?|==|;|,|\\(|\\)|\\[|\\]|\\{|\\})$",
    "ign" : "^(\\s+|/|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$",
    "err" : "^~$"
}.to_hash_map()
@end

# Cminus lex (compiled regex for dynamic parser)
@begin
var cminus_lex = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|-|\\*|/|<|<=|>|>=|=|~=?|==|;|,|\\(|\\)|\\[|\\]|\\{|\\})$"),
    "ign" : regex.build("^(\\s+|/|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$"),
    "err" : regex.build("^~$")
}.to_hash_map()
@end

# Cminus syntax
@begin
var cminus_stx = {
    "begin" : {
        syntax.ref("declaration"), syntax.repeat(syntax.ref("declaration"))
    },
    "declaration" : {
        syntax.ref("type_specifier"), syntax.token("id"), syntax.ref("declaration_s")
    },
    "declaration_s" : {syntax.cond_or(
        {syntax.term("["), syntax.token("num"), syntax.term("]"), syntax.term(";")},
        {syntax.term("("), syntax.ref("params"), syntax.term(")"), syntax.ref("compound_stmt")}
    )},
    "type_specifier" : {syntax.cond_or(
        {syntax.term("int")},
        {syntax.term("void")}
    )},
    "params" : {syntax.cond_or(
        {syntax.term("void")},
        {syntax.ref("param_list")}
    )},
    "param_list" : {
        syntax.ref("param"), syntax.repeat(syntax.term(","), syntax.ref("param"))
    },
    "param" : {
        syntax.ref("type_specifier"), syntax.token("id"), syntax.optional(syntax.term("["), syntax.term("]"))
    },
    "compound_stmt" : {
        syntax.term("{"),
        syntax.repeat(syntax.cond_or(
            {syntax.ref("var_declaration")},
            {syntax.ref("statement")}
        )),
        syntax.term("}")
    },
    "var_declaration" : {
        syntax.ref("type_specifier"), syntax.token("id"),
        syntax.optional(syntax.term("["), syntax.token("num"), syntax.term("]")),
        syntax.term(";")
    },
    "statement" : {syntax.cond_or(
        {syntax.ref("expression_stmt")},
        {syntax.ref("compound_stmt")},
        {syntax.ref("selection_stmt")},
        {syntax.ref("iteration_stmt")},
        {syntax.ref("return_stmt")}
    )},
    "expression_stmt" : {syntax.cond_or(
        {syntax.term(";")},
        {syntax.ref("expression"), syntax.term(";")}
    )},
    "selection_stmt" : {
        syntax.term("if"), syntax.term("("), syntax.ref("expression"), syntax.term(")"), syntax.ref("statement"),
        syntax.optional(syntax.term("else"), syntax.ref("statement"))
    },
    "iteration_stmt" : {
        syntax.term("while"), syntax.term("("), syntax.ref("expression"), syntax.term(")"), syntax.ref("statement")
    },
    "return_stmt" : {
        syntax.term("return"), syntax.optional(syntax.ref("expression")), syntax.term(";")
    },
    "expression" : {syntax.cond_or(
        {syntax.ref("var"), syntax.term("="), syntax.ref("expression")},
        {syntax.ref("simple_expression")}
    )},
    "var" : {
        syntax.token("id"), syntax.optional(syntax.term("["), syntax.ref("expression"), syntax.term("]"))
    },
    "simple_expression" : {
        syntax.ref("additive_expression"), syntax.optional(syntax.ref("relop"), syntax.ref("additive_expression"))
    },
    "relop" : {syntax.cond_or(
        {syntax.term("<=")},
        {syntax.term("<")},
        {syntax.term(">=")},
        {syntax.term(">")},
        {syntax.term("==")},
        {syntax.term("~=")}
    )},
    "additive_expression" : {
        syntax.ref("term"), syntax.repeat(syntax.ref("addop"), syntax.ref("term"))
    },
    "addop" : {syntax.cond_or(
        {syntax.term("+")},
        {syntax.term("-")}
    )},
    "term" : {
        syntax.ref("factor"), syntax.repeat(syntax.ref("mulop"), syntax.ref("term"))
    },
    "mulop" : {syntax.cond_or(
        {syntax.term("*")},
        {syntax.term("/")}
    )},
    "factor" : {syntax.cond_or(
        {syntax.term("("), syntax.ref("expression"), syntax.term(")")},
        {syntax.token("id"), syntax.optional(syntax.ref("factor_s"))},
        {syntax.token("num")}
    )},
    "factor_s" : {syntax.cond_or(
        {syntax.term("["), syntax.ref("expression"), syntax.term("]")},
        {syntax.term("("), syntax.optional(syntax.ref("args")), syntax.term(")")}
    )},
    "args" : {
        syntax.ref("expression"), syntax.repeat(syntax.term(","), syntax.ref("expression"))
    }
}.to_hash_map()
@end

# ======== SECTION 1: CODEGEN GENERATION ========

system.out.println("=== Codegen Generation Test ===")

block
    var tgram = new parsergen.grammar
    tgram.ext = ".*\\.tny"
    tgram.lex = tiny_lex
    tgram.stx = tiny_stx

    var tgen = new parsergen_codegen.code_generator
    tgen.generate("tiny_gen_parser", tgram, tiny_lex_regexes, "./unit_tests/tiny_gen_parser.csp")
    system.out.println("Generated: unit_tests/tiny_gen_parser.csp")
    assert_true("tiny_gen_parser.csp created", true)
end

block
    var cgram = new parsergen.grammar
    cgram.ext = ".*\\.c-"
    cgram.lex = cminus_lex
    cgram.stx = cminus_stx

    var cgen = new parsergen_codegen.code_generator
    cgen.generate("cminus_gen_parser", cgram, cminus_lex_regexes, "./unit_tests/cminus_gen_parser.csp")
    system.out.println("Generated: unit_tests/cminus_gen_parser.csp")
    assert_true("cminus_gen_parser.csp created", true)
end

# ======== SECTION 2: AST COMPARISON - JSON ========

system.out.println("")
system.out.println("=== AST Comparison: JSON ===")

@begin
var json_tests = {
    "{}",
    "[]",
    "{\"a\": 1}",
    "[1, 2, 3]",
    "{\"x\": true, \"y\": [null, false]}",
    "{\"nested\": {\"deep\": {\"key\": \"val\"}}}"
}
@end

block
    var gram = new parsergen.grammar
    gram.lex = json_lex
    gram.stx = json_stx

    foreach input in json_tests
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("json", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        assert_true("json dyn: parse '" + input + "'", dyn_gen.from_string("json", input))
        var dyn_sig = ast_signature(dyn_gen.ast)

        var gen_gen = new test_json_parser.generator
        assert_true("json gen: parse '" + input + "'", gen_gen.from_string(input))
        var gen_sig = ast_signature(gen_gen.ast)

        assert_true("json AST match: '" + input + "'", dyn_sig == gen_sig)
    end
end

# ======== SECTION 3: AST COMPARISON - ECS ========

system.out.println("")
system.out.println("=== AST Comparison: ECS ===")

function make_ecs_test1()
    var result = new string
    result += "package test"
    result += '\n'
    result += "import parsergen"
    result += '\n'
    result += "var x = 1 + 2 * 3"
    result += '\n'
    result += "function foo(a, b)"
    result += '\n'
    result += "    return a + b"
    result += '\n'
    result += "end"
    result += '\n'
    return move(result)
end

function make_ecs_test2()
    var result = new string
    result += "if x > 0"
    result += '\n'
    result += "    var y = x * 2"
    result += '\n'
    result += "else"
    result += '\n'
    result += "    var y = 0"
    result += '\n'
    result += "end"
    result += '\n'
    return move(result)
end

function make_ecs_test3()
    var result = new string
    result += "class foo extends bar"
    result += '\n'
    result += "    var x = 0"
    result += '\n'
    result += "    function get()"
    result += '\n'
    result += "        return x"
    result += '\n'
    result += "    end"
    result += '\n'
    result += "end"
    result += '\n'
    return move(result)
end

var ecs_test1 = make_ecs_test1()
var ecs_test2 = make_ecs_test2()
var ecs_test3 = make_ecs_test3()

block
    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("ecs", ecs_parser.grammar)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    assert_true("ecs dyn: test1", dyn_gen.from_string("ecs", ecs_test1))
    var gen_gen = new ecs_gen_parser.generator
    assert_true("ecs gen: test1", gen_gen.from_string(ecs_test1))
    compare_ast("ecs test1", dyn_gen.ast, gen_gen.ast)
end

block
    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("ecs", ecs_parser.grammar)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    assert_true("ecs dyn: test2", dyn_gen.from_string("ecs", ecs_test2))
    var gen_gen = new ecs_gen_parser.generator
    assert_true("ecs gen: test2", gen_gen.from_string(ecs_test2))
    compare_ast("ecs test2", dyn_gen.ast, gen_gen.ast)
end

block
    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("ecs", ecs_parser.grammar)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    assert_true("ecs dyn: test3", dyn_gen.from_string("ecs", ecs_test3))
    var gen_gen = new ecs_gen_parser.generator
    assert_true("ecs gen: test3", gen_gen.from_string(ecs_test3))
    compare_ast("ecs test3", dyn_gen.ast, gen_gen.ast)
end

# ======== SECTION 4: AST COMPARISON - TINY ========

system.out.println("")
system.out.println("=== AST Comparison: TINY ===")

var tiny_tests = new array
tiny_tests.push_back("x := 5")
tiny_tests.push_back("read x")
tiny_tests.push_back("write x + 1")
tiny_tests.push_back("if 0 < x then x := 1 end")
tiny_tests.push_back("repeat x := x + 1 until x = 0")
tiny_tests.push_back("x := 1; y := 2")
tiny_tests.push_back("x := 1; y := 2;")
tiny_tests.push_back("read x; if 0 < x then fact := 1; repeat fact := fact * x; x := x - 1 until x = 0; write fact end")

block
    var gram = new parsergen.grammar
    gram.lex = tiny_lex
    gram.stx = tiny_stx

    foreach input in tiny_tests
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("tiny", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        assert_true("tiny dyn: parse '" + input + "'", dyn_gen.from_string("tiny", input))
        var dyn_sig = ast_signature(dyn_gen.ast)

        var gen_gen = new tiny_gen_parser.generator
        assert_true("tiny gen: parse '" + input + "'", gen_gen.from_string(input))
        var gen_sig = ast_signature(gen_gen.ast)

        assert_true("tiny AST match: '" + input + "'", dyn_sig == gen_sig)
    end
end

# ======== SECTION 5: AST COMPARISON - CMINUS ========

system.out.println("")
system.out.println("=== AST Comparison: C-MINUS ===")

var cminus_tests = new array
cminus_tests.push_back("int x[10];")
cminus_tests.push_back("void main(void) { }")
cminus_tests.push_back("int x[10]; void main(void) { x = 5; }")
cminus_tests.push_back("int gcd(int u, int v) { if (v == 0) return u; else return gcd(v, u-u/v*v); }")
cminus_tests.push_back("int x[10];")
cminus_tests.push_back("int minloc(int a[], int low, int high) { int i; int x; int k; k = low; x = a[low]; i = low + 1; while (i < high) { if (a[i] < x) { x = a[i]; k = i; } i = i + 1; } return k; }")

block
    var gram = new parsergen.grammar
    gram.lex = cminus_lex
    gram.stx = cminus_stx

    foreach input in cminus_tests
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("c-", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        assert_true("cminus dyn: parse '" + input + "'", dyn_gen.from_string("c-", input))
        var dyn_sig = ast_signature(dyn_gen.ast)

        var gen_gen = new cminus_gen_parser.generator
        assert_true("cminus gen: parse '" + input + "'", gen_gen.from_string(input))
        var gen_sig = ast_signature(gen_gen.ast)

        assert_true("cminus AST match: '" + input + "'", dyn_sig == gen_sig)
    end
end

# ======== SECTION 6: ERROR HANDLING CONSISTENCY ========

system.out.println("")
system.out.println("=== Error Handling Consistency ===")

block
    var json_invalid = {"{", "[}]", "{\"a\":}", "[:", "{\"a\" 1}"}
    var gram = new parsergen.grammar
    gram.lex = json_lex
    gram.stx = json_stx

    foreach input in json_invalid
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("json", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        var dyn_ok = dyn_gen.from_string("json", input)

        var gen_gen = new test_json_parser.generator
        var gen_ok = gen_gen.from_string(input)

        assert_true("json err consistent: '" + input + "'", dyn_ok == gen_ok)
    end
end

block
    var tiny_invalid = {"x = 5", "if x then end", "repeat until 0", "read", "write", "x : 5"}
    var gram = new parsergen.grammar
    gram.lex = tiny_lex
    gram.stx = tiny_stx

    foreach input in tiny_invalid
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("tiny", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        var dyn_ok = dyn_gen.from_string("tiny", input)

        var gen_gen = new tiny_gen_parser.generator
        var gen_ok = gen_gen.from_string(input)

        assert_true("tiny err consistent: '" + input + "'", dyn_ok == gen_ok)
    end
end

block
    var cminus_invalid = {"int ;", "int x[;]", "void main(;) { }", "x = ;", "return ;", "if (x) y = 5"}
    var gram = new parsergen.grammar
    gram.lex = cminus_lex
    gram.stx = cminus_stx

    foreach input in cminus_invalid
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("c-", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        var dyn_ok = dyn_gen.from_string("c-", input)

        var gen_gen = new cminus_gen_parser.generator
        var gen_ok = gen_gen.from_string(input)

        assert_true("cminus err consistent: '" + input + "'", dyn_ok == gen_ok)
    end
end

block
    var ecs_invalid = {"var = 5", "if end", "function () end", "class end", "return ;"}
    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("ecs", ecs_parser.grammar)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false

    foreach input in ecs_invalid
        var dyn_ok = dyn_gen.from_string("ecs", input)

        var gen_gen = new ecs_gen_parser.generator
        var gen_ok = gen_gen.from_string(input)

        assert_true("ecs err consistent: '" + input + "'", dyn_ok == gen_ok)
    end
end

# ======== SECTION 7: REUSE TEST ========

system.out.println("")
system.out.println("=== Reuse Test ===")

block
    var json_inputs = {"{}", "[]", "{\"a\": 1}"}
    var gen_gen = new test_json_parser.generator
    foreach input in json_inputs
        assert_true("json reuse: '" + input + "'", gen_gen.from_string(input))
    end
end

block
    var tiny_inputs = {"x := 1", "read x", "write 0"}
    var gen_gen = new tiny_gen_parser.generator
    foreach input in tiny_inputs
        assert_true("tiny reuse: '" + input + "'", gen_gen.from_string(input))
    end
end

block
    var cminus_inputs = {"int x[10];", "void main(void) { }", "int x[10]; void f(void) { return; }"}
    var gen_gen = new cminus_gen_parser.generator
    foreach input in cminus_inputs
        assert_true("cminus reuse: '" + input + "'", gen_gen.from_string(input))
    end
end

block
    var ecs_inputs = {ecs_test1, ecs_test2, ecs_test3}
    var gen_gen = new ecs_gen_parser.generator
    foreach input in ecs_inputs
        assert_true("ecs reuse: parse", gen_gen.from_string(input))
    end
end

# ======== SECTION 8: FROM_FILE TEST ========

system.out.println("")
system.out.println("=== from_file Test ===")

block
    var temp_path = "./_test_temp.tny"
    var os = iostream.ofstream(temp_path)
    os.println("x := 3 + 4 * 5;")
    os.println("write x")

    var gram = new parsergen.grammar
    gram.ext = ".*\\.tny"
    gram.lex = tiny_lex
    gram.stx = tiny_stx

    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("tiny", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    assert_true("dyn from_file tiny", dyn_gen.from_file(temp_path))
    var dyn_sig = ast_signature(dyn_gen.ast)

    var gen_gen = new tiny_gen_parser.generator
    assert_true("gen from_file tiny", gen_gen.from_file(temp_path))
    var gen_sig = ast_signature(gen_gen.ast)

    assert_true("from_file AST match", dyn_sig == gen_sig)
end

block
    var temp_path = "./_test_temp.json"
    var os = iostream.ofstream(temp_path)
    os.println("{")
    os.println("    \"key\": [1, 2, 3]")
    os.println("}")

    var gram = new parsergen.grammar
    gram.ext = ".*\\.json"
    gram.lex = json_lex
    gram.stx = json_stx

    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("json", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    assert_true("dyn from_file json", dyn_gen.from_file(temp_path))
    var dyn_sig = ast_signature(dyn_gen.ast)

    var gen_gen = new test_json_parser.generator
    assert_true("gen from_file json", gen_gen.from_file(temp_path))
    var gen_sig = ast_signature(gen_gen.ast)

    assert_true("from_file json AST match", dyn_sig == gen_sig)
end

# ======== SECTION 9: EMPTY INPUT TEST ========

system.out.println("")
system.out.println("=== Empty Input Test ===")

block
    var gram = new parsergen.grammar
    gram.lex = json_lex
    gram.stx = json_stx

    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("json", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    var dyn_ok = dyn_gen.from_string("json", "")

    var gen_gen = new test_json_parser.generator
    var gen_ok = gen_gen.from_string("")

    assert_true("json empty consistent", dyn_ok == gen_ok)
end

block
    var gram = new parsergen.grammar
    gram.lex = tiny_lex
    gram.stx = tiny_stx

    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("tiny", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    var dyn_ok = dyn_gen.from_string("tiny", "")

    var gen_gen = new tiny_gen_parser.generator
    var gen_ok = gen_gen.from_string("")

    assert_true("tiny empty consistent", dyn_ok == gen_ok)
end

block
    var gram = new parsergen.grammar
    gram.lex = cminus_lex
    gram.stx = cminus_stx

    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("c-", gram)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    var dyn_ok = dyn_gen.from_string("c-", "")

    var gen_gen = new cminus_gen_parser.generator
    var gen_ok = gen_gen.from_string("")

    assert_true("cminus empty consistent", dyn_ok == gen_ok)
end

block
    var dyn_gen = new parsergen.generator
    dyn_gen.add_grammar("ecs", ecs_parser.grammar)
    dyn_gen.stop_on_error = true
    dyn_gen.show_prompt = false
    var dyn_ok = dyn_gen.from_string("ecs", "")

    var gen_gen = new ecs_gen_parser.generator
    var gen_ok = gen_gen.from_string("")

    assert_true("ecs empty consistent", dyn_ok == gen_ok)
end

# ======== SECTION 10: PERFORMANCE COMPARISON ========

system.out.println("")
system.out.println("=== Performance Comparison ===")

# JSON performance
system.out.println("--- JSON ---")
@begin
var json_perf = "{\n" +
    "\"widget\": {\n" +
    "    \"debug\": true,\n" +
    "    \"window\": {\n" +
    "        \"title\": \"Sample\",\n" +
    "        \"name\": \"main\",\n" +
    "        \"width\": 500,\n" +
    "        \"height\": 400\n" +
    "    },\n" +
    "    \"image\": {\n" +
    "        \"src\": \"Images/Sun.png\",\n" +
    "        \"name\": \"sun1\",\n" +
    "        \"hOffset\": 250,\n" +
    "        \"vOffset\": 100,\n" +
    "        \"alignment\": \"center\"\n" +
    "    },\n" +
    "    \"text\": {\n" +
    "        \"data\": \"Click Here\",\n" +
    "        \"size\": 36,\n" +
    "        \"style\": \"bold\",\n" +
    "        \"name\": \"text1\",\n" +
    "        \"hOffset\": 250,\n" +
    "        \"vOffset\": 200,\n" +
    "        \"alignment\": \"center\",\n" +
    "        \"onMouseUp\": \"sun1.opacity = 50\"\n" +
    "    }\n" +
    "}}\n"
@end

block
    var gram = new parsergen.grammar
    gram.lex = json_lex
    gram.stx = json_stx

    var dyn_times = new array
    for i = 0, i < 5, ++i
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("json", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        var t0 = runtime.time()
        dyn_gen.from_string("json", json_perf)
        dyn_times.push_back(runtime.time() - t0)
    end

    var gen_times = new array
    for i = 0, i < 5, ++i
        var gen_gen = new test_json_parser.generator
        var t0 = runtime.time()
        gen_gen.from_string(json_perf)
        gen_times.push_back(runtime.time() - t0)
    end

    var dyn_avg = 0.0
    foreach t in dyn_times do dyn_avg += t
    dyn_avg = dyn_avg / dyn_times.size

    var gen_avg = 0.0
    foreach t in gen_times do gen_avg += t
    gen_avg = gen_avg / gen_times.size

    system.out.println("JSON input: " + json_perf.size + " chars")
    system.out.println("Dynamic (avg 5 runs): " + dyn_avg + " ms")
    system.out.println("Generated (avg 5 runs): " + gen_avg + " ms")
    if gen_avg < dyn_avg
        system.out.println("Speedup: " + (dyn_avg / gen_avg) + "x")
    end
end

# TINY performance
system.out.println("--- TINY ---")
var tiny_perf = "read x; if 0 < x then fact := 1; repeat fact := fact * x; x := x - 1 until x = 0; write fact end"

block
    var gram = new parsergen.grammar
    gram.lex = tiny_lex
    gram.stx = tiny_stx

    var dyn_times = new array
    for i = 0, i < 5, ++i
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("tiny", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        var t0 = runtime.time()
        dyn_gen.from_string("tiny", tiny_perf)
        dyn_times.push_back(runtime.time() - t0)
    end

    var gen_times = new array
    for i = 0, i < 5, ++i
        var gen_gen = new tiny_gen_parser.generator
        var t0 = runtime.time()
        gen_gen.from_string(tiny_perf)
        gen_times.push_back(runtime.time() - t0)
    end

    var dyn_avg = 0.0
    foreach t in dyn_times do dyn_avg += t
    dyn_avg = dyn_avg / dyn_times.size

    var gen_avg = 0.0
    foreach t in gen_times do gen_avg += t
    gen_avg = gen_avg / gen_times.size

    system.out.println("TINY input: " + tiny_perf.size + " chars")
    system.out.println("Dynamic (avg 5 runs): " + dyn_avg + " ms")
    system.out.println("Generated (avg 5 runs): " + gen_avg + " ms")
    if gen_avg < dyn_avg
        system.out.println("Speedup: " + (dyn_avg / gen_avg) + "x")
    end
end

# CMINUS performance
system.out.println("--- C-MINUS ---")
var cminus_perf = "int minloc(int a[], int low, int high) { int i; int x; int k; k = low; x = a[low]; i = low + 1; while (i < high) { if (a[i] < x) { x = a[i]; k = i; } i = i + 1; } return k; }"

block
    var gram = new parsergen.grammar
    gram.lex = cminus_lex
    gram.stx = cminus_stx

    var dyn_times = new array
    for i = 0, i < 5, ++i
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("c-", gram)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        var t0 = runtime.time()
        dyn_gen.from_string("c-", cminus_perf)
        dyn_times.push_back(runtime.time() - t0)
    end

    var gen_times = new array
    for i = 0, i < 5, ++i
        var gen_gen = new cminus_gen_parser.generator
        var t0 = runtime.time()
        gen_gen.from_string(cminus_perf)
        gen_times.push_back(runtime.time() - t0)
    end

    var dyn_avg = 0.0
    foreach t in dyn_times do dyn_avg += t
    dyn_avg = dyn_avg / dyn_times.size

    var gen_avg = 0.0
    foreach t in gen_times do gen_avg += t
    gen_avg = gen_avg / gen_times.size

    system.out.println("C-MINUS input: " + cminus_perf.size + " chars")
    system.out.println("Dynamic (avg 5 runs): " + dyn_avg + " ms")
    system.out.println("Generated (avg 5 runs): " + gen_avg + " ms")
    if gen_avg < dyn_avg
        system.out.println("Speedup: " + (dyn_avg / gen_avg) + "x")
    end
end

# ECS performance
system.out.println("--- ECS ---")

block
    var dyn_times = new array
    for i = 0, i < 3, ++i
        var dyn_gen = new parsergen.generator
        dyn_gen.add_grammar("ecs", ecs_parser.grammar)
        dyn_gen.stop_on_error = true
        dyn_gen.show_prompt = false
        var t0 = runtime.time()
        dyn_gen.from_string("ecs", ecs_test1)
        dyn_times.push_back(runtime.time() - t0)
    end

    var gen_times = new array
    for i = 0, i < 3, ++i
        var gen_gen = new ecs_gen_parser.generator
        var t0 = runtime.time()
        gen_gen.from_string(ecs_test1)
        gen_times.push_back(runtime.time() - t0)
    end

    var dyn_avg = 0.0
    foreach t in dyn_times do dyn_avg += t
    dyn_avg = dyn_avg / dyn_times.size

    var gen_avg = 0.0
    foreach t in gen_times do gen_avg += t
    gen_avg = gen_avg / gen_times.size

    system.out.println("ECS input: " + ecs_test1.size + " chars")
    system.out.println("Dynamic (avg 3 runs): " + dyn_avg + " ms")
    system.out.println("Generated (avg 3 runs): " + gen_avg + " ms")
    if gen_avg < dyn_avg
        system.out.println("Speedup: " + (dyn_avg / gen_avg) + "x")
    end
end

# ======== SUMMARY ========
system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
