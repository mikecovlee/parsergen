#pragma once
#include <parsergen/syntax.hpp>
#include <parsergen/token.hpp>
#include <parsergen/unicode.hpp>

#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace pg {

using lexical_t = std::map<std::string, std::string>;
using token_list_t = std::vector<token_type>;

using regex_handle_t = std::shared_ptr<void>;
std::string regex_pattern(const regex_handle_t &reg);
bool regex_match(const std::string &pattern, const std::string &text);
// Full-string (anchored) match: the whole text must match the pattern.
// Mirrors the CovScript reference `from_file` ext selection.
bool regex_match_full(const std::string &pattern, const std::string &text);

struct grammar {
	std::string ext = ".*";
	lexical_t lex;
	std::unordered_map<std::string, syntax_seq> stx;
};

class lexer_type final {
	struct compiled_regex;

	std::unordered_set<std::string> m_lexical_set;
	std::string m_buff;
	std::string m_data;
	std::array<std::size_t, 2> m_wpos = {0, 0};

	std::unordered_map<std::string, std::shared_ptr<compiled_regex>> m_regex_cache;

	std::shared_ptr<compiled_regex> get_regex(const std::string &pattern);
	void process_token();

public:
	std::array<std::size_t, 3> pos = {0, 0, 0};
	std::vector<lex_error> error_log;
	token_list_t output;

	void error(const std::string &str, std::array<std::size_t, 2> p);
	token_list_t run(const lexical_t &lexical, const std::string &text);
};

class unicode_lexer_type final {
	struct compiled_wregex;

	std::shared_ptr<codecvt::charset> m_cvt;
	std::unordered_set<std::string> m_lexical_set;
	std::u32string m_buff;
	std::u32string m_data;
	std::array<std::size_t, 2> m_wpos = {0, 0};

	std::unordered_map<std::string, std::shared_ptr<compiled_wregex>> m_regex_cache;

	std::shared_ptr<compiled_wregex> get_wregex(const std::string &pattern);
	void cursor_forward();
	void process_token();

public:
	std::array<std::size_t, 3> pos = {0, 0, 0};
	std::vector<lex_error> error_log;
	token_list_t output;

	explicit unicode_lexer_type(std::shared_ptr<codecvt::charset> c) : m_cvt(std::move(c)) {}

	void error(const std::string &str, std::array<std::size_t, 2> p);
	token_list_t run(const lexical_t &lexical, const std::string &text);
};

} // namespace pg
