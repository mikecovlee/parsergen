import parsergen, visitorgen, ecs_parser

var ofs = iostream.ofstream("./ast_visitor.csp")
(new visitorgen.visitor_generator).run(ofs, ecs_parser.grammar.stx)

var ast_visitor = context.source_import("./ast_visitor.csp")

var parser = new parsergen.generator
var visitor = new ast_visitor.main
parser.add_grammar("ecs-lang", ecs_parser.grammar)
parser.from_file(context.cmd_args.at(1))

if parser.ast != null
    visitor.run(parser.token_buff, parser.ast)
end