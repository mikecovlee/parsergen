# ParserGen C++ Native API Reference

C++ 库 `libparsergen` 的原生接口。命名空间 `pg`。

## 类型定义

```cpp
// token.hpp
struct token_type {
    std::array<std::size_t, 2> pos = {0, 0};  // [col, line]
    std::string type;
    std::string data;
};

struct lex_error {
    std::string text;
    std::array<std::size_t, 2> pos = {0, 0};
};

token_type make_token(std::array<std::size_t, 2> pos, const std::string &type, const std::string &data);

// ast.hpp
using ast_node = std::variant<token_type, std::shared_ptr<syntax_tree>>;

struct syntax_tree {
    std::string root;
    std::vector<ast_node> nodes;
};

void print_ast(const std::shared_ptr<syntax_tree> &tree);

// syntax.hpp
enum class syntax_type { token=1, term=2, ref=3, nlook=4, repeat=5, opt=6, cond=7, cond_p=8 };

struct syntax_impl {
    std::shared_ptr<bootset_type> boot = nullptr;
    syntax_type type = syntax_type::token;
    std::any data;
};

using syntax_t = std::shared_ptr<syntax_impl>;
using syntax_seq = std::vector<syntax_t>;

// lexer.hpp
using lexical_t = std::map<std::string, std::string>;
using token_list_t = std::vector<token_type>;

using regex_handle_t = std::shared_ptr<void>;
std::string regex_pattern(const regex_handle_t &reg);
bool regex_match(const std::string &pattern, const std::string &text);
// 全串（锚定）匹配：整段 text 必须匹配 pattern（与 CovScript 参考 from_file 的 ext 选择一致）
bool regex_match_full(const std::string &pattern, const std::string &text);

struct grammar {
    std::string ext = ".*";
    lexical_t lex;
    std::unordered_map<std::string, syntax_seq> stx;
};

// parser.hpp
enum class parse_state {
    eof    = 0,
    reject = 1,
    accept = 2
};

using syntax_map_t = std::unordered_map<std::string, syntax_seq>;
using predict_cache_t = std::unordered_map<std::string, std::shared_ptr<bootset_type>>;

struct parse_error {
    int cursor = 0;
    std::string text;
    std::array<std::size_t, 2> pos = {0, 0};
};

struct parse_stage {
    syntax_tree product;
    int cursor = 0;
};

struct parse_memo {
    parse_state result = parse_state::reject;
    int cursor = 0;
    std::shared_ptr<syntax_tree> product = nullptr;
};
```

## syntax 工厂函数

```cpp
namespace pg::syntax {
    syntax_t token(const std::string &data);
    syntax_t term(const std::string &data);
    syntax_t ref(const std::string &name);
    syntax_t nlook(syntax_seq args);
    syntax_t repeat(syntax_seq args);
    syntax_t optional(syntax_seq args);
    syntax_t cond_or(std::initializer_list<syntax_seq> args);
    syntax_t cond_or(std::vector<syntax_seq> args);
}
```

## lexer_type

```cpp
class pg::lexer_type final {
public:
    std::array<std::size_t, 3> pos = {0, 0, 0};   // [col, line, cursor]
    std::vector<lex_error> error_log;
    token_list_t output;

    void error(const std::string &str, std::array<std::size_t, 2> p);
    token_list_t run(const lexical_t &lexical, const std::string &text);

private:
    // 内部状态
    std::unordered_set<std::string> m_lexical_set;
    std::string m_buff;
    std::string m_data;
    std::array<std::size_t, 2> m_wpos = {0, 0};
    std::unordered_map<std::string, std::shared_ptr<compiled_regex>> m_regex_cache;

    std::shared_ptr<compiled_regex> get_regex(const std::string &pattern);
    void process_token();
};
```

## unicode_lexer_type

