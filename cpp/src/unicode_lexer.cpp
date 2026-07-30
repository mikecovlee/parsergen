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
	auto it = regex_cache.find(pattern);
	if (it != regex_cache.end())
		return it->second;
	std::u32string wpattern = cvt->local2wide(pattern);
	auto reg = std::make_shared<compiled_wregex>(wpattern);
	regex_cache[pattern] = reg;
	return reg;
}

void unicode_lexer_type::error(const std::string &str, std::array<int, 2> p)
{
	lex_error err;
	err.text = str;
	err.pos = p;
	error_log.push_back(std::move(err));
}

void unicode_lexer_type::cursor_forward()
{
	char32_t ch = data[pos[2]];
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
	if (lexical_set.empty())
		return;
	if (lexical_set.size() > 1) {
		if (lexical_set.count("err")) {
			error("Unexpected input \"" + cvt->wide2local(buff) + "\"", wpos);
			lexical_set.clear();
			return;
		}
		else {
			lexical_set.erase("ign");
			if (lexical_set.size() > 1) {
				error("Ambiguous lexical \"" + cvt->wide2local(buff) + "\"", wpos);
				lexical_set.clear();
				return;
			}
		}
	}
	std::string rule;
	for (auto &it : lexical_set)
		rule = it;
	if (rule != "ign")
		output.push_back(make_token(wpos, rule, cvt->wide2local(buff)));
}

token_list_t unicode_lexer_type::run(const lexical_t &lexical, const std::string &text)
{
	error_log.clear();
	output.clear();
	data = cvt->local2wide(text);
	pos = {0, 0, 0};
	lexical_set.clear();
	buff.clear();

	std::unordered_map<std::string, std::shared_ptr<compiled_wregex>> compiled;
	for (auto &[name, pattern] : lexical)
		compiled[name] = get_wregex(pattern);

	while (pos[2] != static_cast<int>(data.size())) {
		char32_t ch = data[pos[2]];
		if (lexical_set.empty()) {
			std::u32string nbuff(1, ch);
			for (auto &[name, reg] : compiled) {
				if (reg->match(nbuff))
					lexical_set.insert(name);
			}
			if (!lexical_set.empty()) {
				wpos = {pos[0], pos[1]};
				buff = nbuff;
			}
			else {
				error("Unknown character '" + cvt->wide2local(std::u32string(1, ch)) + "'",
				      {pos[0], pos[1]});
			}
			cursor_forward();
		}
		else {
			std::u32string nbuff = buff;
			nbuff.push_back(ch);
			std::unordered_set<std::string> still_match;
			for (auto &name : lexical_set) {
				if (compiled[name]->match(nbuff))
					still_match.insert(name);
			}
			if (still_match.empty()) {
				process_token();
				lexical_set.clear();
			}
			else {
				lexical_set = std::move(still_match);
				buff = nbuff;
				cursor_forward();
			}
		}
	}
	process_token();
	return output;
}

} // namespace pg
