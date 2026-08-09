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

enum class parse_state {
	eof    = 0,
	reject = 1,
	accept = 2
};

struct parse_stage {
	syntax_tree product;
	int cursor = 0;
};

struct parse_error {
	int cursor = 0;
	std::string text;
	std::array<std::size_t, 2> pos = {0, 0};
};

struct parse_memo {
	parse_state result = parse_state::reject;
	int cursor = 0;
	std::shared_ptr<syntax_tree> product = nullptr;
};

using syntax_map_t = std::unordered_map<std::string, syntax_seq>;
using predict_cache_t = std::unordered_map<std::string, std::shared_ptr<bootset_type>>;

class parser_type {
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

	int cursor() const
	{
		return m_stack.front().cursor;
	}
	bool eof() const
	{
		return m_stack.front().cursor >= static_cast<int>(m_lex->size());
	}
	const token_type &peek() const
	{
		return m_lex->at(m_stack.front().cursor);
	}

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

public:
	bool log = false;

	parser_type() = default;
	virtual ~parser_type() = default;

	void init(const syntax_map_t &grammar);
	bool parse(const token_list_t &lex_output);
	bool run(const syntax_map_t &grammar, const token_list_t &lex_output);

	std::shared_ptr<syntax_tree> production() const;
	std::vector<parse_error> get_log(int n);
};

class partial_parser_type final : public parser_type {
public:
	std::function<void(partial_parser_type &)> on_eof_hook;

	parse_state match_syntax(const syntax_seq &seq) override;
};

class recovering_parser_type final : public parser_type {
	std::unordered_set<std::string> m_sync_types;
	std::vector<parse_error> m_all_errors;

	int find_sync_after(int pos);

public:
	recovering_parser_type();

	bool parse_with_recovery(const token_list_t &lex_output);
	const std::vector<parse_error> &get_all_errors() const
	{
		return m_all_errors;
	}
};

} // namespace pg
