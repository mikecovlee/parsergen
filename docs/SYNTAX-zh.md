# ParserGen 语法参考

## 词法规则

词法规则定义为 `hash_map`，键为规则名，值为正则表达式（通过 `regex.build()` 创建）。
词法分析器贪婪匹配最长前缀。

```js
var lex = {
    "id"   : regex.build("^[A-Za-z_]\\w*$"),   // 标识符
    "num"  : regex.build("^[0-9]+$"),            // 数字
    "str"  : regex.build(`^("|"([^"]|\\")*"?)$`), // 字符串
    "sig"  : regex.build("^(=|;|\\(|\\))$"),     // 单字符 Token
    "ign"  : regex.build("^\\s+$"),              // 空白（跳过）
    "err"  : regex.build("^.$")                  // 未知字符兜底
}.to_hash_map()
```

| 规则 | 用途 |
|---|---|
| 普通规则 | 定义一个 Token 类型。匹配后产生 token，`.type = 规则名`，`.data = 匹配文本`。 |
| `"ign"` | 特殊规则：匹配的 Token 被静默丢弃。 |
| `"err"` | 约定：当 "err" 与其他规则竞争时，报告错误。 |

正则表达式必须以 `^` 开头、`$` 结尾（全匹配）。正则中包含 `{`、`}`、`(`、`)` 等
与 Covariant Script 的 `@begin` 块语法冲突的字符时，需要用 `@begin/@end` 包裹赋值：

```js
@begin
var lex = {
    "sig" : regex.build("^(\\{|\\}|\\[|\\]|\\(|\\))$"),
    "ign" : regex.build("^(\\s+|\\{[^\\}]*\\}?)$")
}.to_hash_map()
@end
```

## 语法规则

语法定义为 `hash_map`，每个键是规则名，值是一个由**语法元素**组成的**数组**。
有两个特殊的规则名：

- `"begin"` &mdash; 语法入口点
- `"ignore"` &mdash; 空白/注释，Token 之间自动尝试匹配

### `syntax.token(name)`

按 **token 类型** 匹配。Token 类型由词法规则的 hash_map 键定义（`ign`/`err` 除外）。

```js
syntax.token("id")     // 匹配任何 type == "id" 的 Token
syntax.token("num")    // 匹配任何 type == "num" 的 Token
```

EBNF 等价：`<id>`、`<num>`

### `syntax.term(text)`

按 **精确文本** 匹配。比较 token 的 `.data` 字段。

```js
syntax.term("if")      // 匹配关键字 "if"
syntax.term("+")       // 匹配运算符 "+"
syntax.term(";")       // 匹配分号
syntax.term("||")      // 匹配双字符运算符 "||"
```

EBNF 等价：`"if"`、`"+"`、`";"`、`"||"`

### `syntax.ref(name)`

引用另一个语法规则（非终结符）。

```js
syntax.ref("expr")     // 匹配 "expr" 规则
syntax.ref("stmts")    // 匹配 "stmts" 规则
```

解析器在尝试解析之前，会先预测 `name` 是否能匹配当前输入（使用 FIRST 集 /
boot-set 分析）。如果预测失败，则跳过该引用，不消费输入。

EBNF 等价：`expr`、`stmts`

### `syntax.nlook(...args)`

**负向前瞻**。包含的模式**不** 匹配时成功，不消费任何输入。

```js
// 重复匹配 "id" 直到遇到 "end"
syntax.repeat(syntax.nlook(syntax.term("end")), syntax.token("id"))

// 一元运算符后不跟表达式时才是独立的一元运算符
syntax.optional(syntax.nlook(syntax.token("endl")), syntax.ref("postfix_expr"))
```

EBNF 等价：`!( ... )`

### `syntax.repeat(...args)`

**零次或多次** 重复包含的模式（贪婪匹配）。

```js
// 零个或多个标识符
syntax.repeat(syntax.token("id"))

// 零个或多个逗号分隔的表达式
syntax.repeat(syntax.term(","), syntax.ref("expr"))
```

EBNF 等价：`{ ... }`

### `syntax.optional(...args)`

**零次或一次** 出现包含的模式。

```js
// 可选的 else 子句
syntax.optional(syntax.term("else"), syntax.ref("stmts"))

// 可选的初始化表达式
syntax.optional(syntax.term("="), syntax.ref("expr"))
```

EBNF 等价：`[ ... ]`

### `syntax.cond_or(...args)`

**有序选择**。每个参数是一个**序列**（数组 `{...}`），由语法元素组成。解析器按顺序
尝试每个分支，第一个成功匹配的胜出。

```js
syntax.cond_or(
    {syntax.ref("if_stmt")},
    {syntax.ref("while_stmt")},
    {syntax.ref("assign_stmt")}
)

// 行内字面量选择
syntax.cond_or({syntax.term("+")}, {syntax.term("-")})

// 混合选择
syntax.cond_or(
    {syntax.token("num")},
    {syntax.token("str")},
    {syntax.term("("), syntax.ref("expr"), syntax.term(")")}
)
```

EBNF 等价：`( 分支1 | 分支2 | 分支3 )`

## 解析器行为

### 预测（Boot Set）

在尝试匹配规则引用之前，解析器会计算 **boot set**（FIRST 集）：能够启动该规则的
token 类型和字面值集合。如果当前 token 不在 boot set 中，则跳过该规则，不消费输入。

这使得 `cond_or` 高效：只尝试 boot set 包含当前 token 的分支。

### 回溯

当 `cond_or` 的某个分支失败时，解析器**回溯**（恢复游标位置）并尝试下一个分支。
有序选择是**提交式**的——第一个成功的分支胜出，即使后续分支可能产生更长的匹配。

### 记忆化

解析器缓存规则在某个位置的匹配结果。如果同一规则在同一位置再次被尝试（例如来自
不同的 `cond_or` 分支），直接返回缓存结果。这保证了 **O(n)** 最坏情况解析时间。

### 错误恢复

`recovering_parser_type` 遇到错误后跳过 Token 直到同步点（`endl` 或 `;`），
继续解析。一次报告所有错误，而不是在第一个错误处停止。

## 完整示例

```js
import parsergen, regex
constant syntax = parsergen.syntax

// --- 词法 ---
var lex = {
    "id"  : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+$"),
    "op"  : regex.build("^(=|;|\\+|\\*|\\(|\\))$"),
    "ign" : regex.build("^\\s+$")
}.to_hash_map()

// --- 语法 ---
@begin
var stx = {
    "begin" : {syntax.repeat(syntax.ref("stmt"))},
    "stmt"  : {syntax.token("id"), syntax.term("="), syntax.ref("expr"),
               syntax.term(";")},
    "expr"  : {syntax.ref("term"),
               syntax.repeat(syntax.term("+"), syntax.ref("term"))},
    "term"  : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.token("id")},
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")}
    )},
    "ignore": {syntax.repeat(syntax.token("endl"))}
}.to_hash_map()
@end

// --- 解析 ---
var gram = new parsergen.grammar
gram.lex = lex
gram.stx = stx

var gen = new parsergen.generator
gen.add_grammar("calc", gram)
gen.from_string("calc", "x = 1 + (2 * y);")
```

## 参见

- [静态代码生成器](README-zh.md#parsergen_codegen----静态代码生成器)
- [EBNF 解析器与导出器](README-zh.md#ebnfigen----ebnf-导出器)
- [语法分析器](README-zh.md#parsergen_analysis----语法分析)
- [错误恢复](README-zh.md#parsergenrecovering_parser_type)
