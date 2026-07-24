import parsergen_cxx as parsergen
import regex

system.out.println("1: create grammar")
var gram = parsergen.grammar()
system.out.println("2: set ext")
gram.ext = ".*\\.ecs"
system.out.println("3: get ext = " + gram.ext)

system.out.println("4: set lex")
@begin
var lex = {
    "id" : regex.build("^[a-z]+$"),
    "ign" : regex.build("^\\s+$")
}.to_hash_map()
@end
gram.lex = lex
system.out.println("5: set stx")
constant syntax = parsergen.syntax
@begin
var stx = {
    "begin" : {syntax.token("id")}
}.to_hash_map()
@end
gram.stx = stx

system.out.println("6: create generator")
var gen = parsergen.generator()
gen.show_prompt = false
gen.add_grammar("test", gram)
system.out.println("7: parse")
var ok = gen.from_string("test", "hello")
system.out.println("8: result = " + ok)
system.out.println("ALL OK")
