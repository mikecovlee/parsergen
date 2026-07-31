import parsergen, regex
import ecs_parser

# Build grammar with string patterns (new style)
var gram = new parsergen.grammar
gram.ext = ".*\\.(csp|csc|ecs|ecsx)"
@begin
gram.lex = {
    "endl" : "^\\n+$",
    "id" :   "^[A-Za-z_\\p{Han}](\\w|\\p{Han})*$",
    "num" :  "^[0-9]+\\.?([0-9]+)?$",
    "str" :  "^(\"|\"([^\"]|\\\\\")*\"?)$",
    "char" : "^(\'|\'([^\']|\\\\(0|\\\\|\'|\"|\\w))\'?)$",
    "bsig" : "^(;|:=?|::|\\?|\\.\\.?|\\.\\.\\.)$",
    "msig" : "^(\\+(\\+|=)?|-(-|=|>)?|\\*=?|/=?|%=?|\\^=?)$",
    "lsig" : "^(>|<|&|(\\|)|&&|(\\|\\|)|!|=(=|>)?|!=?|>=?|<=?)$",
    "brac" : "^(\\(|\\)|\\[|\\]|\\{|\\}|,)$",
    "prep" : "^@.*$",
    "err" :  "^(\"|\'|(\\|)|\\.\\.)$",
    "ign" :  "^([ \\f\\r\\t]+|#.*)$"
}.to_hash_map()
@end
gram.stx := ecs_parser.get_syntax(false)

var gen = new parsergen.generator
gen.stop_on_error = true
gen.show_prompt = false
gen.add_language("ecs-lang", "ascii", gram)

var file = context.cmd_args.at(1)
if gen.from_file(file)
    system.out.println("PARSE OK")
else
    system.out.println("PARSE FAIL")
    foreach it in gen.get_errors()
        system.out.println("  Line " + (it.pos[1] + 1) + ": " + it.text)
    end
end
