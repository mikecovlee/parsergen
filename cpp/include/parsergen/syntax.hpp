#pragma once
#include <any>
#include <memory>
#include <string>
#include <vector>

namespace pg {

enum class syntax_type {
	token  = 1,
	term   = 2,
	ref    = 3,
	nlook  = 4,
	repeat = 5,
	opt    = 6,
	cond   = 7,
	cond_p = 8
};

struct bootset_type;

struct syntax_impl {
	std::shared_ptr<bootset_type> boot = nullptr;
	syntax_type type;
	std::any data;
};

using syntax_t = std::shared_ptr<syntax_impl>;
using syntax_seq = std::vector<syntax_t>;

inline syntax_t make_syntax(syntax_type type, std::any data)
{
	auto s = std::make_shared<syntax_impl>();
	s->type = type;
	s->data = std::move(data);
	return s;
}

namespace syntax {
	inline syntax_t token(const std::string &data)
	{
		return make_syntax(syntax_type::token, data);
	}

	inline syntax_t term(const std::string &data)
	{
		return make_syntax(syntax_type::term, data);
	}

	inline syntax_t ref(const std::string &name)
	{
		return make_syntax(syntax_type::ref, name);
	}

	inline syntax_t nlook(syntax_seq args)
	{
		return make_syntax(syntax_type::nlook, std::move(args));
	}

	inline syntax_t repeat(syntax_seq args)
	{
		return make_syntax(syntax_type::repeat, std::move(args));
	}

	inline syntax_t optional(syntax_seq args)
	{
		return make_syntax(syntax_type::opt, std::move(args));
	}

	inline syntax_t cond_or(std::initializer_list<syntax_seq> args)
	{
		syntax_seq data;
		for (auto &seq : args)
			data.push_back(make_syntax(syntax_type::cond_p, seq));
		return make_syntax(syntax_type::cond, std::move(data));
	}
} // namespace syntax

} // namespace pg
