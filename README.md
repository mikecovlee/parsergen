# ParserGen &mdash; LL(\*) Parser Generator in Covariant Script

ParserGen is a top-down, backtracking parser generator for the
[Covariant Script](https://github.com/covscript/covscript) language.
It generates **LL(&#8727;)** parsers with PEG-style ordered choice,
negative lookahead, and automatic whitespace skipping.

ParserGen ships in two interchangeable implementations with an identical
unified API (see [API.md](API.md)):

- **`parsergen`** &mdash; pure CovScript reference implementation
- **`parsergen_cxx`** &mdash; C++17 native implementation (`libparsergen`
  + CNI extension), see [CXX_API.md](CXX_API.md)

Set the environment variable `PARSERGEN_IMPL=parsergen_cxx` to switch a
`context.import`-based loader between the two at runtime.

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

Each lexical rule is a regular-expression **pattern string**. The special rule
`"ign"` matches whitespace and comments (skipped between tokens). Patterns are
compiled internally by `add_language` / `make_grammar_from`.

```js
var lex = {
    "id"  : "^[A-Za-z_]\\w*$",
    "num" : "^[0-9]+$",
    "sig" : "^(\\+|\\*|\\(|\\))$",
    "ign" : "^\\s+$",
    "err" : "^.$"
}.to_hash_map()
```

### 3 &nbsp; Define a Grammar

```js
import parsergen
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

Build a grammar with `make_grammar_from` and register it with `add_language`
(the unified API; works identically for `parsergen` and `parsergen_cxx`).

```js
var gram = parsergen.make_grammar_from(".*\\.mylang", lex, stx)

var gen = new parsergen.generator
gen.set_show_prompt(false)
gen.add_language("my-lang", "ascii", gram)

if gen.from_string("my-lang", "1 + (2 + 3)")
    var ast = gen.get_ast()    // parsergen.syntax_tree
    parsergen.print_ast(ast)
else
    parsergen.print_error(gen.get_file_path(), gen.get_code_buff(), gen.get_errors())
end
```

### 5 &nbsp; Parse from Files

The grammar's `ext` (set via `make_grammar_from`) selects the language by file
extension.

```js
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

## C++ Implementation (`parsergen_cxx`)

The `cpp/` directory contains a C++17 port of the core engine
(`libparsergen`) and a CovScript CNI extension (`parsergen_cxx.cse`) that
exposes the same unified API. Algorithm and produced AST are identical to the
CovScript implementation.

Build (requires the CovScript SDK; set `CS_DEV_PATH` to the SDK root):

```bash
# Unix
cmake -S cpp -B cmake-build/unix
cmake --build cmake-build/unix --parallel

# Windows (MinGW-w64)
cmake -G "MinGW Makefiles" -S cpp -B cmake-build/mingw-w64
cmake --build cmake-build/mingw-w64 --parallel
```

Or use the helpers `csbuild/make.sh` / `csbuild/make.bat`, which also copy the
built `parsergen_cxx.cse` to `build/imports/` for `cspkg build
csbuild/parsergen_cxx.json`.

Use it from CovScript exactly like `parsergen`:

```js
import parsergen_cxx as parsergen
// ... same unified API as above ...
```

See [CXX_API.md](CXX_API.md) for the native C++ interface and
[API.md](API.md) for the unified CovScript API shared by both implementations.

## Project Structure

```
parsergen.csp          Core parser / lexer / generator (CovScript)
parsergen_debug.csp    Debug build with extended logging
ebnfigen.csp           EBNF exporter (syntax → EBNF text)
ebnf_parser.csp        EBNF parser (EBNF text → syntax)
parsergen_analysis.csp Grammar analyzer (lr / unreachable / overlap)
visitorgen.csp         AST visitor code generator
cpp/                   C++17 implementation (libparsergen + CNI)
  include/parsergen/   Public headers
  src/                 Lexer / parser / generator sources
  cni/                 CovScript CNI extension (parsergen_cxx.cse)
  test/                C++ unit tests + drop-in comparison scripts
csbuild/               Build & format scripts + cspkg descriptors
unit_tests/            8 test suites, 300+ test cases
tests/                 Integration test grammars (tiny, cminus, JSON, ECS)
misc/                  Utility scripts
docs/                  Documentation
```

## License

Apache License 2.0 &mdash; Copyright (C) 2017-2026 Michael Lee
