import parsergen_cxx as parsergen
import regex

system.out.println("1: create grammar")
var gram = new parsergen.grammar
system.out.println("2: set_ext")
gram.set_ext(".*")
system.out.println("3: get ext = " + gram.ext())
system.out.println("4: create syntax")
constant syntax = parsergen.syntax
var s = syntax.token("id")
system.out.println("5: token type = " + s.type())
system.out.println("6: set_lex")
@begin
var lex = {
    "id" : regex.build("^[a-z]+$"),
    "ign" : regex.build("^\\s+$")
}.to_hash_map()
@end
gram.set_lex(lex)
system.out.println("7: set_stx")
@begin
var stx = {
    "begin" : {syntax.token("id")}
}.to_hash_map()
@end
gram.set_stx(stx)
system.out.println("8: create generator")
var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_grammar("test", gram)
system.out.println("9: parse")
var ok = gen.from_string("test", "hello")
system.out.println("10: result = " + ok)
system.out.println("ALL OK")
