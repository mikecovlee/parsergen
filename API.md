# ParserGen Unified API Reference

CovScript `parsergen.csp` 和 C++ `parsergen_cxx.cse` 的统一对外接口。

## 实现状态

所有统一 API 均已在两边实现完毕。

- CovScript `parsergen.csp` / `parsergen_debug.csp`：统一方法 + legacy 字段并存
- C++ CNI `parsergen_cxx.cse`：type_t 注册（支持 `new` 语义）+ 统一方法
- C++ 原生库 `libparsergen`：见 CXX_API.md

## 约定：优先使用方法 API，避免 property 赋值

> **统一 API 的设计立场是「方法优先」。** 请一律使用统一的**方法**接口
> （`get_*` / `set_*` / `make_*` / `add_language` 等），**不要**依赖对对象字段的
> property 读写赋值（如 `gen.ast`、`gram.lex = ...`、`parser.log = v`）。

理由：

1. **跨实现一致性**：方法 API 在 CovScript 与 C++ 两套实现中行为完全一致；而
   property 赋值**无法穿透 C++ 对象**——在 `parsergen_cxx` 侧对 CNI 对象做
   `obj.field = v` 赋值会**静默失败**（不报错但不生效），读取也仅限只读访问。
2. **可移植性**：只用方法 API 的代码可以在 `parsergen` 与 `parsergen_cxx` 之间
   无缝切换（drop-in），不依赖任何实现细节。
3. **legacy 字段仅作兼容**：`gen.ast`、`gram.lex = ...` 等字段访问/赋值属于
   CovScript legacy，仅为向后兼容保留，均已标注**废弃**（见下文各表的
   「CovScript legacy」小节），新代码不应使用。

**只读访问**（如遍历 AST 时读 `tree.root`、`tree.nodes`、`tok.type`、`tok.data`、
`err.text`、`err.pos`）两套实现均支持，可放心使用；需要**写入**时请改用对应的
方法（如 `err.set_text(v)`、`err.set_pos(v)`）。

## 构造方式

| 类型 | 写法 |
|------|------|
| generator | `new parsergen.generator` |
| grammar | `new parsergen.grammar` |
| lexer | `new parsergen.lexer_type` |
| parser | `new parsergen.parser_type` |
| partial_parser | `new parsergen.partial_parser_type` |
| recovering_parser | `new parsergen.recovering_parser_type` |
| lex_error | `new parsergen.lex_error` |

## 顶层函数

| 函数 | 说明 |
|------|------|
| `make_grammar_from(ext, lex, stx)` | 一次性构建 grammar（lex 为字符串 patterns） |
| `make_token(pos, type, data)` | 构建 token（pos 为 [col, line]，0-based） |
| `make_lex_error(text, pos)` | 构建 lex_error（pos 为 [col, line]，0-based） |
| `print_error(file, code, errors)` | 格式化错误输出 |
| `print_ast(tree)` | S-expression 输出 AST |

## syntax 命名空间

| 函数 | 说明 |
|------|------|
| `syntax.token(data)` | 匹配 token type |
| `syntax.term(data)` | 匹配 token data |
| `syntax.ref(name)` | 引用其他规则 |
| `syntax.nlook(...args)` | 非前瞻 |
| `syntax.repeat(...args)` | 重复 |
| `syntax.optional(...args)` | 可选 |
| `syntax.cond_or(...args)` | 选择（每个 arg 是 array） |

## 常量命名空间

```
syntax_type.{token, term, ref, nlook, repeat, opt, cond, cond_p}
parse_state.{accept, reject, eof}
```

## generator

### 统一方法 API

| 方法 | 说明 |
|------|------|
| `add_language(lang, coding, gram)` | 注册语法 + 编码（"ascii"/"utf8"/"gbk"） |
| `from_file(path)` | 解析文件 |
| `from_string(lang, str)` | 解析字符串 |
| `from_stream(lang, stream)` | 解析流（cs::istream） |
| `get_ast()` | 获取 AST |
| `get_code_buff()` | 获取源码行数组 |
| `get_file_path()` | 获取文件路径 |
| `get_tokens()` | 获取 token 列表 |
| `get_lex_errors()` | 获取词法错误 |
| `get_errors()` | 获取所有错误（词法+语法，按行排序） |
| `set_show_prompt(v)` | 设置错误提示开关 |
| `set_stop_on_error(v)` | 设置遇错即停 |
| `set_enable_log(v)` | 设置解析日志 |
| `lex_string(lang, text, start_line)` | 独立词法（REPL 用） |

