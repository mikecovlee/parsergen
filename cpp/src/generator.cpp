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
		if (it.pos[1] < static_cast<int>(code.size())) {
			std::cout << "> " << code[it.pos[1]] << "\n";
			for (int i = 0; i < it.pos[0] + 2; ++i)
				std::cout << ' ';
			std::cout << "^\n\n";
		}
	}
}

void generator::add_grammar(const std::string &lang, grammar gram)
{
	rules[lang] = std::move(gram);
}

bool generator::priv_run(const std::string &lang)
{
	auto it = rules.find(lang);
	if (it == rules.end())
		return false;
	auto &gram = it->second;

	lexer_ = std::make_unique<lexer_type>();
	if (gram.lex.empty()) {
		if (show_prompt)
			print_header("Lexical rules not found! Stop");
		return false;
	}
	token_buff = lexer_->run(gram.lex, input);
	if (!lexer_->error_log.empty()) {
		if (show_prompt) {
			if (stop_on_error)
				print_header("Compilation Error");
			else
				print_header("Compilation Warning");
			std::vector<parse_error> lex_errors;
			for (auto &e : lexer_->error_log) {
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
	input = str;
	code_buff.clear();
	std::istringstream stream(str);
	std::string line;
	while (std::getline(stream, line)) {
		if (!line.empty() && line.back() == '\r')
			line.pop_back();
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
	file_path = path;
	for (auto &[lang, gram] : rules) {
		std::string ext_pattern = gram.ext;
		if (path.size() >= ext_pattern.size()) {
			bool matched = true;
			for (std::size_t i = 0; i < ext_pattern.size(); ++i) {
				if (ext_pattern[i] == '.') {
					if (i + 1 < ext_pattern.size() && ext_pattern[i + 1] == '*') {
						continue;
					}
				}
				if (ext_pattern[i] == '*')
					continue;
				std::size_t pi = path.size() - ext_pattern.size() + i;
				if (pi < path.size() && path[pi] != ext_pattern[i]) {
					matched = false;
					break;
				}
			}
			if (matched) {
				std::string content((std::istreambuf_iterator<char>(ifs)),
				                    std::istreambuf_iterator<char>());
				return from_string(lang, content);
			}
		}
	}
	return false;
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
	if (parser_) {
		auto perr = parser_->get_log(0);
		err.insert(err.end(), perr.begin(), perr.end());
	}
	std::sort(err.begin(), err.end(),
	          [](const parse_error &lhs, const parse_error &rhs) { return lhs.pos[1] < rhs.pos[1]; });
	return err;
}

} // namespace pg
