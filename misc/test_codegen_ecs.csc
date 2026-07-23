import parsergen_codegen, parsergen, regex, ecs_parser

system.out.println("=== Generate ECS Parser ===")

@begin
var ecs_lex_regexes = {
    "endl" : "^\\n+$",
    "id" :   "^[A-Za-z_]\\w*$",
    "num" :  "^[0-9]+\\.?([0-9]+)?$",
    "str" :  "^(\"|\"([^\"]|\\\\\")*\"?)$",
    "char" : "^(\'|\'([^\']|\\\\(0|\\\\|\'|\"|\\w))\'?)$",
    "bsig" : "^(;|:=?|::|\\?|\\.\\.?|\\.\\.\\.)$",
    "msig" : "^(\\+(\\+|=)?|-(-|=|>)?|\\*=?|/=?|%=?|\\^=?)$",
    "lsig" : "^(>|<|&|(\\|)|&&|(\\|\\|)|!|=(=|>)?|!=?|>=?|<=?)$",
    "brac" : "^(\\(|\\)|\\[|\\]|\\{|\\}|,)$",
    "prep" : "^@.*$",
    "ign" :  "^([ \\f\\r\\t]+|#.*)$",
    "err" :  "^(\"|\'|(\\|)|\\.\\.)$"
}.to_hash_map()
@end

var gen = new parsergen_codegen.code_generator
gen.generate("ecs_gen_parser", ecs_parser.grammar, ecs_lex_regexes, "./unit_tests/ecs_gen_parser.csp")
system.out.println("Generated")

# Quick compile test
system.out.println("")
system.out.println("=== Compile Check ===")
