import visitorgen, ecs_parser

(new visitorgen.visitor_generator).run(system.out, ecs_parser.grammar.stx)