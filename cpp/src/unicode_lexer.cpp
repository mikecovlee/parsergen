#define PCRE2_CODE_UNIT_WIDTH 32
#define pcre2_stl_string std::u32string
#define pcre2_stl_string_view std::u32string_view

#include <parsergen/lexer.hpp>

#include <pcre2.hpp>

struct pg::unicode_lexer_type::compiled_wregex {
	pcre2_regex_t reg;

	explicit compiled_wregex(const std::u32string &pattern)
		: reg(std::make_shared<pcre2_regex>(pattern, true))
	{}

	bool match(const std::u32string &text)
	{
		return !pcre2_regex_match(reg, text, PCRE2_ANCHORED | PCRE2_ENDANCHORED).empty();
	}
};

namespace pg {

std::shared_ptr<unicode_lexer_type::compiled_wregex>
unicode_lexer_type::get_wregex(const std::string &pattern)
{
	auto it = m_regex_cache.find(pattern);
	if (it != m_regex_cache.end())
		return it->second;
	std::u32string wpattern = m_cvt->local2wide(pattern);
	auto reg = std::make_shared<compiled_wregex>(wpattern);
	m_regex_cache[pattern] = reg;
	return reg;
}

void unicode_lexer_type::error(const std::string &str, std::array<std::size_t, 2> p)
{
	lex_error err;
	err.text = str;
	err.pos = p;
	error_log.push_back(std::move(err));
}

void unicode_lexer_type::cursor_forward()
{
	char32_t ch = m_data[pos[2]];
	++pos[2];
	if (ch == U'\n') {
		++pos[1];
		pos[0] = 0;
	}
	else {
		++pos[0];
	}
}

void unicode_lexer_type::process_token()
{
	if (m_lexical_set.empty())
		return;
	if (m_lexical_set.size() > 1) {
		if (m_lexical_set.count("err")) {
			error("Unexpected input \"" + m_cvt->wide2local(m_buff) + "\"", m_wpos);
			m_lexical_set.clear();
			return;
		}
		else {
			m_lexical_set.erase("ign");
			if (m_lexical_set.size() > 1) {
				error("Ambiguous lexical \"" + m_cvt->wide2local(m_buff) + "\"", m_wpos);
				m_lexical_set.clear();
				return;
			}
		}
	}
	std::string rule;
	for (auto &it : m_lexical_set)
		rule = it;
	if (rule != "ign")
		output.push_back(make_token(m_wpos, rule, m_cvt->wide2local(m_buff)));
}

token_list_t unicode_lexer_type::run(const lexical_t &lexical, const std::string &text)
{
	error_log.clear();
	output.clear();
	m_data = m_cvt->local2wide(text);
	pos[0] = 0;
	pos[2] = 0;
	m_lexical_set.clear();
	m_buff.clear();

	std::unordered_map<std::string, std::shared_ptr<compiled_wregex>> compiled;
	for (auto &[name, pattern] : lexical)
		compiled[name] = get_wregex(pattern);

	while (pos[2] != m_data.size()) {
		char32_t ch = m_data[pos[2]];
		if (m_lexical_set.empty()) {
			std::u32string nbuff(1, ch);
			for (auto &[name, reg] : compiled) {
				if (reg->match(nbuff))
					m_lexical_set.insert(name);
			}
			if (!m_lexical_set.empty()) {
				m_wpos = {pos[0], pos[1]};
				m_buff = nbuff;
			}
			else {
				error("Unknown character '" + m_cvt->wide2local(std::u32string(1, ch)) + "'",
				{pos[0], pos[1]});
			}
			cursor_forward();
		}
		else {
			std::u32string nbuff = m_buff;
			nbuff.push_back(ch);
			std::unordered_set<std::string> still_match;
			for (auto &name : m_lexical_set) {
				if (compiled[name]->match(nbuff))
					still_match.insert(name);
			}
			if (still_match.empty()) {
				process_token();
				m_lexical_set.clear();
			}
			else {
				m_lexical_set = std::move(still_match);
				m_buff = nbuff;
				cursor_forward();
			}
		}
	}
	process_token();
	return output;
}

} // namespace pg
