#pragma once
#include <parsergen/ast.hpp>
#include <parsergen/bootset.hpp>
#include <parsergen/lexer.hpp>
#include <parsergen/syntax.hpp>

#include <deque>
#include <functional>
#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace pg {

namespace parse_state {
constexpr int accept = 2;
constexpr int reject = 1;
constexpr int eof    = 0;
} // namespace parse_state

struct parse_stage {
	syntax_tree product;
	int cursor = 0;
};

struct parse_error {
	int cursor = 0;
	std::string text;
	std::array<int, 2> pos = {0, 0};
};

struct parse_memo {
	int result = 0;
	int cursor = 0;
	std::shared_ptr<syntax_tree> product = nullptr;
};

using syntax_map_t = std::unordered_map<std::string, syntax_seq>;
using predict_cache_t = std::unordered_map<std::string, std::shared_ptr<bootset_type>>;

class parser_type {
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

	int cursor() const { return stack.front().cursor; }
	bool eof() const { return stack.front().cursor >= static_cast<int>(lex->size()); }
	const token_type &peek() const { return lex->at(stack.front().cursor); }

	void error(const std::string &str, std::array<int, 2> pos);
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

public:
	bool log = false;

	parser_type() = default;
	virtual ~parser_type() = default;

	void init(const syntax_map_t &grammar);
	bool parse(const token_list_t &lex_output);
	bool run(const syntax_map_t &grammar, const token_list_t &lex_output);

	std::shared_ptr<syntax_tree> production();
	std::vector<parse_error> get_log(int n);
};

class partial_parser_type : public parser_type {
public:
	std::function<void(partial_parser_type &)> on_eof_hook;

	int match_syntax(const syntax_seq &seq) override;
};

class recovering_parser_type : public parser_type {
	std::unordered_set<std::string> sync_types;
	std::vector<parse_error> all_errors;

	int find_sync_after(int pos);

public:
	recovering_parser_type();

	bool parse_with_recovery(const token_list_t &lex_output);
	const std::vector<parse_error> &get_all_errors() const { return all_errors; }
};

} // namespace pg
