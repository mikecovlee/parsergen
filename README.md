# ParserGen &mdash; LL(\*) Parser Generator in Covariant Script

ParserGen is a top-down, backtracking parser generator for the
[Covariant Script](https://github.com/covscript/covscript) language.
It generates **LL(&#8727;)** parsers with PEG-style ordered choice,
negative lookahead, and automatic whitespace skipping.

## Features

| Feature | Description |
|---|---|
| Token-level PEG | Ordered choice, negative lookahead, greedy repetition |
| Automatic `ignore` | Whitespace/comments skipped between tokens |
| FIRST-set prediction | Boot-set optimization reduces backtracking |
| Packrat memoization | Linear-time parsing via parse-memo cache |
| Error recovery | Skip to sync points, report multiple errors in one pass |
| EBNF support | Parse EBNF text &#8594; grammar; grammar &#8594; EBNF export |
| Grammar analysis | Left-recursion detection, unreachable rules, FIRST overlap warnings |
| Partial parsing | `partial_parser_type` supports interactive/resumable parsing |

## Quick Start

### 1 &nbsp; Install

```bash
cspkg config source --app \\
  https://raw.githubusercontent.com/mikecovlee/parsergen/main/cspkg/
cspkg install parsergen --yes
```

### 2 &nbsp; Define a Lexer

Each lexical rule is a regular expression. The special rule `"ign"` matches
whitespace and comments (skipped between tokens).

```js
import parsergen, regex

var lex = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|\\*|\\(|\\))$"),
    "ign" : regex.build("^\\s+$"),
    "err" : regex.build("^.$")
}.to_hash_map()
```

### 3 &nbsp; Define a Grammar

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

### 4 &nbsp; Parse Input

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

### 5 &nbsp; Parse from Files

```js
gen.add_grammar("my-lang", gram)
gram.ext = ".*\\.mylang"

if gen.from_file("./test.mylang")
    // success
else
    // check gen.get_errors()
end
```

## Syntax Types

| Function | EBNF | Description |
|---|---|---|
| `syntax.token("id")` | `<id>` | Match token by lexical type |
| `syntax.term("if")` | `"if"` | Match token by exact text |
| `syntax.ref("expr")` | `expr` | Reference another rule |
| `syntax.nlook(...)` | `!( ... )` | Negative lookahead &mdash; succeed if pattern does **not** match |
| `syntax.repeat(...)` | `{ ... }` | Zero or more repetitions (greedy) |
| `syntax.optional(...)` | `[ ... ]` | Zero or one occurrence |
| `syntax.cond_or(a, b, ...)` | `( a \| b \| ... )` | Ordered choice (first match wins) |

The `ignore` rule is special: if defined, it is automatically tried between every
token match. Use it for whitespace and comments.

## New Modules

### `ebnfigen` &mdash; EBNF Exporter

Convert a parsergen syntax hash_map to ISO 14977 EBNF text.

```js
import ebnfigen
var ofs = iostream.ofstream("./grammar.ebnf")
(new ebnfigen.ebnf_generator).run(ofs, grammar.stx)
```

Supports PEG-style negative lookahead syntax `!( ... )` and
`<token>` notation for lexical token references. Rule names with hyphens are
automatically converted to underscores (EBNF compatibility).

### `ebnf_parser` &mdash; EBNF Parser

Parse EBNF text (ISO 14977 + `!()` and `<name>` extensions) into
a parsergen syntax hash_map, ready for use with the parser.

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
// use with parsergen.generator as usual
```

### `parsergen_analysis` &mdash; Grammar Analysis

Analyze a grammar for common issues.

```js
import parsergen_analysis

parsergen_analysis.print_report(grammar.stx)
```

Detects:
- **Left recursion** &mdash; rules that call themselves before consuming input (infinite loop)
- **Unreachable rules** &mdash; rules defined but never referenced from `"begin"`
- **FIRST overlap** &mdash; `cond_or` alternatives that share the same starting token

### `parsergen.recovering_parser_type`

Extended parser that recovers from errors by skipping to synchronization
points (`endl` tokens or `;`), reporting multiple errors in a single pass.

```js
var lexer = new parsergen.lexer_type
var parser = new parsergen.recovering_parser_type
var tokens = lexer.run(gram.lex, source_code)
parser.init(gram.stx)
if parser.parse_with_recovery(tokens)
    // success
else
    foreach it in parser.get_all_errors()
        system.out.println("Line " + (it.pos[1] + 1) + ": " + it.text)
    end
end
```

### `parsergen_codegen` &mdash; Native Code Generator

Generate a standalone, high-performance native parser package from a grammar
definition. The generated package expands the grammar into direct
recursive-descent parse functions with pre-computed predict (boot) sets,
eliminating runtime interpretation overhead. It exposes the same API as
`parsergen.generator`, making it a drop-in replacement.

```js
import parsergen_codegen, parsergen, regex

// Define grammar as usual
var gram = new parsergen.grammar
gram.ext = ".*\\.json"
gram.stx = json_stx

// Provide lex regex pattern strings (cannot extract from regex objects)
@begin
var lex_regexes = {
    "num" : "^[0-9]+\\.?([0-9]+)?$",
    "str" : "^(\"|\"([^\"]|\\\\\")*\"?)$",
    "sig" : "^(:|,|\\[|\\]|\\{|\\})$",
    "ign" : "^\\s+$"
}.to_hash_map()
@end

var gen = new parsergen_codegen.code_generator
gen.generate("json_parser", gram, lex_regexes, "./json_parser.csp")
```

Use the generated parser (API compatible with `parsergen.generator`):

```js
import json_parser
var gen = new json_parser.generator
gen.from_string("{\"a\": 1, \"b\": [2, 3]}")
var ast = gen.ast    // syntax_tree, identical to dynamic parser output
```

Key features of generated parsers:
- Native recursive descent &mdash; grammar expanded into direct `_parse_*()` functions, no interpreter loop
- Pre-computed predict sets &mdash; no `init()`/`prep_syntax()` overhead at parse time
- Standalone package &mdash; no need to pass grammar objects at runtime
- Identical AST output &mdash; verified node-by-node against the dynamic parser
- Drop-in replacement &mdash; same `from_string`/`from_file`/`get_errors` API
- 2&ndash;3x speedup &mdash; measured on TINY, C-MINUS, and ECS grammars

## Project Structure

```
parsergen.csp          Core parser / lexer / generator
parsergen_codegen.csp  Native recursive-descent parser code generator (v2.0.0)
parsergen_debug.csp    Debug build with extended logging
ebnfigen.csp           EBNF exporter (syntax → EBNF text)
ebnf_parser.csp        EBNF parser (EBNF text → syntax)
parsergen_analysis.csp Grammar analyzer (lr / unreachable / overlap)
visitorgen.csp         AST visitor code generator
unit_tests/            10 test suites, 300+ test cases
tests/                 Integration test grammars (tiny, cminus, JSON, ECS)
misc/                  Utility scripts
```

## License

Apache License 2.0 &mdash; Copyright (C) 2017-2026 Michael Lee