```cpp
class pg::unicode_lexer_type final {
public:
    std::array<std::size_t, 3> pos = {0, 0, 0};
    std::vector<lex_error> error_log;
    token_list_t output;

    explicit unicode_lexer_type(std::shared_ptr<codecvt::charset> c);

    void error(const std::string &str, std::array<std::size_t, 2> p);
    token_list_t run(const lexical_t &lexical, const std::string &text);

private:
    std::shared_ptr<codecvt::charset> m_cvt;
    std::unordered_set<std::string> m_lexical_set;
    std::u32string m_buff;
    std::u32string m_data;
    std::array<std::size_t, 2> m_wpos = {0, 0};
    std::unordered_map<std::string, std::shared_ptr<compiled_wregex>> m_regex_cache;

    std::shared_ptr<compiled_wregex> get_wregex(const std::string &pattern);
    void cursor_forward();
    void process_token();
};
```

## codecvt（unicode.hpp）

```cpp
namespace pg::codecvt {
    class charset {
    public:
        virtual ~charset() = default;
        virtual std::u32string local2wide(std::string_view) = 0;
        virtual std::string wide2local(const std::u32string &) = 0;
        virtual bool is_identifier(char32_t) = 0;
    };

    class ascii final : public charset { ... };
    class utf8 final : public charset { ... };
    class gbk final : public charset { ... };
}
```

## parser_type

```cpp
class pg::parser_type {
public:
    bool log = false;

    parser_type() = default;
    virtual ~parser_type() = default;

    void init(const syntax_map_t &grammar);
    bool parse(const token_list_t &lex_output);
    bool run(const syntax_map_t &grammar, const token_list_t &lex_output);

    std::shared_ptr<syntax_tree> production() const;
    std::vector<parse_error> get_log(int n);

protected:
    std::deque<parse_stage> m_stack;
    syntax_map_t m_syn_storage;
    const syntax_map_t *m_syn = nullptr;
    const token_list_t *m_lex = nullptr;

    std::vector<parse_error> m_error_log;
    int m_max_cursor = 0;
    int m_max_prediction_pass = 20;
    predict_cache_t m_predict_cache;
    std::shared_ptr<bootset_type> m_ign_bootset;
    bool m_on_ign = false;

    std::unordered_map<std::string, parse_memo> m_memo_cache;
    std::unordered_map<std::string, std::optional<int>> m_ign_cache;

    void push_stage(const std::string &root);
    parse_stage pop_stage();
    void push(ast_node val);
    void push_token();

    int cursor() const;
    bool eof() const;
    const token_type &peek() const;

    void error(const std::string &str, std::array<std::size_t, 2> pos);
    void do_accept();
    void do_merge();

    virtual parse_state match_syntax(const syntax_seq &seq);
    std::optional<int> try_ignore();
    void ignore();
    parse_state predict(const std::shared_ptr<bootset_type> &set);
    parse_state match(const syntax_t &it);

    std::shared_ptr<bootset_type> prep_syntax(const syntax_seq &seq);
    bool expand_pending_ref(std::shared_ptr<bootset_type> &boot);
    void solve_pending_ref();
};
```

## partial_parser_type

```cpp
class pg::partial_parser_type final : public parser_type {
public:
    std::function<void(partial_parser_type &)> on_eof_hook;

    parse_state match_syntax(const syntax_seq &seq) override;
};
```

解析在 EOF 处失败时调用 `on_eof_hook`（传入 parser 自身），随后清空缓存与当前 stage 的 product，并从当前规则起点重试匹配。典型用法是在 hook 内注入缺失的 token，使解析得以继续。若 hook 未注入任何新 token（或未设置 hook），重试一次后即以 `Incomplete sentence` 错误终止，不会无限重试。

CNI 版（`cpp/cni`）将其封装为 `set_eof_hook(fn)` / `clear_eof_hook()` / `push_tokens(arr)` / `append_token(tok)`：hook 在多次 `run()` 之间持续生效，可用 `clear_eof_hook()` 清除（CovScript 版等价写法为 `set_eof_hook(null)`）；`push_tokens` / `append_token` 注入的 token 在下一次 `run()` 触发 EOF 重试时并入 token 流。

