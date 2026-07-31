#include <parsergen/lexer.hpp>

#include <pcre2.hpp>

namespace pg {
std::string regex_pattern(const regex_handle_t &reg)
{
	return std::static_pointer_cast<pcre2_regex>(reg)->pattern;
}

bool regex_match(const std::string &pattern, const std::string &text)
{
	auto reg = std::make_shared<pcre2_regex>(pattern);
	return !pcre2_regex_match(reg, text, 0).empty();
}
} // namespace pg

struct pg::lexer_type::compiled_regex {
	pcre2_regex_t reg;

	explicit compiled_regex(const std::string &pattern)
	    : reg(std::make_shared<pcre2_regex>(pattern, true))
	{}

	bool match(const std::string &text)
	{
		return !pcre2_regex_match(reg, text, PCRE2_ANCHORED | PCRE2_ENDANCHORED).empty();
	}
};

namespace pg {

std::shared_ptr<lexer_type::compiled_regex> lexer_type::get_regex(const std::string &pattern)
{
	auto it = regex_cache.find(pattern);
	if (it != regex_cache.end())
		return it->second;
	auto reg = std::make_shared<compiled_regex>(pattern);
	regex_cache[pattern] = reg;
	return reg;
}

void lexer_type::error(const std::string &str, std::array<std::size_t, 2> p)
{
	lex_error err;
	err.text = str;
	err.pos = p;
	error_log.push_back(std::move(err));
}

void lexer_type::process_token()
{
	if (lexical_set.empty())
		return;
	if (lexical_set.size() > 1) {
		if (lexical_set.count("err")) {
			error("Unexpected input \"" + buff + "\"", wpos);
			lexical_set.clear();
			return;
		}
		else {
			lexical_set.erase("ign");
			if (lexical_set.size() > 1) {
				error("Ambiguous lexical \"" + buff + "\"", wpos);
				lexical_set.clear();
				return;
			}
		}
	}
	std::string rule;
	for (auto &it : lexical_set)
		rule = it;
	if (rule != "ign")
		output.push_back(make_token(wpos, rule, buff));
}

token_list_t lexer_type::run(const lexical_t &lexical, const std::string &text)
{
	error_log.clear();
	output.clear();
	data = text;
	pos[0] = 0;
	pos[2] = 0;
	lexical_set.clear();
	buff.clear();

	std::unordered_map<std::string, std::shared_ptr<compiled_regex>> compiled;
	for (auto &[name, pattern] : lexical)
		compiled[name] = get_regex(pattern);

	while (pos[2] != data.size()) {
		char ch = data[pos[2]];
		if (lexical_set.empty()) {
			std::string nbuff(1, ch);
			for (auto &[name, reg] : compiled) {
				if (reg->match(nbuff))
					lexical_set.insert(name);
			}
			if (!lexical_set.empty()) {
				wpos = {pos[0], pos[1]};
				buff = nbuff;
			}
			else {
				error(std::string("Unknown character '") + ch + "'", {pos[0], pos[1]});
			}
			++pos[2];
			if (ch == '\n') {
				++pos[1];
				pos[0] = 0;
			}
			else {
				++pos[0];
			}
		}
		else {
			std::string nbuff = buff + ch;
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
				++pos[2];
				if (ch == '\n') {
					++pos[1];
					pos[0] = 0;
				}
				else {
					++pos[0];
				}
			}
		}
	}
	process_token();
	return output;
}

} // namespace pg
