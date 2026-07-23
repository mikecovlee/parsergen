import ecs_native, ecs_parser, parsergen

var test_pass = 0
var test_fail = 0

function assert_true(name, cond)
    if cond
        ++test_pass
    else
        ++test_fail
        system.out.println("  FAIL: " + name)
    end
end

system.out.println("=== ECS Native Parser Test ===")

@begin
var test1 = "package test" + '\n' + "import parsergen" + '\n' + "var x = 1 + 2 * 3" + '\n' + "function foo(a, b)" + '\n' + "    return a + b" + '\n' + "end" + '\n'
@end

@begin
var test2 = "if x > 0" + '\n' + "    var y = x * 2" + '\n' + "else" + '\n' + "    var y = 0" + '\n' + "end" + '\n'
@end

@begin
var test3 = "class foo extends bar" + '\n' + "    var x = 0" + '\n' + "    function get()" + '\n' + "        return x" + '\n' + "    end" + '\n' + "end" + '\n'
@end

var gen = new ecs_native.generator

assert_true("package test1", gen.from_string(test1))
assert_true("if test2", gen.from_string(test2))
assert_true("class test3", gen.from_string(test3))

system.out.println("")
system.out.println("=== Performance ===")

var perf = "package test" + '\n' + "import parsergen, regex" + '\n' + "var x = 1 + 2 * 3" + '\n' + "function foo(a, b)" + '\n' + "    if a > b" + '\n' + "        return a" + '\n' + "    else" + '\n' + "        return b" + '\n' + "    end" + '\n' + "end" + '\n'

# Dynamic
var dt = 0.0
for i = 0, i < 3, ++i
    var g = new parsergen.generator; g.add_grammar("ecs", ecs_parser.grammar); g.stop_on_error = true; g.show_prompt = false
    var t = runtime.time(); g.from_string("ecs", perf); dt += runtime.time() - t
end
system.out.println("Dynamic (avg 3): " + (dt/3) + " ms")

# Native
var nt = 0.0
for i = 0, i < 3, ++i
    var g = new ecs_native.generator
    var t = runtime.time(); g.from_string(perf); nt += runtime.time() - t
end
system.out.println("Native (avg 3):  " + (nt/3) + " ms")
if nt < dt
    system.out.println("Speedup: " + (dt/nt) + "x")
end

system.out.println("")
system.out.println("Passed: " + test_pass + ", Failed: " + test_fail)
if test_fail > 0
    system.exit(1)
end
