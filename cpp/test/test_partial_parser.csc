import parsergen_cxx as parsergen
import ecs_parser

var cxx_gram = parsergen.make_grammar_from(".*\\.(csp|csc|ecs|ecsx)", ecs_parser.get_lexical_patterns(false), ecs_parser.get_syntax(false))

var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_language("ecs-lang", "ascii", cxx_gram)

var hook_called = false

function on_eof(p)
    hook_called = true
    # Provide the missing expression + newline
    var tokens = gen.lex_string("ecs-lang", "1\n", 0)
    p.push_tokens(tokens)
end

var parser = new parsergen.partial_parser_type
parser.set_eof_hook(on_eof)

# "var x = " is incomplete - needs an expression after "="
# No trailing newline so parser hits EOF mid-rule
var tokens = gen.lex_string("ecs-lang", "var x = ", 0)
var ok = parser.run(ecs_parser.get_syntax(false), tokens)
system.out.println("hook_called: " + hook_called)
system.out.println("parse result: " + ok)
if ok
    var ast = parser.production()
    system.out.println("ast root: " + ast.root)
    system.out.println("PARTIAL PARSER OK")
else
    var err = parser.get_log(0)
    foreach it in err
        system.out.println("  err: " + it.text)
    end
    system.out.println("PARTIAL PARSER FAIL")
end
