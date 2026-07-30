#pragma once
#include <array>
#include <string>

namespace pg {

struct token_type {
	std::array<int, 2> pos = {0, 0};
	std::string type;
	std::string data;
};

inline token_type make_token(std::array<int, 2> pos, const std::string &type, const std::string &data)
{
	token_type t;
	t.pos = pos;
	t.type = type;
	t.data = data;
	return t;
}

struct lex_error {
	std::string text;
	std::array<int, 2> pos = {0, 0};
};

} // namespace pg
