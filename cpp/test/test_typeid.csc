import parsergen_cxx as parsergen
import ecs_parser

var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_language("ecs-lang", "ascii", ecs_parser.grammar)

if gen.from_file("tests/test_cases/ecs/v3.ecs")
    var ast = gen.get_ast()
    foreach it in ast.nodes
        if typeid it == typeid parsergen.syntax_tree
            system.out.println("tree: " + it.root)
        end
        if typeid it == typeid parsergen.token_type
            system.out.println("token: " + it.type + " " + it.data)
        end
    end
    system.out.println("TYPEID OK")
else
    system.out.println("PARSE FAIL")
end