## recovering_parser_type

```cpp
class pg::recovering_parser_type final : public parser_type {
public:
    recovering_parser_type();

    bool parse_with_recovery(const token_list_t &lex_output);
    const std::vector<parse_error> &get_all_errors() const;

private:
    std::unordered_set<std::string> m_sync_types;
    std::vector<parse_error> m_all_errors;

    int find_sync_after(int pos);
};
```

遇到错误后跳到同步点（`endl` 或 `;`）继续解析，一次遍历报告多处错误。

`parse_with_recovery` 返回语义：

| 返回值 | 含义 |
|--------|------|
| `true` | 输入被完全消耗 —— 或为一次干净解析，或为错误恢复后的完整解析。恢复情形下 `production()` 返回**最后一个成功段**的 AST，全部段的错误在 `get_all_errors()` |
| `false` | 未能恢复出到 EOF 的完整 accept（重试达到上限 100，或 error 之后没有同步点且重试仍失败）。错误在 `get_all_errors()` |

## generator

```cpp
class pg::generator final {
public:
    bool stop_on_error = true;
    bool show_prompt = true;
    bool enable_log = false;

    void add_grammar(const std::string &lang, grammar gram);
    void add_language(const std::string &lang, const std::string &coding, grammar gram);
    bool from_string(const std::string &lang, const std::string &str);
    bool from_file(const std::string &path);   // 按 ext 选语言：ext 为整条路径的全匹配（regex_match_full）
    bool from_stream(const std::string &lang, std::istream &stream);

    // lang 未注册时返回 std::nullopt（对应 CovScript 参考返回的 null）
    std::optional<token_list_t> lex_string(const std::string &lang, const std::string &text, int start_line);
    std::vector<lex_error> get_lex_errors() const;

    std::shared_ptr<syntax_tree> ast() const;
    const token_list_t &tokens() const;
    const std::vector<std::string> &code() const;
    const std::string &path() const;

    std::vector<parse_error> get_errors();

private:
    std::unordered_map<std::string, grammar> m_rules;
    std::unordered_map<std::string, std::string> m_lang_codings;
    std::string m_input;
    std::vector<std::string> m_code_buff;
    token_list_t m_token_buff;
    std::shared_ptr<syntax_tree> m_ast;
    std::unique_ptr<lexer_type> m_lexer;
    std::unique_ptr<unicode_lexer_type> m_unicode_lexer;
    std::unique_ptr<parser_type> m_parser;
    std::string m_file_path = "<FILE>";

    bool priv_run(const std::string &lang);
};
```

## bootset_type

```cpp
struct pg::bootset_type {
    bool epsilon = false;
    std::unordered_set<std::string> data_set;
    std::unordered_set<std::string> type_set;
    std::unordered_set<std::string> pending_ref;

    bool predict(const token_type &token) const;
    bool all_empty() const;
    bool empty() const;
    void merge(const bootset_type &set);
};
```

## 工具函数

```cpp
namespace pg {
    void print_error(const std::string &file, const std::vector<std::string> &code,
                     const std::vector<parse_error> &err);
    void print_header(const std::string &txt);
    void print_ast(const std::shared_ptr<syntax_tree> &tree);
}
```

## 头文件结构

```
include/parsergen/
├── parsergen.hpp      # 总 include（包含以下所有）
├── token.hpp          # token_type, lex_error, make_token
├── ast.hpp            # syntax_tree, ast_node, print_ast
├── syntax.hpp         # syntax_type, syntax_impl, syntax:: 工厂
├── bootset.hpp        # bootset_type（predict 集合）
├── lexer.hpp          # grammar, lexical_t, token_list_t, lexer_type, unicode_lexer_type
├── unicode.hpp        # codecvt::charset, ascii, utf8, gbk
├── parser.hpp         # parser_type, partial_parser_type, recovering_parser_type
└── generator.hpp      # generator, print_error, print_header
```
