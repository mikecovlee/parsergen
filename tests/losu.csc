@charset: gbk

import parsergen, unicode

constant syntax = parsergen.syntax

var cvt = new unicode.codecvt.gbk

var losu_grammar = new parsergen.grammar
losu_grammar.ext = ".*\\.losu"

@begin
losu_grammar.lex = {
    "endl" : unicode.build_wregex(cvt.local2wide("^\\n+$")),
    # GBK
    "zh_id"  : unicode.build_wregex(cvt.local2wide("^[\\uB0A1-\\uF7FE\\u8140-\\uA0FE\\uAA40-\\uFEA0\\uA996][0-9\\uB0A1-\\uF7FE\\u8140-\\uA0FE\\uAA40-\\uFEA0\\uA996]*$")),
    # UTF8
    #"zh_id"  : unicode.build_wregex(cvt.local2wide("^[\\u4E00-\\u9FA5\\u9FA6-\\u9FEF\\u3007][0-9\\u4E00-\\u9FA5\\u9FA6-\\u9FEF\\u3007]*$")),
    "id"  : unicode.build_wregex(cvt.local2wide("^[A-Za-z_]\\w*$")),
    "num" : unicode.build_wregex(cvt.local2wide("^[0-9]+\\.?([0-9]+)?$")),
    "str" : unicode.build_wregex(cvt.local2wide("^(\"|\"([^\"]|\\\\\")*\"?)$")),
    "sig" : unicode.build_wregex(cvt.local2wide("^(#|\\+|/|-|\\*|<|<=|>|>=|=|!=?|==|&|;|,|\\(|\\)|\\[|\\]|\\{|\\})$")),
    "ign" : unicode.build_wregex(cvt.local2wide("^([ \\f\\r\\t\\v]+|/|//.*\\n?|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$")),
    "err" : unicode.build_wregex(cvt.local2wide("^(!)$"))
}.to_hash_map()
@end

