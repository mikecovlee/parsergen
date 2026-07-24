import parsergen
import regex
import ecs_parser

var gen = new parsergen.generator
gen.show_prompt = false
gen.stop_on_error = false
gen.add_grammar("ecs-lang", ecs_parser.grammar)

var pass = 0
var fail = 0

function check(name, cond)
    if cond
        ++pass
    else
        ++fail
        system.out.println("[FAIL] " + name)
    end
end

check("v1.ecs", gen.from_file("tests/test_cases/ecs/v1.ecs"))
check("v2.ecs", gen.from_file("tests/test_cases/ecs/v2.ecs"))
check("v3.ecs", gen.from_file("tests/test_cases/ecs/v3.ecs"))
check("v4.ecs", gen.from_file("tests/test_cases/ecs/v4.ecs"))

system.out.println("ECS full: Passed " + pass + ", Failed " + fail)
if fail > 0
    system.exit(1)
end
