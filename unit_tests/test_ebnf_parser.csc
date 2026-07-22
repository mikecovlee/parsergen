import ebnf_parser, parsergen

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

system.out.println("=== EBNF Parser Tests ===")

block
    var p = new ebnf_parser.parser
    assert_true("simple rule", p.parse("expr = term ;"))
    var stx = p.get_syntax()
    assert_true("rule exists", stx.exist("expr"))
    assert_eq("rule count", stx.size, 1)
end

block
    var p = new ebnf_parser.parser
    assert_true("multiple rules", p.parse("a = b ; b = \"x\" ;"))
    var stx = p.get_syntax()
    assert_eq("two rules", stx.size, 2)
    assert_true("rule a", stx.exist("a"))
    assert_true("rule b", stx.exist("b"))
end

block
    var p = new ebnf_parser.parser
    assert_true("alternatives", p.parse("x = \"a\" | \"b\" | \"c\" ;"))
    var stx = p.get_syntax()
    assert_eq("one rule", stx.size, 1)
    assert_eq("cond_or element", stx.at("x")[0].type, parsergen.syntax_type.cond)
end

block
    var p = new ebnf_parser.parser
    assert_true("optional", p.parse("x = \"a\" [ \"b\" ] ;"))
    var stx = p.get_syntax()
    var seq = stx.at("x")
    assert_eq("seq size", seq.size, 2)
    assert_eq("second is opt", seq[1].type, parsergen.syntax_type.opt)
end

block
    var p = new ebnf_parser.parser
    assert_true("repetition", p.parse("x = { \"a\" } ;"))
    var stx = p.get_syntax()
    var seq = stx.at("x")
    assert_eq("seq size", seq.size, 1)
    assert_eq("is repeat", seq[0].type, parsergen.syntax_type.repeat)
end

block
    var p = new ebnf_parser.parser
    assert_true("token ref", p.parse("x = <id> ;"))
    var stx = p.get_syntax()
    var seq = stx.at("x")
    assert_eq("seq size", seq.size, 1)
    assert_eq("is token", seq[0].type, parsergen.syntax_type.token)
    assert_eq("token name", seq[0].data, "id")
end

block
    var p = new ebnf_parser.parser
    assert_true("nlook", p.parse("x = !(<endl>) \"a\" ;"))
    var stx = p.get_syntax()
    var seq = stx.at("x")
    assert_eq("seq size", seq.size, 2)
    assert_eq("first is nlook", seq[0].type, parsergen.syntax_type.nlook)
end

block
    var p = new ebnf_parser.parser
    assert_true("group", p.parse("x = (\"a\" | \"b\") \"c\" ;"))
    var stx = p.get_syntax()
    var seq = stx.at("x")
    assert_eq("seq size", seq.size, 2)
    assert_eq("first is cond", seq[0].type, parsergen.syntax_type.cond)
end

block
    var p = new ebnf_parser.parser
    assert_true("comment ignored", p.parse("(* comment *) x = \"a\" ;"))
    var stx = p.get_syntax()
    assert_true("rule exists", stx.exist("x"))
end

block
    var p = new ebnf_parser.parser
    assert_true("string escape", p.parse("x = \"\\\"\" ;"))
    var stx = p.get_syntax()
    var seq = stx.at("x")
    assert_eq("term is quote", seq[0].data, "\"")
end

block
    var p = new ebnf_parser.parser
    assert_false("invalid syntax", p.parse("= ;"))
    assert_true("has error msg", p.get_error() != null)
end

block
    var p = new ebnf_parser.parser
    assert_true("ref in rule", p.parse("a = b ; b = \"x\" ;"))
    var stx = p.get_syntax()
    var seq = stx.at("a")
    assert_eq("is ref", seq[0].type, parsergen.syntax_type.ref)
    assert_eq("ref name", seq[0].data, "b")
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
