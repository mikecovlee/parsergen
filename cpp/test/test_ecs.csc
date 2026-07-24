import parsergen, regex
import ecs_parser

var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.set_stop_on_error(false)
gen.add_grammar("ecs-lang", ecs_parser.grammar)

var file = context.cmd_args.at(1)
system.out.println("Parsing: " + file)
var ok = gen.from_file(file)
system.out.println("Result: " + ok)

var errors = gen.get_errors()
system.out.println("Errors: " + errors.size)
foreach it in errors
    system.out.println("  Line " + (it.pos()[1] + 1) + ": " + it.text())
end
