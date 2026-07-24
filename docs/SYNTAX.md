# ParserGen Syntax Reference

## Lexical Rules

Lexical rules are defined as a `hash_map` of rule names to regular expressions
(created with `regex.build()`). The lexer greedily matches the longest prefix.

```js
var lex = {
    "id"   : regex.build("^[A-Za-z_]\\w*$"),   // identifiers
    "num"  : regex.build("^[0-9]+$"),            // numbers
    "str"  : regex.build(`^("|"([^"]|\\")*"?)$`), // strings
    "sig"  : regex.build("^(=|;|\\(|\\))$"),     // single-character tokens
    "ign"  : regex.build("^\\s+$"),              // whitespace (skipped)
    "err"  : regex.build("^.$")                  // catch-all for unknown chars
}.to_hash_map()
```

| Rule | Purpose |
|---|---|
| Regular rule | Define a token type. When matched, produces a token with `.type = rule_name` and `.data = matched_text`. |
| `"ign"` | Special rule: matched tokens are silently discarded. |
| `"err"` | Convention: when "err" competes with other rules, an error is reported. |

Regex patterns must start with `^` and end with `$` (full match).
Characters in regexes that conflict with Covariant Script string/block syntax
(like `{`, `}`, `(`, `)`) require the assignment to be wrapped in `@begin/@end`:

```js
@begin
var lex = {
    "sig" : regex.build("^(\\{|\\}|\\[|\\]|\\(|\\))$"),
    "ign" : regex.build("^(\\s+|\\{[^\\}]*\\}?)$")
}.to_hash_map()
@end
```

## Syntax Rules

Syntax rules are defined as a `hash_map` where each key is a rule name and each
value is an **array** of syntax elements. Two rule names are special:

- `"begin"` &mdash; the entry point of the grammar
- `"ignore"` &mdash; whitespace/comments, automatically tried between tokens

### `syntax.token(name)`

Match a token whose **type** equals `name`. Token types are defined by the
lexer's hash_map keys (excluding `ign`/`err`).

```js
syntax.token("id")     // match any token with type == "id"
syntax.token("num")    // match any token with type == "num"
```

EBNF equivalent: `<id>`, `<num>`

### `syntax.term(text)`

Match a token whose **data** (exact text) equals `text`.

```js
syntax.term("if")      // match the keyword "if"
syntax.term("+")       // match the operator "+"
syntax.term(";")       // match the semicolon
syntax.term("||")      // match the two-character operator "||"
```

EBNF equivalent: `"if"`, `"+"`, `";"`, `"||"`

### `syntax.ref(name)`

Reference another grammar rule (non-terminal).

```js
syntax.ref("expr")     // match the "expr" rule
syntax.ref("stmts")    // match the "stmts" rule
```

The parser predicts whether `name` can match the current input (using
FIRST-set / boot-set analysis) before attempting to parse it. If prediction
fails, the reference is skipped without consuming input.

EBNF equivalent: `expr`, `stmts`

### `syntax.nlook(...args)`

**Negative lookahead**. Succeeds if the contained pattern does **not** match
at the current position. Does not consume any input.

```js
// Repeat "id" tokens until "end" is encountered
syntax.repeat(syntax.nlook(syntax.term("end")), syntax.token("id"))

// The unary expression "not" must NOT be followed by an expression
// (otherwise it's the logical "not" operator, not the unary operator)
syntax.optional(syntax.nlook(syntax.token("endl")), syntax.ref("postfix_expr"))
```

EBNF equivalent: `!( ... )`

### `syntax.repeat(...args)`

**Zero or more** repetitions of the contained pattern (greedy).

```js
// Zero or more identifiers
syntax.repeat(syntax.token("id"))

// Zero or more comma-separated expressions
syntax.repeat(syntax.term(","), syntax.ref("expr"))
```

EBNF equivalent: `{ ... }`

### `syntax.optional(...args)`

**Zero or one** occurrence of the contained pattern.

```js
// Optional else clause
syntax.optional(syntax.term("else"), syntax.ref("stmts"))

// Optional initializer
syntax.optional(syntax.term("="), syntax.ref("expr"))
```

EBNF equivalent: `[ ... ]`

### `syntax.cond_or(...args)`

**Ordered choice**. Each argument is a **sequence** (array `{...}`) of syntax
elements. The parser tries each alternative in order; the first one to match
wins.

```js
syntax.cond_or(
    {syntax.ref("if_stmt")},
    {syntax.ref("while_stmt")},
    {syntax.ref("assign_stmt")}
)

// Inline literal alternatives
syntax.cond_or({syntax.term("+")}, {syntax.term("-")})

// Mixed alternatives
syntax.cond_or(
    {syntax.token("num")},
    {syntax.token("str")},
    {syntax.term("("), syntax.ref("expr"), syntax.term(")")}
)
```

EBNF equivalent: `( alt1 | alt2 | alt3 )`

## Parser Behavior

### Prediction (Boot Sets)

Before attempting to match a rule reference, the parser computes a
**boot set** (FIRST set): the set of token types and literal values that can
start the rule. If the current token is not in the boot set, the rule is
skipped without consuming input.

This makes `cond_or` efficient: only alternatives whose boot set contains the
current token are attempted.

### Backtracking

When a `cond_or` alternative fails, the parser **backtracks** (restores the
cursor position) and tries the next alternative. The ordered choice is
**committed** &mdash; the first successful alternative wins, even if later
alternatives could produce a longer match.

### Memoization

The parser caches the result of matching a rule at a given position. If the
same rule is attempted at the same position again (e.g., from a different
`cond_or` branch), the cached result is returned immediately. This guarantees
**O(n)** worst-case parse time.

### Error Recovery

The `recovering_parser_type` continues parsing after errors by skipping tokens
until a synchronization point (an `endl` token or a `;`). It reports all
errors found in a single pass, rather than stopping at the first error.

## Complete Example

```js
import parsergen, regex
constant syntax = parsergen.syntax

// --- Lexer ---
var lex = {
    "id"  : regex.build("^[a-z]+$"),
    "num" : regex.build("^[0-9]+$"),
    "op"  : regex.build("^(=|;|\\+|\\*|\\(|\\))$"),
    "ign" : regex.build("^\\s+$")
}.to_hash_map()

// --- Grammar ---
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

// --- Parse ---
var gram = new parsergen.grammar
gram.lex = lex
gram.stx = stx

var gen = new parsergen.generator
gen.add_grammar("calc", gram)
gen.from_string("calc", "x = 1 + (2 * y);")
```

## See Also

- [EBNF Parser & Exporter](README.md#ebnfigen----ebnf-exporter)
- [Grammar Analyzer](README.md#parsergen_analysis----grammar-analysis)
- [Error Recovery](README.md#parsergenrecovering_parser_type)
