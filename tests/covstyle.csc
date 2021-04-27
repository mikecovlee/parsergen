import parsergen, ecs_parser

var parser = new parsergen.generator
parser.add_grammar("ecs-lang", ecs_parser.grammar)
parser.from_file(context.cmd_args.at(1))

function compress_ast(n)
    foreach it in n.nodes
        while typeid it == typeid parsergen.syntax_tree && it.nodes.size == 1
            it = it.nodes.front
        end
        if typeid it == typeid parsergen.syntax_tree
            compress_ast(it)
        else
            if it.type == "endl"
                it.data = "\n"
            end
        end
    end
end

function format(os, indent, it)
    if typeid it != typeid parsergen.syntax_tree
        os.print(it.data)
        return
    end
    var i = 0
    switch it.root
        case "begin"
            format(os, indent, it.nodes[0])
        end
        case "pacakge-stmt"
            foreach i in range(2*indent) do os.print(' ')
            os.println("package " + it.nodes[1])
        end
        case "import-stmt"
            foreach i in range(2*indent) do os.print(' ')
            os.print("import ")
            format(os, indent, it.nodes[1])
            os.println("")
        end
        case "import-list"
            format(os, indent, it.nodes[i++])
            if it.nodes.size > 1
                if it.nodes[i].data == "as"
                    os.print(" as " + it.nodes[++i].data)
                end
                if it.nodes[i].data == ","
                    os.print(", ")
                    format(os, indent, it.nodes[++i])
                end
            end
        end
        case "module-list"
            os.print(it.nodes[0].data)
            if it.nodes.size > 1
                os.print(".")
                format(os, indent, it.nodes[2])
            end
        end
        case "block-stmt"
            foreach i in range(2*indent) do os.print(' ')
            os.println("block")
            format(os, indent + 1, it.nodes[2])
            foreach i in range(2*indent) do os.print(' ')
            os.println("end")
        end
        case "namespace-stmt"
            foreach i in range(2*indent) do os.print(' ')
            os.println("namespace " + it.nodes[1].data)
            format(os, indent + 1, it.nodes[3])
            foreach i in range(2*indent) do os.print(' ')
            os.println("end")
        end
        case "if-stmt"
            foreach i in range(2*indent) do os.print(' ')
            os.print("if ")
            format(os, indent, it.nodes[1])
            os.println("")
            format(os, indent + 1, it.nodes[3])
            foreach i in range(2*indent) do os.print(' ')
            os.println("end")
        end
        case "expr-stmt"
            foreach i in range(2*indent) do os.print(' ')
            format(os, indent, it.nodes[0])
            os.println("")
        end
        default
            foreach it in it.nodes
                format(os, indent, it)
            end
        end
    end
end

if parser.ast != null
    compress_ast(parser.ast)
    format(system.out, 0, parser.ast)
end