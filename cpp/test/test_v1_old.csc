import parsergen, regex
import ecs_parser, ecs_generator

var gen = new parsergen.generator
gen.add_language("ecs-lang", "ascii", ecs_parser.grammar)
gen.show_prompt = false
gen.from_file("tests/test_cases/ecs/v1.ecs")
if gen.ast == null
    system.out.println("PARSE FAIL")
else
    var codegen = new ecs_generator.generator
    codegen.code_buff = gen.code_buff
    codegen.file_name = "v1.ecs"
    codegen.minimal = true
    var r = codegen.run("./.ecs_output/v1_test", gen.ast)
    if r == null
        system.out.println("CODEGEN FAIL")
    else
        system.out.println("CODEGEN OK: " + r)
    end
end
