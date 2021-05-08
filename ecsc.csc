import parsergen, ecs_parser, ecsc

var parser = new parsergen.generator
var visitor = new ecsc.main
parser.add_grammar("ecs-lang", ecs_parser.grammar)
parser.from_file(context.cmd_args.at(2))

if parser.ast != null
    var ofs = iostream.ofstream(context.cmd_args.at(1))
    visitor.run(ofs, parser.ast)
end