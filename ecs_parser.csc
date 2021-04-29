import parsergen, ecs_parser

function compress_ast(n)
    foreach it in n.nodes
        while typeid it == typeid parsergen.syntax_tree && it.nodes.size == 1
            it = it.nodes.front
        end
        if typeid it == typeid parsergen.syntax_tree
            compress_ast(it)
        else
            if it.type == "endl"
                it.data = "\\n"
            end
        end
    end
end

var parser = new parsergen.generator
parser.add_grammar("ecs-lang", ecs_parser.grammar)

var time_start = runtime.time()
parser.from_file(context.cmd_args.at(1))
system.out.println("Compile Time: " + (runtime.time() - time_start)/1000 + "s")

if parser.ast != null
    compress_ast(parser.ast)
    parsergen.print_ast(parser.ast)
end