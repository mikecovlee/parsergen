# ParserGen &mdash; Covariant Script 语言 LL(\*) 解析器生成器

ParserGen 是一个为 [Covariant Script](https://github.com/covscript/covscript)
编写的自顶向下、支持回溯的解析器生成器。它生成 **LL(&#8727;)** 解析器，支持 PEG
风格的有序选择、负向前瞻和自动空白跳过。

## 特性

| 特性 | 说明 |
|---|---|
| Token 级 PEG | 有序选择、负向前瞻、贪婪重复 |
| 自动 `ignore` | Token 之间自动跳过空白/注释 |
| FIRST 集预测 | Boot-set 优化减少回溯 |
| Packrat 记忆化 | 记忆化缓存保证线性时间解析 |
| 错误恢复 | 跳过同步点，一次报告多个错误 |
| EBNF 支持 | EBNF 文本 &#8594; 语法定义；语法定义 &#8594; EBNF 导出 |
| 语法分析 | 左递归检测、不可达规则、FIRST 重叠警告 |
| 增量解析 | `partial_parser_type` 支持交互式/可恢复解析 |

## 快速开始

### 1 &nbsp; 安装

```bash
cspkg config source --app \\
  https://raw.githubusercontent.com/mikecovlee/parsergen/main/cspkg/
cspkg install parsergen --yes
```

### 2 &nbsp; 定义词法规则

每个词法规则是一个正则表达式。`"ign"` 是特殊规则，匹配的 token 会被静默丢弃（用于空白/注释）。

```js
import parsergen, regex

var lex = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),   // 标识符
    "num" : regex.build("^[0-9]+$"),            // 数字
    "sig" : regex.build("^(\\+|\\*|\\(|\\))$"), // 单字符 Token
    "ign" : regex.build("^\\s+$"),              // 空白（跳过）
    "err" : regex.build("^.$")                  // 未知字符捕获
}.to_hash_map()
```

### 3 &nbsp; 定义语法规则

```js
constant syntax = parsergen.syntax

@begin
var stx = {
    "begin" : {syntax.ref("expr")},
    "expr" : {syntax.ref("term"),
              syntax.repeat(
                  syntax.cond_or({syntax.term("+")}, {syntax.term("-")}),
                  syntax.ref("term"))},
    "term" : {syntax.repeat(syntax.cond_or(
        {syntax.token("num")},
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")}))},
    "ignore" : {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end
```

### 4 &nbsp; 解析输入

```js
var gram = new parsergen.grammar
gram.lex = lex
gram.stx = stx

var gen = new parsergen.generator
gen.add_grammar("my-lang", gram)

if gen.from_string("my-lang", "1 + (2 * 3)")
    var ast = gen.ast    // parsergen.syntax_tree
    parsergen.print_ast(ast)
else
    parsergen.print_error(gen.file_path, gen.code_buff, gen.get_errors())
end
```

### 5 &nbsp; 从文件解析

```js
gen.add_grammar("my-lang", gram)
gram.ext = ".*\\.mylang"

if gen.from_file("./test.mylang")
    // 成功
else
    // 检查 gen.get_errors()
end
```

## 语法类型

| 函数 | EBNF | 说明 |
|---|---|---|
| `syntax.token("id")` | `<id>` | 按词法类型匹配 Token |
| `syntax.term("if")` | `"if"` | 按精确文本匹配 Token |
| `syntax.ref("expr")` | `expr` | 引用另一个规则 |
| `syntax.nlook(...)` | `!( ... )` | 负向前瞻 &mdash; 模式**不**匹配时成功 |
| `syntax.repeat(...)` | `{ ... }` | 零次或多次重复（贪婪） |
| `syntax.optional(...)` | `[ ... ]` | 零次或一次出现 |
| `syntax.cond_or(a, b, ...)` | `( a \| b \| ... )` | 有序选择（先匹配先赢） |

`ignore` 规则是特殊的：如果定义了它，解析器会在每次 Token 匹配之间自动尝试
匹配它。用它来处理空白和注释。

## 模块

### `ebnfigen` &mdash; EBNF 导出器

将 parsergen 语法 hash_map 转换为 ISO 14977 EBNF 文本。

```js
import ebnfigen
var ofs = iostream.ofstream("./grammar.ebnf")
(new ebnfigen.ebnf_generator).run(ofs, grammar.stx)
```

支持 PEG 风格的负向前瞻 `!( ... )` 和 `<token>` 词法引用。连字符规则名自动
转换为下划线（EBNF 兼容性）。

### `ebnf_parser` &mdash; EBNF 解析器

将 EBNF 文本（ISO 14977 + `!()` 和 `<name>` 扩展）解析为 parsergen 语法
hash_map，可直接用于解析。

```js
import ebnf_parser, parsergen, regex

var p = new ebnf_parser.parser
p.parse(
    "begin = expr ;\n" +
    "expr = term { (\"+\" | \"-\") term } ;\n" +
    "term = <num> | \"(\" expr \")\" ;\n"
)
var stx = p.get_syntax()

var gram = new parsergen.grammar
gram.lex = my_lex
gram.stx = stx
// 和平时一样使用 parsergen.generator
```

### `parsergen_analysis` &mdash; 语法分析

分析语法中的常见问题。

```js
import parsergen_analysis

parsergen_analysis.print_report(grammar.stx)
```

检测：
- **左递归** &mdash; 消费输入前调用自身的规则（会导致死循环）
- **不可达规则** &mdash; 定义了但从未从 `"begin"` 引用的规则
- **FIRST 重叠** &mdash; `cond_or` 的不同分支共享相同的起始 Token

### `parsergen.recovering_parser_type`

扩展解析器，通过跳转到同步点（`endl` 或 `;`）从错误中恢复，单次解析报告多个错误。

```js
var lexer = new parsergen.lexer_type
var parser = new parsergen.recovering_parser_type
var tokens = lexer.run(gram.lex, source_code)
parser.init(gram.stx)
if parser.parse_with_recovery(tokens)
    // 成功
else
    foreach it in parser.get_all_errors()
        system.out.println("第 " + (it.pos[1] + 1) + " 行: " + it.text)
    end
end
```

## 项目结构

```
parsergen.csp           核心解析器 / 词法分析器 / 生成器
parsergen_debug.csp     调试版本（扩展日志）
ebnfigen.csp            EBNF 导出器（syntax → EBNF 文本）
ebnf_parser.csp         EBNF 解析器（EBNF 文本 → syntax）
parsergen_analysis.csp  语法分析器（左递归 / 不可达 / 重叠）
visitorgen.csp          AST 访问器代码生成器
unit_tests/             8 组测试，300+ 用例
tests/                  集成测试语法（tiny, cminus, JSON, ECS）
misc/                   实用工具脚本
docs/                   文档
```

## 许可证

Apache License 2.0 &mdash; Copyright (C) 2017-2026 Michael Lee
