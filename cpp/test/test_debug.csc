import parsergen_cxx as parsergen
import regex

constant syntax = parsergen.syntax

var gram = new parsergen.grammar
gram.set_ext(".*")

@begin
var lex = {
    "id" : regex.build("^[a-z]+$"),
    "ign" : regex.build("^\\s+$")
}.to_hash_map()
@end
gram.set_lex(lex)

@begin
var stx = {
    "begin" : {syntax.token("id")}
}.to_hash_map()
@end
gram.set_stx(stx)

var gen = new parsergen.generator
gen.set_show_prompt(true)
gen.add_grammar("test", gram)

system.out.println("parsing 'hello'...")
var ok = gen.from_string("test", "hello")
system.out.println("result = " + ok)

var errors = gen.get_errors()
system.out.println("errors: " + errors.size())
foreach it in errors
    system.out.println("  " + it.text() + " at " + it.pos())
end
