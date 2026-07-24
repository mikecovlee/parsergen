import parsergen, regex
import ecs_parser

function dump_ast(tree, indent)
    if tree == null
        return
    end
    foreach it in tree.nodes
        if typeid it == typeid parsergen.syntax_tree
            system.out.println(indent + "(" + it.root)
            dump_ast(it, indent + "  ")
            system.out.println(indent + ")")
        end
        if typeid it == typeid parsergen.token_type
            system.out.println(indent + "[" + it.type + " " + it.data + "]")
        end
    end
end

var gen = new parsergen.generator
gen.stop_on_error = true
gen.show_prompt = false
gen.add_grammar("ecs-lang", ecs_parser.grammar)

var file = context.cmd_args.at(1)
if gen.from_file(file)
    system.out.println("PARSE OK")
    dump_ast(gen.ast, "")
else
    system.out.println("PARSE FAIL")
    foreach it in gen.get_errors()
        system.out.println("  Line " + (it.pos[1] + 1) + ": " + it.text)
    end
end
