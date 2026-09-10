#pragma once
#include <parsergen/lexer.hpp>
#include <parsergen/parser.hpp>

#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace pg {

class generator final {
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

public:
	bool stop_on_error = true;
	bool show_prompt = true;
	bool enable_log = false;

	void add_grammar(const std::string &lang, grammar gram);
	void add_language(const std::string &lang, const std::string &coding, grammar gram);
	bool from_string(const std::string &lang, const std::string &str);
	bool from_file(const std::string &path);
	bool from_stream(const std::string &lang, std::istream &stream);

	// Returns nullopt when the language is not registered (matches the
	// CovScript reference, which returns null).
	std::optional<token_list_t> lex_string(const std::string &lang, const std::string &text, int start_line);
	std::vector<lex_error> get_lex_errors() const;

	std::shared_ptr<syntax_tree> ast() const
	{
		return m_ast;
	}
	const token_list_t &tokens() const
	{
		return m_token_buff;
	}
	const std::vector<std::string> &code() const
	{
		return m_code_buff;
	}
	const std::string &path() const
	{
		return m_file_path;
	}

	std::vector<parse_error> get_errors();
};

void print_error(const std::string &file, const std::vector<std::string> &code,
                 const std::vector<parse_error> &err);

void print_header(const std::string &txt);

} // namespace pg
