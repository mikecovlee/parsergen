import parsergen_cxx as parsergen
import regex

constant syntax = parsergen.syntax

@begin
var ecs_lex = {
    "endl" : regex.build("^\\n+$"),
    "id"   : regex.build("^[A-Za-z_]\\w*$"),
    "num"  : regex.build("^[0-9]+\\.?([0-9]+)?$"),
    "str"  : regex.build("^(\"|\"([^\"]|\\\\\")*\"?)$"),
    "sig"  : regex.build("^(\\+|-|\\*|/|=|;|\\(|\\)|\\{|\\}|,)$"),
    "ign"  : regex.build("^([ \\f\\r\\t]+|#.*)$"),
    "err"  : regex.build("^\"$")
}.to_hash_map()
@end

@begin
var ecs_stx = {
    "begin" : {syntax.ref("stmts")},
    "ignore" : {syntax.repeat({syntax.token("endl")})},
    "endline" : {syntax.cond_or({{syntax.token("endl")}, {syntax.term(";")}})},
    "stmts" : {syntax.repeat({syntax.ref("statement"), syntax.repeat({syntax.token("endl")})})},
    "statement" : {syntax.cond_or({
        {syntax.ref("var-stmt")},
        {syntax.ref("expr-stmt")}
    })},
    "var-stmt" : {syntax.term("var"), syntax.token("id"), syntax.term("="), syntax.ref("expr"), syntax.ref("endline")},
    "expr-stmt" : {syntax.ref("expr"), syntax.ref("endline")},
    "expr" : {syntax.ref("term"), syntax.repeat({syntax.cond_or({{syntax.term("+")}, {syntax.term("-")}}), syntax.ref("term")})},
    "term" : {syntax.ref("fact"), syntax.repeat({syntax.cond_or({{syntax.term("*")}, {syntax.term("/")}}), syntax.ref("fact")})},
    "fact" : {syntax.cond_or({
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")},
        {syntax.token("num")},
        {syntax.token("id")},
        {syntax.token("str")}
    })}
}.to_hash_map()
@end

var gram = new parsergen.grammar
gram.set_lex(ecs_lex)
gram.set_stx(ecs_stx)

var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_grammar("ecs", gram)

var pass = 0
var fail = 0

function check(name, cond)
    if cond
        ++pass
    else
        ++fail
        system.out.println("[FAIL] " + name)
    end
end

check("var stmt", gen.from_string("ecs", "var x = 1 + 2 * 3\n"))
check("expr stmt", gen.from_string("ecs", "\"hello\"\n"))
check("multi stmt", gen.from_string("ecs", "var x = 1\nvar y = 2\nx + y\n"))
check("paren", gen.from_string("ecs", "var x = (1 + 2) * 3\n"))
check("comment", gen.from_string("ecs", "# comment\nvar x = 1\n"))
check("semicolon", gen.from_string("ecs", "var x = 1;"))
check("invalid", !gen.from_string("ecs", "var = 1\n"))

system.out.println("ECS subset: Passed " + pass + ", Failed " + fail)
if fail > 0
    system.exit(1)
end
