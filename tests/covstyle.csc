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
        case "endline"
            if it.nodes[0].type == "endl"
                os.println("")
            else
                os.println(";")
            end
        end
<<<<<<< Updated upstream
        case "pacakge-stmt"
=======
        case "package-stmt"
>>>>>>> Stashed changes
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
            var index = 0
            for index = 4, index != it.nodes.size-2 , index += 2
                format(os, indent, it.nodes[index])
                format(os, indent + 1, it.nodes[index+1])
            end
            foreach i in range(2*indent) do os.print(' ')
            os.println("end")
        end
        case "var-stmt"
            foreach i in range(2*indent) do os.print(' ')
            os.print(it.nodes[0].data + " ")
            format(os, indent, it.nodes[1])
            format(os, indent, it.nodes[2])
        end
        case "var-def"
            if it.nodes.size > 1
                format(os, indent, it.nodes[0])
                os.print("= ")
                format(os, indent, it.nodes[2])
            else
                format(os, indent, it.nodes[0])
            end
        end
        case "var-bind"
            os.print("(")
            format(os, indent, it.nodes[1])
            for i = 2, it.nodes[i].data !=",", i+=2 
                os.print(",")
                format(os, indent, it.nodes[i+1])
            end 
            os.print(")")
        end
        case "var-bind-list"
            if typeid it.nodes[0] == parsergen.syntax_tree
                format(os, indent, it.nodes[0])
            else
                ps.print(it.nodes[0].data)
            end 
        end
        case "var-list"
            os.print(it.nodes[0].data + " ")
            os.print("= ")
            format(os, indent, it.nodes[2]);
            if it.nodes.size > 3
                os.print(", ")
                format(os, indent, it.nodes[4])
            end
        end
        case "using-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("using ")
            format(os, indent, it.nodes[1])
            format(os, indent, it.nodes[2])
        end
        case "using-list"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(", ")
                format(os, indent, it.nodes[2])
            end
        end
        case "else-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("else ")
            if it.nodes.size > 2
                os.print("if ")
                format(os, indent, it.nodes[2])
            end
            os.println("")
        end
        case "switch-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("switch ")
            format(os, indent, it.nodes[1])
            os.println("")
            format(os, indent, it.nodes[3])
            os.println("end")
        end
        case "switch-stmts"
            for i = 0, i != it.nodes.size, i++
                if typeid it.nodes[i] != typeid parsergen.syntax_tree
                    continue
                else
                    format(os, indent + 1, it.nodes[i])
                end
            end
        end
        case "switch-case"
            foreach i in range(2*indent) do os.print(" ")
            os.print("case ")
            format(os, indent, it.nodes[1])
            os.println("")
            format(os, indent + 1, it.nodes[3])
            foreach i in range(2*indent) do os.print(" ")
            os.println("end")
        end
        case "switch-default"
            foreach i in range(2*indent) do os.print(" ")
            os.println("default")
            format(os, indent + 1, it.nodes[2])
            foreach i in range(2*indent) do os.print(" ")
            os.println("end")
        end
        case "while-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("while ")
            format(os, indent, it.nodes[1])
            os.println("")
            format(os, indent + 1, it.nodes[3])
            foreach i in range(2*indent) do os.print(" ")
            os.println("end")
        end
        case "loop-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.println("loop ")
            format(os, indent + 1, it.nodes[2])
            if it.nodes.size > 4
                foreach i in range(2*indent) do os.print(" ")
                os.println("end")
            else
                format(os, indent, it.nodes[3])
            end
        end
        case "until-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("until ")
            format(os, indent, it.nodes[1])
