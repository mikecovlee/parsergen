import ebnfigen, ecs_parser
var ofs = iostream.ofstream("./ecs-grammar.ebnf")
(new ebnfigen.ebnf_generator).run(ofs, ecs_parser.grammar.stx)
