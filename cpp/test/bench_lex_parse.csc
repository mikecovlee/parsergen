import parsergen, regex
import ecs_parser

var file = context.cmd_args.at(1)
var rounds = 3

var ifs = iostream.ifstream(file)
if !ifs.good()
    system.out.println("Cannot open: " + file)
    system.exit(1)
end
var input = new string
loop
    var line = ifs.getline()
    if ifs.good() || !line.empty()
        input += line + "\n"
    else
        break
    end
end

var compiled_lex = ecs_parser.get_lexical(regex.build_optimize, false)
var stx = ecs_parser.grammar.stx

var lex_total = 0
var parse_total = 0

for i = 0, i < rounds, ++i
    var lexer = new parsergen.lexer_type
    var t0 = runtime.time()
    var tokens = lexer.run(compiled_lex, input)
    var t1 = runtime.time()
    lex_total += (t1 - t0)

    var parser = new parsergen.parser_type
    var t2 = runtime.time()
    var ok = parser.run(stx, tokens)
    var t3 = runtime.time()
    parse_total += (t3 - t2)
end

var lex_avg = lex_total / rounds
var parse_avg = parse_total / rounds
var total = lex_avg + parse_avg

system.out.println("File: " + file)
system.out.println("Rounds: " + rounds)
system.out.println("Lex:   " + lex_avg + " ms (" + (lex_avg * 100 / total) + "%)")
system.out.println("Parse: " + parse_avg + " ms (" + (parse_avg * 100 / total) + "%)")
system.out.println("Total: " + total + " ms")
