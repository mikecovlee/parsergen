import parsergen, parsergen_codegen, regex

constant syntax = parsergen.syntax

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
var test_lex_regexes = {
    "id"  : "^[a-z]+$",
    "num" : "^[0-9]+$",
    "op"  : "^(\\+|-|\\*|/|=|;|\\(|\\)|,)$",
    "endl": "^\\n+$",
    "ign" : "^[ \\t]+$",
    "err" : "^@$"
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
var nested_lex_regexes = {
    "num" : "^[0-9]+$",
    "sig" : "^(\\(|\\)|,)$",
    "ign" : "^\\s+$",
    "err" : "^@$"
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

@begin
var condor_lex_regexes = {
    "id" : "^[a-z]+$",
    "num" : "^[0-9]+$",
    "ign" : "^\\s+$",
    "err" : "^@$"
}.to_hash_map()
@end

# ======== Test 1: nlook (negative lookahead) ========
@begin
var nlook_stx = {
    "begin" : {syntax.ref("items"), syntax.term("end")},
    "items" : {syntax.repeat(syntax.nlook(syntax.term("end")), syntax.token("id"))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var gram = new parsergen.grammar
    gram.ext = ".*\\.nlook"
    gram.lex = test_lex
    gram.stx = nlook_stx
    
    var gen = new parsergen_codegen.code_generator
    gen.generate("test_nlook_parser", gram, test_lex_regexes, "./unit_tests/test_nlook_parser.csp")
    system.out.println("Generated: unit_tests/test_nlook_parser.csp")
end

# ======== Test 2: Complex repeat with backtracking ========
@begin
var repeat_bt_stx = {
    "begin" : {syntax.ref("stmts")},
    "stmts" : {syntax.repeat(syntax.ref("stmt"))},
    "stmt" : {syntax.token("id"), syntax.term("="), syntax.token("num"), syntax.term(";")},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

block
    var gram = new parsergen.grammar
    gram.ext = ".*\\.rbt"
    gram.lex = test_lex
    gram.stx = repeat_bt_stx
    
    var gen = new parsergen_codegen.code_generator
    gen.generate("test_repeat_bt_parser", gram, test_lex_regexes, "./unit_tests/test_repeat_bt_parser.csp")
    system.out.println("Generated: unit_tests/test_repeat_bt_parser.csp")
end

# ======== Test 3: Deeply nested structures ========
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
    var gram = new parsergen.grammar
    gram.ext = ".*\\.nest"
    gram.lex = nested_lex
    gram.stx = nested_stx
    
    var gen = new parsergen_codegen.code_generator
    gen.generate("test_nested_parser", gram, nested_lex_regexes, "./unit_tests/test_nested_parser.csp")
    system.out.println("Generated: unit_tests/test_nested_parser.csp")
end

# ======== Test 4: Multiple cond_or branches ========
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
    var gram = new parsergen.grammar
    gram.ext = ".*\\.condor"
    gram.lex = condor_lex
    gram.stx = condor_stx
    
    var gen = new parsergen_codegen.code_generator
    gen.generate("test_condor_parser", gram, condor_lex_regexes, "./unit_tests/test_condor_parser.csp")
    system.out.println("Generated: unit_tests/test_condor_parser.csp")
end

# ======== Test 5: Optional with complex content ========
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
    var gram = new parsergen.grammar
    gram.ext = ".*\\.optc"
    gram.lex = test_lex
    gram.stx = opt_complex_stx
    
    var gen = new parsergen_codegen.code_generator
    gen.generate("test_opt_complex_parser", gram, test_lex_regexes, "./unit_tests/test_opt_complex_parser.csp")
    system.out.println("Generated: unit_tests/test_opt_complex_parser.csp")
end

system.out.println("")
system.out.println("All parsers generated successfully!")
