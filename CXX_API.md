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
    syntax_type type;
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

struct grammar {
    std::string ext = ".*";
    lexical_t lex;
    std::unordered_map<std::string, syntax_seq> stx;
};

// parser.hpp
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
    int result = 0;
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
class pg::lexer_type {
public:
    std::array<std::size_t, 3> pos = {0, 0, 0};   // [col, line, cursor]
    std::vector<lex_error> error_log;
    token_list_t output;

    void error(const std::string &str, std::array<std::size_t, 2> p);
    token_list_t run(const lexical_t &lexical, const std::string &text);

private:
    // 内部状态
    std::unordered_set<std::string> lexical_set;
    std::string buff;
    std::string data;
    std::array<std::size_t, 2> wpos = {0, 0};
    std::unordered_map<std::string, std::shared_ptr<compiled_regex>> regex_cache;

    std::shared_ptr<compiled_regex> get_regex(const std::string &pattern);
    void process_token();
};
```

## unicode_lexer_type

```cpp
class pg::unicode_lexer_type {
public:
    std::array<std::size_t, 3> pos = {0, 0, 0};
    std::vector<lex_error> error_log;
    token_list_t output;

    explicit unicode_lexer_type(std::shared_ptr<codecvt::charset> c);

    void error(const std::string &str, std::array<std::size_t, 2> p);
    token_list_t run(const lexical_t &lexical, const std::string &text);

private:
    std::shared_ptr<codecvt::charset> cvt;
    std::unordered_set<std::string> lexical_set;
    std::u32string buff;
    std::u32string data;
    std::array<std::size_t, 2> wpos = {0, 0};
    std::unordered_map<std::string, std::shared_ptr<compiled_wregex>> regex_cache;

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

    std::shared_ptr<syntax_tree> production();
    std::vector<parse_error> get_log(int n);

protected:
    std::deque<parse_stage> stack;
    const syntax_map_t *syn = nullptr;
    const token_list_t *lex = nullptr;

    std::vector<parse_error> error_log;
    int max_cursor = 0;
    int max_prediction_pass = 20;
    predict_cache_t predict_cache;
    std::shared_ptr<bootset_type> ign_bootset;
    bool on_ign = false;

    std::unordered_map<std::string, parse_memo> memo_cache;
    std::unordered_map<std::string, std::optional<int>> ign_cache;

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

    virtual int match_syntax(const syntax_seq &seq);
    std::optional<int> try_ignore();
    void ignore();
    int predict(const std::shared_ptr<bootset_type> &set);
    int match(const syntax_t &it);

    std::shared_ptr<bootset_type> prep_syntax(const syntax_seq &seq);
    bool expand_pending_ref(std::shared_ptr<bootset_type> &boot);
    void solve_pending_ref();
};
```

## partial_parser_type

```cpp
class pg::partial_parser_type : public parser_type {
public:
    std::function<void(partial_parser_type &)> on_eof_hook;

    int match_syntax(const syntax_seq &seq) override;
};
```

## recovering_parser_type

```cpp
class pg::recovering_parser_type : public parser_type {
public:
    recovering_parser_type();

    bool parse_with_recovery(const token_list_t &lex_output);
    const std::vector<parse_error> &get_all_errors() const;

private:
    std::unordered_set<std::string> sync_types;
    std::vector<parse_error> all_errors;

    int find_sync_after(int pos);
};
```

## generator

```cpp
class pg::generator {
public:
    bool stop_on_error = true;
    bool show_prompt = true;
    bool enable_log = false;

    void add_grammar(const std::string &lang, grammar gram);
    void add_language(const std::string &lang, const std::string &coding, grammar gram);
    bool from_string(const std::string &lang, const std::string &str);
    bool from_file(const std::string &path);
    bool from_stream(const std::string &lang, std::istream &stream);

    token_list_t lex_string(const std::string &lang, const std::string &text, int start_line);
    std::vector<lex_error> get_lex_errors() const;

    std::shared_ptr<syntax_tree> ast() const;
    const token_list_t &tokens() const;
    const std::vector<std::string> &code() const;
    const std::string &path() const;

    std::vector<parse_error> get_errors();

private:
    std::unordered_map<std::string, grammar> rules;
    std::unordered_map<std::string, std::string> lang_codings;
    std::string input;
    std::vector<std::string> code_buff;
    token_list_t token_buff;
    std::shared_ptr<syntax_tree> ast_;
    std::unique_ptr<lexer_type> lexer_;
    std::unique_ptr<unicode_lexer_type> unicode_lexer_;
    std::unique_ptr<parser_type> parser_;
    std::string file_path = "<FILE>";

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
