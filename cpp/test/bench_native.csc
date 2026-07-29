import parsergen
import ecs_parser

var gen = new parsergen.generator
gen.stop_on_error = true
gen.show_prompt = false
gen.add_language("ecs-lang", "ascii", ecs_parser.grammar)

var file = context.cmd_args.at(1)
var rounds = 3

var t0 = runtime.time()
for i = 0, i < rounds, ++i
    gen.from_file(file)
end
var t1 = runtime.time()

system.out.println("Time: " + (t1 - t0) / 1000 + " ms (" + rounds + " rounds)")