### CovScript legacy

| 字段/方法 | 等价统一方法 | 状态 |
|------|---|---|
| `add_grammar(lang, gram)` | 无（gram.lex 需预编译 regex） | 废弃（推荐用 `add_language`） |
| `gen.ast` | `get_ast()` | 废弃（仅 CovScript 字段访问） |
| `gen.code_buff` | `get_code_buff()` | 废弃（仅 CovScript 字段访问） |
| `gen.file_path` | `get_file_path()` | 废弃（仅 CovScript 字段访问） |
| `gen.token_buff` | `get_tokens()` | 废弃（仅 CovScript 字段访问） |
| `gen.show_prompt = v` | `set_show_prompt(v)` | 废弃（仅 CovScript 赋值） |
| `gen.stop_on_error = v` | `set_stop_on_error(v)` | 废弃（仅 CovScript 赋值） |
| `gen.enable_log = v` | `set_enable_log(v)` | 废弃（仅 CovScript 赋值） |
| `gen.unicode_cvt = cvt` | `add_language(lang, coding, gram)` | 废弃 |
| `gen.lexer.error_log` | `get_lex_errors()` | 废弃（C++ 不暴露内部 worker） |
| `gen.lexer` / `gen.parser` | 无（内部状态） | 废弃（C++ 不暴露内部 worker） |

## partial_parser

### 统一方法 API

| 方法 | 说明 |
|------|------|
| `run(stx, tokens)` | 增量解析 |
| `production()` | 获取 AST |
| `get_log(n)` | 获取错误 |
| `set_eof_hook(fn)` | 设置 EOF 回调（fn 接收 parser 自身）；多次 `run()` 之间持续生效 |
| `clear_eof_hook()` | 清除 EOF 回调（CovScript 版等价写法 `set_eof_hook(null)`） |
| `push_tokens(arr)` | 追加 token 数组（EOF 重试时注入） |
| `append_token(tok)` | 追加单个 token（EOF 重试时注入） |

EOF 重试仅在回调注入了新 token 时才会真正重试；若回调未注入任何 token（或未设置回调），匹配以 `Incomplete sentence` 错误终止，不会无限重试。

### CovScript legacy

| 字段 | 等价统一方法 | 状态 |
|------|---|---|
| `parser.on_eof_hook = fn` | `set_eof_hook(fn)` | 废弃（仅 CovScript 赋值） |
| `parser.lex.push_back(tok)` | `append_token(tok)` | 废弃（C++ 不暴露内部 buffer） |
| `parser.log = v` | 用 `generator.set_enable_log(v)` | 废弃（仅 CovScript 赋值） |

## recovering_parser

| 方法 | 说明 |
|------|------|
| `init(stx)` | 初始化语法规则 |
| `parse_with_recovery(tokens)` | 带恢复解析（error 后跳到 `endl`/`;` 同步点继续）。`true` = 输入被完全消耗（干净解析或恢复后完整解析，此时 AST 为**最后成功段**）；`false` = 未能恢复出到 EOF 的完整解析 |
| `get_all_errors()` | 获取所有错误（含各失败段） |

## parser_type

### 统一方法 API

| 方法 | 说明 |
|------|------|
| `init(stx)` | 初始化语法规则 |
| `run(stx, tokens)` | 解析 |
| `production()` | 获取 AST |
| `get_log(n)` | 获取错误 |

### CovScript legacy

| 字段 | 状态 |
|------|---|
| `parser.log = v` | 废弃（仅 CovScript 赋值；C++ 侧 `parser.log` 只读，日志请用 `generator.set_enable_log(v)`） |

## lexer_type

### 统一方法 API

| 方法 | 说明 |
|------|------|
| `run(lexical, text)` | 执行词法 |
| `get_error_log()` | 获取词法错误 |

### CovScript legacy

| 字段 | 等价统一方法 | 状态 |
|------|---|---|
| `lexer.error_log` | `get_error_log()` | 废弃（仅 CovScript 字段访问） |
| `lexer.pos[1] = n` | 用 `gen.lex_string(lang, text, start_line)` | 废弃（C++ 不暴露内部状态） |
| `lexer.output` | 用 `run()` 返回值 | 废弃（仅 CovScript 字段访问） |
| `unicode_lexer_type` | 由 `add_language` coding 内部处理 | 废弃 |