@begin
losu_grammar.stx = {
    "begin" : {
        syntax.repeat(syntax.term("#"), syntax.ref("ctrl-stmt"), syntax.token("endl"))
    },
    # Ignore if not match initiatively
    "ignore" : {
        syntax.repeat(syntax.token("endl"))
    },
    "ctrl-stmt" : {syntax.cond_or(
        {syntax.ref("load-stmt")},
        {syntax.ref("import-stmt")},
        {syntax.ref("method-stmt")}
    )},
    "inst-stmt" : {syntax.cond_or(
        {syntax.ref("if-stmt")},
        {syntax.ref("loop-stmt")},
        {syntax.ref("expr-stmt")}
    )},
    "identifier" : {syntax.cond_or(
        {syntax.token("zh_id")},
        {syntax.token("id")}
    )},
    "load-stmt" : {
        syntax.term("加载"), syntax.ref("identifier")
    },
    "import-stmt" : {
        syntax.term("导入"), syntax.ref("identifier"), syntax.repeat(syntax.term("/"), syntax.ref("identifier"))
    },
    "method-list" : {
        syntax.ref("identifier"), syntax.optional(syntax.term(","), syntax.ref("method-list"))
    },
    "method-stmt" : {
        syntax.term("方法"), syntax.ref("identifier"), syntax.optional(syntax.term("("), syntax.optional(syntax.ref("method-list")), syntax.term(")")),
        syntax.token("endl"), syntax.repeat(syntax.ref("inst-stmt"), syntax.token("endl")), syntax.term(";")
    },
    "if-stmt" : {
        syntax.term("#"), syntax.term("如果"), syntax.ref("expr"),
        syntax.token("endl"), syntax.repeat(syntax.ref("inst-stmt"), syntax.token("endl")), syntax.term(";")
    },
    "loop-stmt" : {
        syntax.term("#"), syntax.term("循环"), syntax.ref("expr"),
        syntax.token("endl"), syntax.repeat(syntax.ref("inst-stmt"), syntax.token("endl")), syntax.term(";")
    },
    "expr-stmt" : {
        syntax.ref("expr")
    },
    "expr" : {
        syntax.ref("logic-or-expr"), syntax.optional(syntax.term("="), syntax.ref("expr"))
    },
    "logic-or-expr" : {
        syntax.ref("logic-and-expr"), syntax.optional(syntax.cond_or({syntax.term("||")}, {syntax.term("或")}), syntax.ref("logic-or-expr"))
    },
    "logic-and-expr" : {
        syntax.ref("equal-expr"), syntax.optional(syntax.cond_or({syntax.term("&&")}, {syntax.term("且")}), syntax.ref("logic-and-expr"))
    },
    "equal-expr" : {
        syntax.ref("relat-expr"), syntax.optional(syntax.cond_or({syntax.term("==")}, {syntax.term("!=")}, {syntax.term("等于")}, {syntax.term("不等于")}), syntax.ref("equal-expr"))
    },
    "relat-expr" : {
        syntax.ref("add-expr"), syntax.optional(syntax.cond_or({syntax.term(">")}, {syntax.term("<")}, {syntax.term(">=")}, {syntax.term("<=")}), syntax.ref("relat-expr"))
    },
    "add-expr" : {
        syntax.ref("mul-expr"), syntax.optional(syntax.cond_or({syntax.term("+")}, {syntax.term("-")}, {syntax.term("&")}), syntax.ref("add-expr"))
    },
    "mul-expr" : {
        syntax.ref("unary-expr"), syntax.optional(syntax.nlook(syntax.token("endl")), syntax.cond_or({syntax.term("*")}, {syntax.term("/")}, {syntax.term("%")}, {syntax.term("^")}), syntax.ref("mul-expr"))
    },
    "unary-expr" : {syntax.cond_or(
        {syntax.ref("unary-op"), syntax.ref("unary-expr")},
        {syntax.ref("prim-expr"), syntax.optional(syntax.nlook(syntax.token("endl")), syntax.ref("postfix-expr"))}
    )},
    "unary-op" : {syntax.cond_or(
        {syntax.term("++")},
        {syntax.term("--")},
        {syntax.term("-")},
        {syntax.term("!")},
        {syntax.term("非")}
    )},
    "postfix-expr" : {
        syntax.cond_or({syntax.term("++")}, {syntax.term("--")}), syntax.optional(syntax.ref("postfix-expr"))
    },
    "prim-expr" : {syntax.cond_or(
        {syntax.ref("visit-expr")},
        {syntax.ref("constant")}
    )},
    "visit-expr" : {
        syntax.ref("element"), syntax.optional(syntax.term(","), syntax.ref("visit-expr"))
    },
    "element" : {
        syntax.cond_or({syntax.ref("identifier")}, {syntax.term("("), syntax.ref("expr"), syntax.term(")")}),
        syntax.repeat(syntax.nlook(syntax.token("endl")), syntax.ref("fcall"))
    },
    "constant" : {syntax.cond_or(
        {syntax.term("<"), syntax.ref("visit-expr"), syntax.term(">")},
        {syntax.token("str")},
        {syntax.token("num")}
    )},
    "array" : {
        syntax.term("{"), syntax.optional(syntax.ref("expr")), syntax.term("}")
    },
    "fcall" : {
        syntax.term("("), syntax.optional(syntax.ref("expr")), syntax.optional(syntax.term(","), syntax.ref("expr")), syntax.term(")")
    }
}.to_hash_map()
@end

var main = new parsergen.generator
main.add_grammar("洛书", losu_grammar)

main.stop_on_error = false
main.unicode_cvt = cvt
# main.enable_log = true

var time_start = runtime.time()
main.from_file(context.cmd_args.at(1))
system.out.println("Compile Time: " + (runtime.time() - time_start)/1000 + "s")

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

if main.ast != null
    compress_ast(main.ast)
    parsergen.print_ast(main.ast)
end