#pragma once
#include <cstdint>
#include <cwctype>
#include <stdexcept>
#include <string>
#include <string_view>

#include <utf8.h>

namespace pg {
namespace codecvt {

class charset {
public:
	virtual ~charset() = default;

	virtual std::u32string local2wide(std::string_view) = 0;

	virtual std::string wide2local(const std::u32string &) = 0;

	virtual bool is_identifier(char32_t) = 0;
};

class ascii final : public charset {
public:
	std::u32string local2wide(std::string_view local) override
	{
		return std::u32string(local.begin(), local.end());
	}

	std::string wide2local(const std::u32string &wide) override
	{
		return std::string(wide.begin(), wide.end());
	}

	bool is_identifier(char32_t ch) override
	{
		return ch == '_' || std::iswalnum(ch);
	}
};

class utf8 final : public charset {
	static constexpr std::uint32_t ascii_max = 0x7F;

public:
	std::u32string local2wide(std::string_view local) override
	{
		std::u32string ustr;
		::utf8::utf8to32(local.begin(), local.end(), std::back_inserter(ustr));
		return ustr;
	}

	std::string wide2local(const std::u32string &ustr) override
	{
		return ::utf8::utf32to8(ustr);
	}

	bool is_identifier(char32_t ch) override
	{
		if (ch <= ascii_max)
			return ch == '_' || std::iswalnum(ch);
		return (ch >= 0x4E00 && ch <= 0x9FA5) || (ch >= 0x9FA6 && ch <= 0x9FEF) || ch == 0x3007;
	}
};

namespace gbk_impl {
static inline char32_t set_zero(char32_t ch)
{
	return ch & 0x0000ffff;
}

static constexpr std::uint8_t u8_blck_begin = 0x80;
static constexpr std::uint32_t u32_blck_begin = 0x8000;
} // namespace gbk_impl

class gbk final : public charset {
public:
	std::u32string local2wide(std::string_view local) override
	{
		std::u32string wide;
		std::uint32_t head = 0;
		bool read_next = true;
		for (auto it = local.begin(); it != local.end();) {
			if (read_next) {
				head = static_cast<unsigned char>(*(it++));
				if (head & gbk_impl::u8_blck_begin)
					read_next = false;
				else
					wide.push_back(gbk_impl::set_zero(head));
			}
			else {
				std::uint8_t tail = static_cast<unsigned char>(*(it++));
				wide.push_back(gbk_impl::set_zero(head << 8 | tail));
				read_next = true;
			}
		}
		if (!read_next)
			throw std::runtime_error("Codecvt: Bad encoding.");
		return wide;
	}

	std::string wide2local(const std::u32string &wide) override
	{
		std::string local;
		for (auto &ch : wide) {
			if (ch & gbk_impl::u32_blck_begin)
				local.push_back(static_cast<char>(ch >> 8));
			local.push_back(static_cast<char>(ch));
		}
		return local;
	}

	bool is_identifier(char32_t ch) override
	{
		if (ch & gbk_impl::u32_blck_begin)
			return (ch >= 0xB0A1 && ch <= 0xF7FE) || (ch >= 0x8140 && ch <= 0xA0FE) ||
			       (ch >= 0xAA40 && ch <= 0xFEA0) || ch == 0xA996;
		return ch == '_' || std::iswalnum(ch);
	}
};

} // namespace codecvt
} // namespace pg