<<<<<<< Updated upstream
=======
            os.println("")
        end
        case "for-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("for ")
            var num = 0;
            for index = 0, index!= it.nodes.size, index += 0
                if typeid it.nodes[++index] == typeid parsergen.syntax_tree
                    format(os, indent, it.nodes[index])
                else
                    os.print(it.nodes[index].data + " ")
                    num++
                    if num == 2
                        if typeid it.nodes[++index] == typeid parsergen.syntax_tree
                            format(os, indent, it.nodes[index])
                        else
                            index--
                        end
                        i = index
                        break
                    end
                end
            end
            if it.nodes[++i].type == "endl"
                os.println("") 
                format(os, indent + 1, it.nodes[++i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("end")
            else
                os.print(" do ")
                format(os, indent, it.nodes[++i])
                format(os, indent, it.nodes[++i])
            end
        end
        case "foreach-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("foreach ")
            if it.nodes[++i].type == "id"
                os.print(it.nodes[i].data + " ")
            else
                --i
            end
            ++i
            os.print("in ")
            format(os, indent, it.nodes[++i])
            if it.nodes[++i].type == "endl"
                os.println("")
                format(os, indent + 1, it.nodes[++i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("end")
            else
                os.print("do ")
                format(os, indent, it.nodes[++i])
                format(os, indent, it.nodes[++i])
            end
        end
        case "function-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("function ")
            os.print(it.nodes[1].data)
            os.print("(")
            i = 2
            if typeid it.nodes[++i] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[i])
            else
                i--
            end
            ++i
            os.print(") ")
            if it.nodes[++i].data == "override"
                os.print("override")
            else
                --i
            end
            ++i
>>>>>>> Stashed changes
            os.println("")
            if typeid it.nodes[++i] != typeid parsergen.syntax_tree
                foreach index in range(2*indent) do os.print(" ")
                os.print("{")
                os.println("")
                format(os, indent + 1, it.nodes[++i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("}")
            else
                format(os, indent + 1, it.nodes[i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("end")
            end
        end
        case "return-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("return ")
            format(os, indent, it.nodes[1])
            if it.nodes.size > 2 
                format(os, indent, it.nodes[2])
            end
        end
        case "try-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.println("try")
            format(os, indent + 1, it.nodes[2])
            for i = 3, typeid it.nodes[i] != typeid parsergen.syntax_tree, i++
                format(os, indent, it.nodes[i])
                i++
                format(os, indent + 1, it.nodes[i])
            end
            os.println("end")
        end
        case "catch-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("catch ")
            os.print(it.nodes[1].data + " ")
            if it.nodes[2].type != "endl"
                os.print(": ")
                format(os, indent, it.nodes[3])
            end
            os.println("")
        end
        case "throw-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("throw ")
            format(os, indent, it.nodes[1])
            if it.nodes.size > 2
                format(os, indent, it.nodes[2])
            end
        end
        case "class-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print(it.nodes[0].data + " ")
            os.print(it.nodes[1].data + " ")
            i = 2
            if it.nodes.size > 6
                os.print("extends ")
                format(os, indent, it.nodes[3])
                i += 2
            end
            os.println("")
            format(os, indent + 1, it.nodes[++i])
            os.println("end")
        end
        case "class-stmts"
            for i = 0, i < it.nodes.size, i++
                if typeid it.nodes[i] == typeid parsergen.syntax_tree
                    if it.nodes[i].root == "member-control"
                        format(os, indent, it.nodes[i])
                        os.println("")
                    else
                        format(os, indent + 1, it.nodes[i])
                        os.println("")
                    end
                end
            end
        end
        case "member-control"
            foreach i in range(2*indent) do os.print(" ")
            os.print(it.nodes[0])
        end
        case "control-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print(it.nodes[0].data)
            format(os, indent, it.nodes[1])
        end
        case "expr-stmt"
            foreach i in range(2*indent) do os.print(" ")
            format(os, indent, it.nodes[0])
            format(os, indent, it.nodes[1])
        end
        case "expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(", ")
                format(os, indent, it.nodes[2])
            end
        end
        case "single-expr"
            format(os, indent, it.nodes[0])
        end
        case "basic-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                if typeid it.nodes[1] == typeid parsergen.syntax_tree
                    format(os, indent, it.nodes[1])
                    format(os, indent, it.nodes[2])
                else
                    os.print(" = ")
                    format(os, indent, it.nodes[2])
                end    
            end
        end
        case "asi-op"
            os.print(" " + it.nodes[0].data + " ")
        end
        case "lambda-expr"
            os.print("[")
            if typeid it.nodes[++i] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[i])
            else
                i--
            end
            os.print("](")
            i += 2
            if typeid it.nodes[++i] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[i])
            else
                i--
            end
            os.print(")")
            i += 1
            format(os, indent, it.nodes[++i])
        end
        case "capture-list"
            if it.nodes[0].data == "id"
                i = -1
            else
                os.print("= ")
            end
            os.print(it.nodes[++i].data)
            for j = 0, true, null
                if i >= it.size
                    break
                end
                os.print(", ")
                i++
                format(os, indent, it.nodes[++i])
            end
        end
        case "argument-list"
            if it.nodes[0].data == "..."
                os.print("... ")
                os.print(it.nodes[1].data)
            else
                if it.nodes[0].data == "="
                    os.print("=")
                else
                    i -= 1
                end
                os.print(it.nodes[++i].data)
                if i < it.nodes.size - 1
                    if it.nodes[++i].data == ":"
                        os.print(" : ")
                        format(os, indent, it.nodes[++i])
                    else
                        i -= 1
                    end
                end
                for j = 0, true, null 
                    if i >= it.nodes.size - 1
                        break
                    end
                    os.print(", ")
                    ++i
                    format(os, indent, it.nodes[++i])
                end
            end
        end
        case "lambda-body"
            if it.nodes[0].data == "{"
                os.println("{")
                for j = 0, true, null
                    if i >= it.nodes.size - 1
                        break
                    end
                    if typeid it.nodes[i] == typeid parsergen.syntax_tree
                        format(os, indent, it.nodes[i])
                        os.println("")
                    end
                end
                os.println("}")
            else
                os.print("->")
                format(os, indent, it.nodes[1])
            end
        end
        case "cond-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
                if it.nodes.size > 3
                    os.print(" : ")
                    format(os, indent, it.nodes[4])
                end 
            end
        end
        case "logic-or-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "logic-and-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "equal-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "relat-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "add-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "mul-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "unary-expr"
            if typeid it.nodes[0] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[0])
                if it.nodes.size > 1
                    format(os, indent, it.nodes[1])
                end
            else
                os.print(it.nodes[0].data + " ")
                format(os, indent, it.nodes[1])
                if it.nodes.size > 2
                    os.print("{")
                    if typeid it.nodes[3] == typeid parsergen.syntax_tree
                        format(os, indent, it.nodes[3])
                    end
                    os.print("}")
                end
            end
        end
        case "unary-op"
            os.print(it.nodes[0].data)
            if it.nodes[0].data == "typeid"
                os.print(" ")
            end 
        end
        case "postfix-expr"
            os.print(it.nodes[0].data)
            if it.nodes.size > 1
                format(os, indent, it.nodes[1])
            end
        end
        case "prim-expr"
            format(os, indent, it.nodes[0])
        end
        case "visit-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(it.nodes[1].data)
                format(os, indent, it.nodes[2])
            end
        end
        case "object"
            if typeid it.nodes[0] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[0])
                if it.nodes.size > 1
                    format(os, indent, it.nodes[1])
                end
            else
                os.print(it.nodes[0].data)
            end
        end
        case "element"
            if it.nodes[0].type == "id"
                os.print(it.nodes[0].data)
            else
                os.print("(")
                format(os, indent, it.nodes[1])
                os.print(")")
                i += 2
            end
            while true
                if i >= it.nodes.size - 1
                    break
                end
                format(os, indent, it.nodes[++i])
            end
        end
        case "constant"
            os.print(it.nodes[0].data)
        end
        case "array"
            os.print("{")
            if it.nodes.size > 2
                format(os, indent, it.nodes[1])
            end
            os.print("}")
        end
        case "fcall"
            os.print("(")
            if it.nodes.size > 2
                format(os, indent, it.nodes[1])
            end
            os.print(")")
        end
        case "index"
            os.print("[")
            format(os, indent, it.nodes[1])
            os.print("]")
        end
        case "for-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("for ")
            var num = 0;
            for index = 0, index!= it.nodes.size, index += 0
                if typeid it.nodes[++index] == typeid parsergen.syntax_tree
                    format(os, indent, it.nodes[index])
                else
                    os.print(it.nodes[index].data + " ")
                    num++
                    if num == 2
                        if typeid it.nodes[++index] == typeid parsergen.syntax_tree
                            format(os, indent, it.nodes[index])
                        else
                            index--
                        end
                        i = index
                        break
                    end
                end
            end
            if it.nodes[++i].type == "endl"
                os.println("") 
                format(os, indent + 1, it.nodes[++i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("end")
            else
                os.print(" do ")
                format(os, indent, it.nodes[++i])
                format(os, indent, it.nodes[++i])
            end
        end
        case "foreach-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("foreach ")
            if it.nodes[++i].type == "id"
                os.print(it.nodes[i].data + " ")
            else
                --i
            end
            ++i
            os.print("in ")
            format(os, indent, it.nodes[++i])
            if it.nodes[++i].type == "endl"
                os.println("")
                format(os, indent + 1, it.nodes[++i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("end")
            else
                os.print("do ")
                format(os, indent, it.nodes[++i])
                format(os, indent, it.nodes[++i])
            end
        end
        case "function-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("function ")
            os.print(it.nodes[1].data)
            os.print("(")
            i = 2
            if typeid it.nodes[++i] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[i])
            else
                i--
            end
            ++i
            os.print(") ")
            if it.nodes[++i].data == "override"
                os.print("override")
            else
                --i
            end
            ++i
            os.println("")
            if typeid it.nodes[++i] != typeid parsergen.syntax_tree
                foreach index in range(2*indent) do os.print(" ")
                os.print("{")
                os.println("")
                format(os, indent + 1, it.nodes[++i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("}")
            else
                format(os, indent + 1, it.nodes[i])
                foreach index in range(2*indent) do os.print(" ")
                os.println("end")
            end
        end
        case "return-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.print("return ")
            format(os, indent, it.nodes[1])
            if it.nodes.size > 2 
                format(os, indent, it.nodes[2])
            end
        end
        case "try-stmt"
            foreach index in range(2*indent) do os.print(" ")
            os.println("try")
            format(os, indent + 1, it.nodes[2])
            for i = 3, typeid it.nodes[i] != typeid parsergen.syntax_tree, i++
                format(os, indent, it.nodes[i])
                i++
                format(os, indent + 1, it.nodes[i])
            end
            os.println("end")
        end
        case "catch-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("catch ")
            os.print(it.nodes[1].data + " ")
            if it.nodes[2].type != "endl"
                os.print(": ")
                format(os, indent, it.nodes[3])
            end
            os.println("")
        end
        case "throw-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print("throw ")
            format(os, indent, it.nodes[1])
            if it.nodes.size > 2
                format(os, indent, it.nodes[2])
            end
        end
        case "class-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print(it.nodes[0].data + " ")
            os.print(it.nodes[1].data + " ")
            i = 2
            if it.nodes.size > 6
                os.print("extends ")
                format(os, indent, it.nodes[3])
                i += 2
            end
            os.println("")
            format(os, indent + 1, it.nodes[++i])
            os.println("end")
        end
        case "class-stmts"
            for i = 0, i < it.nodes.size, i++
                if typeid it.nodes[i] == typeid parsergen.syntax_tree
                    if it.nodes[i].root == "member-control"
                        format(os, indent, it.nodes[i])
                        os.println("")
                    else
                        format(os, indent + 1, it.nodes[i])
                        os.println("")
                    end
                end
            end
        end
        case "member-control"
            foreach i in range(2*indent) do os.print(" ")
            os.print(it.nodes[0])
        end
        case "control-stmt"
            foreach i in range(2*indent) do os.print(" ")
            os.print(it.nodes[0].data)
            format(os, indent, it.nodes[1])
        end
        case "expr-stmt"
            foreach i in range(2*indent) do os.print(" ")
            format(os, indent, it.nodes[0])
            format(os, indent, it.nodes[1])
        end
        case "expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(", ")
                format(os, indent, it.nodes[2])
            end
        end
        case "single-expr"
            format(os, indent, it.nodes[0])
        end
        case "basic-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                if typeid it.nodes[1] == typeid parsergen.syntax_tree
                    format(os, indent, it.nodes[1])
                    format(os, indent, it.nodes[2])
                else
                    os.print(" = ")
                    format(os, indent, it.nodes[2])
                end    
            end
        end
        case "asi-op"
            os.print(" " + it.nodes[0].data + " ")
        end
        case "lambda-expr"
            os.print("[")
            if typeid it.nodes[++i] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[i])
            else
                i--
            end
            os.print("](")
            i += 2
            if typeid it.nodes[++i] == typeid parsergen.syntax_tree
                format(os, indent, it.nodes[i])
            else
                i--
            end
            os.print(")")
            i += 1
            format(os, indent, it.nodes[++i])
        end
        case "capture-list"
            if it.nodes[0].data == "id"
                i = -1
            else
                os.print("= ")
            end
            os.print(it.nodes[++i].data)
            for j = 0, true, null
                if i >= it.size
                    break
                end
                os.print(", ")
                i++
                format(os, indent, it.nodes[++i])
            end
        end
        case "argument-list"
            if it.nodes[0].data == "..."
                os.print("... ")
                os.print(it.nodes[1].data)
            else
                if it.nodes[0].data == "="
                    os.print("=")
                else
                    i -= 1
                end
                os.print(it.nodes[++i].data)
                if i < it.nodes.size - 1
                    if it.nodes[++i].data == ":"
                        os.print(" : ")
                        format(os, indent, it.nodes[++i])
                    else
                        i -= 1
                    end
                end
                for j = 0, true, null 
                    if i >= it.nodes.size - 1
                        break
                    end
                    os.print(", ")
                    ++i
                    format(os, indent, it.nodes[++i])
                end
            end
        end
        case "lambda-body"
            if it.nodes[0].data == "{"
                os.println("{")
                for j = 0, true, null
                    if i >= it.nodes.size - 1
                        break
                    end
                    if typeid it.nodes[i] == typeid parsergen.syntax_tree
                        format(os, indent, it.nodes[i])
                        os.println("")
                    end
                end
                os.println("}")
            else
                os.print("->")
                format(os, indent, it.nodes[1])
            end
        end
        case "cond-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
                if it.nodes.size > 3
                    os.print(" : ")
                    format(os, indent, it.nodes[4])
                end 
            end
        end
        case "logic-or-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "logic-and-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "equal-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "relat-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "add-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        case "mul-expr"
            format(os, indent, it.nodes[0])
            if it.nodes.size > 1
                os.print(" " + it.nodes[1].data + " ")
                format(os, indent, it.nodes[2])
            end
        end
        default
            foreach it in it.nodes
                format(os, indent, it)
            end
        end
    end
end

if parser.ast != null
    #compress_ast(parser.ast)
    format(system.out, 0, parser.ast)
end