## lex_error

### 统一方法 API

| 方法 | 说明 |
|------|------|
| `set_text(v)` | 设置错误文本 |
| `set_pos(v)` | 设置位置 [col, line]（0-based） |

读取（两边语法一致）：`err.text`、`err.pos`

### CovScript legacy

| 字段 | 等价统一方法 | 状态 |
|------|---|---|
| `err.text = v` | `set_text(v)` | 废弃（仅 CovScript 赋值） |
| `err.pos = v` | `set_pos(v)` | 废弃（仅 CovScript 赋值） |

## grammar 对象

### 统一

| 方法/访问 | 说明 |
|------|------|
| `parsergen.make_grammar_from(ext, lex, stx)` | 工厂构建（推荐） |
| `gram.ext` / `gram.lex` / `gram.stx` | 字段读取（两边语法一致；赋值仅 CovScript，C++ 只读） |

### CovScript legacy

| 写法 | 状态 |
|------|---|
| `new parsergen.grammar` + 字段赋值 | 废弃（推荐用 `make_grammar_from`） |

## AST 节点访问（只读，两边语法一致）

以下为**只读**访问，两套实现均支持。写入请使用对应方法（见 `lex_error` 的
`set_text` / `set_pos`）。

| 访问 | 说明 |
|------|------|
| `tree.root` | 子树根名称 |
| `tree.nodes` | 子节点数组 |
| `tok.type` | token 类型名 |
| `tok.data` | token 文本 |
| `tok.pos` | 位置 [col, line]（0-based） |
| `perr.cursor` | 错误光标位置 |
| `perr.text` | 错误文本 |
| `perr.pos` | 错误位置 [col, line]（0-based） |

## typeid（两边一致）

```
typeid parsergen.syntax_tree
typeid parsergen.token_type
typeid parsergen.lex_error
```

## 不可消除的差异

| 差异 | 原因 |
|------|------|
| `err.text = v` 赋值语法仅 CovScript | CovScript 赋值无法穿透 C++ 对象（用 `set_text(v)`） |
| `gen.lexer` / `gen.parser` 仅 CovScript | C++ 封装不暴露内部 worker |
| `unicode_lexer_type` 仅 CovScript | C++ 由 coding 内部处理 |
| `print_header(txt)` 仅 CovScript | 纯便利函数 |
| `parser.log = v` 赋值仅 CovScript | C++ 侧只读，日志用 `generator.set_enable_log(v)` |
| `gram.ext/lex/stx = v` 赋值仅 CovScript | C++ 侧只读，用 `make_grammar_from` 构建 |

## 统一写法完整示例

```python
import parsergen

# 构建 grammar
var grammar = parsergen.make_grammar_from(".*\\.ecs", get_lexical_patterns(false), get_syntax(false))

# 主解析路径
var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_language("ecs-lang", "utf8", grammar)
gen.from_file("test.ecs")

if gen.get_ast() == null
    var errors = gen.get_lex_errors()
    if errors.empty()
        var recovery = new parsergen.recovering_parser_type
        recovery.init(get_syntax(false))
        recovery.parse_with_recovery(gen.get_tokens())
        foreach it in recovery.get_all_errors() do errors.push_back(it)
    end
    errors.sort([](lhs, rhs)->lhs.pos[1] < rhs.pos[1])
    parsergen.print_error("test.ecs", gen.get_code_buff(), errors)
end

# REPL 路径
var parser = new parsergen.partial_parser_type
parser.set_eof_hook(on_eof)

function on_eof(p)
    var tokens = gen.lex_string("ecs-lang", readline(), line_no)
    p.push_tokens(tokens)
end

var tokens = gen.lex_string("ecs-lang", input, 0)
if parser.run(get_syntax(false), tokens)
    var ast = parser.production()
end

# 错误报告
var err = parsergen.make_lex_error("undefined variable", {1, 5})
parsergen.print_error(file_name, gen.get_code_buff(), {err})

# AST 遍历
function walk(tree)
    foreach node in tree.nodes
        if typeid node == typeid parsergen.syntax_tree
            system.out.println(node.root)
            walk(node)
        end
        if typeid node == typeid parsergen.token_type
            system.out.println(node.type + ": " + node.data)
        end
    end
end
```
