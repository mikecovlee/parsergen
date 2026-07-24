#pragma once
#include <parsergen/lexer.hpp>
#include <parsergen/parser.hpp>

#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace pg {

class generator {
	std::unordered_map<std::string, grammar> rules;
	std::string input;
	std::vector<std::string> code_buff;
	token_list_t token_buff;
	std::shared_ptr<syntax_tree> ast_;
	std::unique_ptr<lexer_type> lexer_;
	std::unique_ptr<parser_type> parser_;

	std::string file_path = "<FILE>";

	bool priv_run(const std::string &lang);

public:
	bool stop_on_error = true;
	bool show_prompt = true;
	bool enable_log = false;

	void add_grammar(const std::string &lang, grammar gram);
	bool from_string(const std::string &lang, const std::string &str);
	bool from_file(const std::string &path);

	std::shared_ptr<syntax_tree> ast() const { return ast_; }
	const token_list_t &tokens() const { return token_buff; }
	const std::vector<std::string> &code() const { return code_buff; }
	const std::string &path() const { return file_path; }

	std::vector<parse_error> get_errors();
};

void print_error(const std::string &file, const std::vector<std::string> &code,
                 const std::vector<parse_error> &err);

void print_header(const std::string &txt);

} // namespace pg
