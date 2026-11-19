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
	m_rules[lang] = std::move(gram);
}

void generator::add_language(const std::string &lang, const std::string &coding, grammar gram)
{
	m_lang_codings[lang] = coding;
	m_rules[lang] = std::move(gram);
}

bool generator::priv_run(const std::string &lang)
{
	auto it = m_rules.find(lang);
	if (it == m_rules.end())
		return false;
	auto &gram = it->second;

	m_lexer.reset();
	m_unicode_lexer.reset();
	m_parser.reset();
	m_ast.reset();

	std::string coding;
	auto cit = m_lang_codings.find(lang);
	if (cit != m_lang_codings.end())
		coding = cit->second;

	std::vector<lex_error> *lex_errors_ptr = nullptr;
	if (coding == "utf8") {
		m_unicode_lexer = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::utf8>());
		if (gram.lex.empty()) {
			if (show_prompt)
				print_header("Lexical rules not found! Stop");
			return false;
		}
		m_token_buff = m_unicode_lexer->run(gram.lex, m_input);
		lex_errors_ptr = &m_unicode_lexer->error_log;
	}
	else if (coding == "gbk") {
		m_unicode_lexer = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::gbk>());
		if (gram.lex.empty()) {
			if (show_prompt)
				print_header("Lexical rules not found! Stop");
			return false;
		}
		m_token_buff = m_unicode_lexer->run(gram.lex, m_input);
		lex_errors_ptr = &m_unicode_lexer->error_log;
	}
	else {
		m_lexer = std::make_unique<lexer_type>();
		if (gram.lex.empty()) {
			if (show_prompt)
				print_header("Lexical rules not found! Stop");
			return false;
		}
		m_token_buff = m_lexer->run(gram.lex, m_input);
		lex_errors_ptr = &m_lexer->error_log;
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
			print_error(m_file_path, m_code_buff, lex_errors);
		}
		if (stop_on_error)
			return false;
	}

	m_parser = std::make_unique<parser_type>();
	m_parser->log = enable_log;
	if (gram.stx.empty()) {
		if (show_prompt)
			print_header("Syntactic rules not found! Stop");
		return false;
	}
	if (m_parser->run(gram.stx, m_token_buff)) {
		m_ast = m_parser->production();
		return true;
	}
	else {
		if (show_prompt) {
			print_header("Compilation Error");
			auto err = get_errors();
			print_error(m_file_path, m_code_buff, err);
		}
		return false;
	}
}

bool generator::from_string(const std::string &lang, const std::string &str)
{
	m_file_path = "<FILE>";
	m_input = str;
	m_code_buff.clear();
	std::istringstream stream(m_input);
	std::string line;
	while (std::getline(stream, line)) {
		m_code_buff.push_back(line);
	}
	m_code_buff.push_back("");
	return priv_run(lang);
}

bool generator::from_stream(const std::string &lang, std::istream &stream)
{
	m_file_path = "<FILE>";
	m_input.clear();
	m_code_buff.clear();
	std::string line;
	while (std::getline(stream, line)) {
		if (!line.empty() && line.back() == '\r')
			line.pop_back();
		m_input += line + "\n";
		std::replace(line.begin(), line.end(), '\t', ' ');
		m_code_buff.push_back(line);
	}
	m_code_buff.push_back("");
	return priv_run(lang);
}

bool generator::from_file(const std::string &path)
{
	std::vector<std::string> matched;
	for (auto &[lang, gram] : m_rules) {
		if (regex_match_full(gram.ext, path))
			matched.push_back(lang);
	}
	if (matched.empty())
		return false;
	std::sort(matched.begin(), matched.end());

	std::ifstream ifs(path);
	if (!ifs.good())
		return false;
	std::string content((std::istreambuf_iterator<char>(ifs)),
	                    std::istreambuf_iterator<char>());
	m_file_path = path;
	m_input = content;
	if (!m_input.empty() && m_input.back() != '\n')
		m_input += '\n';
	m_code_buff.clear();
	std::istringstream stream(m_input);
	std::string line;
	while (std::getline(stream, line)) {
		if (!line.empty() && line.back() == '\r')
			line.pop_back();
		std::replace(line.begin(), line.end(), '\t', ' ');
		m_code_buff.push_back(line);
	}
	m_code_buff.push_back("");
	return priv_run(matched.front());
}

std::optional<token_list_t> generator::lex_string(const std::string &lang, const std::string &text, int start_line)
{
	auto it = m_rules.find(lang);
	if (it == m_rules.end())
		return std::nullopt;
	auto &gram = it->second;

	m_lexer.reset();
	m_unicode_lexer.reset();

	std::string coding;
	auto cit = m_lang_codings.find(lang);
	if (cit != m_lang_codings.end())
		coding = cit->second;

	if (coding == "utf8") {
		m_unicode_lexer = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::utf8>());
		m_unicode_lexer->pos[1] = start_line;
		return m_unicode_lexer->run(gram.lex, text);
	}
	else if (coding == "gbk") {
		m_unicode_lexer = std::make_unique<unicode_lexer_type>(std::make_shared<codecvt::gbk>());
		m_unicode_lexer->pos[1] = start_line;
		return m_unicode_lexer->run(gram.lex, text);
	}
	else {
		m_lexer = std::make_unique<lexer_type>();
		m_lexer->pos[1] = start_line;
		return m_lexer->run(gram.lex, text);
	}
}

std::vector<lex_error> generator::get_lex_errors() const
{
	if (m_lexer)
		return m_lexer->error_log;
	if (m_unicode_lexer)
		return m_unicode_lexer->error_log;
	return {};
	}

std::vector<parse_error> generator::get_errors()
{
	std::vector<parse_error> err;
	if (m_lexer) {
		for (auto &e : m_lexer->error_log) {
			parse_error pe;
			pe.text = e.text;
			pe.pos = e.pos;
			err.push_back(pe);
		}
	}
	if (m_unicode_lexer) {
		for (auto &e : m_unicode_lexer->error_log) {
			parse_error pe;
			pe.text = e.text;
			pe.pos = e.pos;
			err.push_back(pe);
		}
	}
	if (m_parser) {
		auto perr = m_parser->get_log(0);
		err.insert(err.end(), perr.begin(), perr.end());
	}
	std::sort(err.begin(), err.end(),
	[](const parse_error &lhs, const parse_error &rhs) {
		return lhs.pos[1] < rhs.pos[1];
	});
	return err;
}

} // namespace pg
