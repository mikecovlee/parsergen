import ebnf_parser, ebnfigen, parsergen, regex

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

system.out.println("=== EBNF Round-Trip Integration Tests ===")

@begin
var arith_ebnf =
    "(* arithmetic grammar *)\n" +
    "begin = expr ;\n" +
    "expr = term { (\"+\" | \"-\") term } ;\n" +
    "term = factor { (\"*\" | \"/\") factor } ;\n" +
    "factor = <num> | \"(\" expr \")\" ;\n"
@end

@begin
var arith_lex = {
    "num" : regex.build("^[0-9]+$"),
    "op"  : regex.build("^(\\+|-|\\*|/|\\(|\\))$"),
    "ign" : regex.build("^\\s+$")
}.to_hash_map()
@end

block
    var p = new ebnf_parser.parser
    assert_true("roundtrip: parse EBNF", p.parse(arith_ebnf))
    var stx = p.get_syntax()
    assert_true("roundtrip: has begin", stx.exist("begin"))
    assert_true("roundtrip: has expr", stx.exist("expr"))
    assert_true("roundtrip: has term", stx.exist("term"))
    assert_true("roundtrip: has factor", stx.exist("factor"))

    var gram = new parsergen.grammar
    gram.lex = arith_lex
    gram.stx = stx

    var gen = new parsergen.generator
    gen.add_grammar("arith", gram)
    gen.stop_on_error = true
    gen.show_prompt = false

    assert_true("roundtrip: parse '1+2'", gen.from_string("arith", "1+2"))
    assert_true("roundtrip: parse '1+2*3'", gen.from_string("arith", "1+2*3"))
    assert_true("roundtrip: parse '(1+2)*3'", gen.from_string("arith", "(1+2)*3"))
    assert_true("roundtrip: parse '42'", gen.from_string("arith", "42"))
    assert_false("roundtrip: reject '1+'", gen.from_string("arith", "1+"))
    assert_false("roundtrip: reject '(1'", gen.from_string("arith", "(1"))
end

@begin
var stmt_ebnf =
    "begin = { statement } ;\n" +
    "statement = <id> \"=\" <num> \";\" ;\n"
@end

@begin
var stmt_lex = {
    "id"  : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(=|;)$"),
    "ign" : regex.build("^[ \\t\\n]+$")
}.to_hash_map()
@end

block
    var p = new ebnf_parser.parser
    assert_true("roundtrip2: parse EBNF", p.parse(stmt_ebnf))
    var stx = p.get_syntax()

    var gram = new parsergen.grammar
    gram.lex = stmt_lex
    gram.stx = stx

    var gen = new parsergen.generator
    gen.add_grammar("stmt", gram)
    gen.stop_on_error = true
    gen.show_prompt = false

    assert_true("roundtrip2: parse 'x = 1;'", gen.from_string("stmt", "x = 1;"))
    assert_true("roundtrip2: parse multiple", gen.from_string("stmt", "x = 1; y = 2; z = 3;"))
    assert_true("roundtrip2: parse empty", gen.from_string("stmt", ""))
    assert_false("roundtrip2: reject 'x = ;'", gen.from_string("stmt", "x = ;"))
end

system.out.println("")
system.out.println("=== EBNF Export → Re-import Round-Trip ===")

block
    var p = new ebnf_parser.parser
    p.parse(arith_ebnf)
    var stx1 = p.get_syntax()

    var path = "./roundtrip_test.ebnf"
    block
        var ofs = iostream.ofstream(path)
        var gen = new ebnfigen.ebnf_generator
        gen.run(ofs, stx1)
    end

    var ifs = iostream.ifstream(path)
    var lines = new array
    parsergen.read_stream(ifs, lines)
    var exported = new string
    foreach line in lines do exported += line + "\n"

    var p2 = new ebnf_parser.parser
    assert_true("reimport: parse exported EBNF", p2.parse(exported))
    var stx2 = p2.get_syntax()

    assert_true("reimport: same rule count", stx1.size == stx2.size)
    foreach it in stx1
        assert_true("reimport: rule '" + it.first + "' exists", stx2.exist(it.first))
    end

    var gram = new parsergen.grammar
    gram.lex = arith_lex
    gram.stx = stx2

    var gen2 = new parsergen.generator
    gen2.add_grammar("arith2", gram)
    gen2.stop_on_error = true
    gen2.show_prompt = false
    assert_true("reimport: can parse '(1+2)*3'", gen2.from_string("arith2", "(1+2)*3"))
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
