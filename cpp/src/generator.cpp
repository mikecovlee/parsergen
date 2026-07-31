#include <parsergen/generator.hpp>

#include <algorithm>
#include <fstream>
#include <iostream>
#include <sstream>

namespace pg {

void print_header(const std::string &txt)
{
	for (std::size_t i = 0; i < txt.size(); ++i)
		std::cout << '#';
	std::cout << "\n" << txt << "\n";
	for (std::size_t i = 0; i < txt.size(); ++i)
		std::cout << '#';
	std::cout << "\n";
}

void print_error(const std::string &file, const std::vector<std::string> &code,
                 const std::vector<parse_error> &err)
{
	for (auto &it : err) {
		std::cout << "File \"" << file << "\", line " << (it.pos[1] + 1) << ": " << it.text << "\n";
		if (it.pos[1] < code.size()) {
			std::cout << "> " << code[it.pos[1]] << "\n";
			for (std::size_t i = 0; i < it.pos[0] + 2; ++i)
				std::cout << ' ';
			std::cout << "^\n\n";
		}
	}
}

void generator::add_grammar(const std::string &lang, grammar gram)
{
	rules[lang] = std::move(gram);
}

void generator::add_language(const std::string &lang, const std::string &coding, grammar gram)
{
	lang_codings[lang] = coding;
	rules[lang] = std::move(gram);
}

bool generator::priv_run(const std::string &lang)
{
	auto it = rules.find(lang);
	if (it == rules.end())
		return false;
	auto &gram = it->second;

	lexer_.reset();
	unicode_lexer_.reset();
	parser_.reset();
	ast_.reset();

	std::string coding;
	auto cit = lang_codings.find(lang);
	if (cit != lang_codings.end())
		coding = cit->second;

	std::vector<lex_error> *lex_errors_ptr = nullptr;
	if (coding == "utf8") {
		unicode_lexer_ = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::utf8>());
		if (gram.lex.empty()) {
			if (show_prompt)
				print_header("Lexical rules not found! Stop");
			return false;
		}
		token_buff = unicode_lexer_->run(gram.lex, input);
		lex_errors_ptr = &unicode_lexer_->error_log;
	}
	else if (coding == "gbk") {
		unicode_lexer_ = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::gbk>());
		if (gram.lex.empty()) {
			if (show_prompt)
				print_header("Lexical rules not found! Stop");
			return false;
		}
		token_buff = unicode_lexer_->run(gram.lex, input);
		lex_errors_ptr = &unicode_lexer_->error_log;
	}
	else {
		lexer_ = std::make_unique<lexer_type>();
		if (gram.lex.empty()) {
			if (show_prompt)
				print_header("Lexical rules not found! Stop");
			return false;
		}
		token_buff = lexer_->run(gram.lex, input);
		lex_errors_ptr = &lexer_->error_log;
	}

	if (!lex_errors_ptr->empty()) {
		if (show_prompt) {
			if (stop_on_error)
				print_header("Compilation Error");
			else
				print_header("Compilation Warning");
			std::vector<parse_error> lex_errors;
			for (auto &e : *lex_errors_ptr) {
				parse_error pe;
				pe.text = e.text;
				pe.pos = e.pos;
				lex_errors.push_back(pe);
			}
			print_error(file_path, code_buff, lex_errors);
		}
		if (stop_on_error)
			return false;
	}

	parser_ = std::make_unique<parser_type>();
	parser_->log = enable_log;
	if (gram.stx.empty()) {
		if (show_prompt)
			print_header("Syntactic rules not found! Stop");
		return false;
	}
	if (parser_->run(gram.stx, token_buff)) {
		ast_ = parser_->production();
		return true;
	}
	else {
		if (show_prompt) {
			print_header("Compilation Error");
			auto err = get_errors();
			print_error(file_path, code_buff, err);
		}
		return false;
	}
}

bool generator::from_string(const std::string &lang, const std::string &str)
{
	file_path = "<FILE>";
	input = str;
	code_buff.clear();
	std::istringstream stream(input);
	std::string line;
	while (std::getline(stream, line)) {
		if (!line.empty() && line.back() == '\r')
			line.pop_back();
		code_buff.push_back(line);
	}
	code_buff.push_back("");
	return priv_run(lang);
}

bool generator::from_stream(const std::string &lang, std::istream &stream)
{
	file_path = "<FILE>";
	input.clear();
	code_buff.clear();
	std::string line;
	while (std::getline(stream, line)) {
		if (!line.empty() && line.back() == '\r')
			line.pop_back();
		input += line + "\n";
		std::replace(line.begin(), line.end(), '\t', ' ');
		code_buff.push_back(line);
	}
	code_buff.push_back("");
	return priv_run(lang);
}

bool generator::from_file(const std::string &path)
{
	std::ifstream ifs(path);
	if (!ifs.good())
		return false;
	for (auto &[lang, gram] : rules) {
		if (regex_match(gram.ext, path)) {
			std::string content((std::istreambuf_iterator<char>(ifs)),
			                    std::istreambuf_iterator<char>());
			file_path = path;
			input = content;
			if (!input.empty() && input.back() != '\n')
				input += '\n';
			code_buff.clear();
			std::istringstream stream(input);
			std::string line;
			while (std::getline(stream, line)) {
				if (!line.empty() && line.back() == '\r')
					line.pop_back();
				std::replace(line.begin(), line.end(), '\t', ' ');
				code_buff.push_back(line);
			}
			code_buff.push_back("");
			return priv_run(lang);
		}
	}
	return false;
}

token_list_t generator::lex_string(const std::string &lang, const std::string &text, int start_line)
{
	auto it = rules.find(lang);
	if (it == rules.end())
		return {};
	auto &gram = it->second;

	std::string coding;
	auto cit = lang_codings.find(lang);
	if (cit != lang_codings.end())
		coding = cit->second;

	if (coding == "utf8") {
		unicode_lexer_ = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::utf8>());
		unicode_lexer_->pos[1] = start_line;
		return unicode_lexer_->run(gram.lex, text);
	}
	else if (coding == "gbk") {
		unicode_lexer_ = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::gbk>());
		unicode_lexer_->pos[1] = start_line;
		return unicode_lexer_->run(gram.lex, text);
	}
	else {
		lexer_ = std::make_unique<lexer_type>();
		lexer_->pos[1] = start_line;
		return lexer_->run(gram.lex, text);
	}
}

std::vector<lex_error> generator::get_lex_errors() const
{
	if (lexer_)
		return lexer_->error_log;
	if (unicode_lexer_)
		return unicode_lexer_->error_log;
	return {};
}

std::vector<parse_error> generator::get_errors()
{
	std::vector<parse_error> err;
	if (lexer_) {
		for (auto &e : lexer_->error_log) {
			parse_error pe;
			pe.text = e.text;
			pe.pos = e.pos;
			err.push_back(pe);
		}
	}
	if (unicode_lexer_) {
		for (auto &e : unicode_lexer_->error_log) {
			parse_error pe;
			pe.text = e.text;
			pe.pos = e.pos;
			err.push_back(pe);
		}
	}
	if (parser_) {
		auto perr = parser_->get_log(0);
		err.insert(err.end(), perr.begin(), perr.end());
	}
	std::sort(err.begin(), err.end(),
	          [](const parse_error &lhs, const parse_error &rhs) { return lhs.pos[1] < rhs.pos[1]; });
	return err;
}

} // namespace pg
