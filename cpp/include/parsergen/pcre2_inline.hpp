#pragma once
#include <string>
#include <vector>
#include <stdexcept>

#ifndef PCRE2_CODE_UNIT_WIDTH
#define PCRE2_CODE_UNIT_WIDTH 8
#endif

#define PCRE2_NAME_CONCAT_IMPL(a, b) a##_##b
#define PCRE2_NAME_CONCAT(a, b) PCRE2_NAME_CONCAT_IMPL(a, b)
#define PCRE2_RENAME(a) PCRE2_NAME_CONCAT(a, PCRE2_CODE_UNIT_WIDTH)

#ifndef pcre2_stl_string
#define pcre2_stl_string std::string
#endif

#ifndef pcre2_stl_string_view
#define pcre2_stl_string_view std::string_view
#endif

#include <pcre2.h>

#define pcre2_regex PCRE2_RENAME(pcre2_regex)

struct pcre2_regex {
	pcre2_stl_string pattern;
	pcre2_code *code;
	pcre2_match_data *match_data;
	// for JIT
	pcre2_match_context *match_ctx = nullptr;
	pcre2_jit_stack *jit_stack = nullptr;

	pcre2_regex(const pcre2_stl_string &pattern_v, bool try_jit = false) : pattern(pattern_v)
	{
		int errornumber;
		PCRE2_SIZE erroroffset;

		code = pcre2_compile(
		           reinterpret_cast<PCRE2_SPTR>(pattern.data()),
		           pattern.size(),
		           PCRE2_UTF | PCRE2_NEWLINE_ANYCRLF,
		           &errornumber,
		           &erroroffset,
		           nullptr);

		if (!code)
			throw std::runtime_error("PCRE2 compile failed");

		match_data = pcre2_match_data_create_from_pattern(code, nullptr);
		if (!match_data) {
			pcre2_code_free(code);
			throw std::runtime_error("Failed to create match_data");
		}

		if (try_jit) {
			match_ctx = pcre2_match_context_create(nullptr);
			if (match_ctx != nullptr && pcre2_jit_compile(code, PCRE2_JIT_COMPLETE) == 0) {
				jit_stack = pcre2_jit_stack_create(32 * 1024, 512 * 1024, nullptr);
				pcre2_jit_stack_assign(match_ctx, nullptr, jit_stack);
			}
		}
	}

	~pcre2_regex()
	{
		if (jit_stack)
			pcre2_jit_stack_free(jit_stack);
		if (match_ctx)
			pcre2_match_context_free(match_ctx);
		if (match_data)
			pcre2_match_data_free(match_data);
		if (code)
			pcre2_code_free(code);
	}

	pcre2_regex(const pcre2_regex &) = delete;
	pcre2_regex(pcre2_regex &&other) noexcept = delete;
	pcre2_regex &operator=(const pcre2_regex &) = delete;
};

#define pcre2_smatch PCRE2_RENAME(pcre2_smatch)

struct pcre2_smatch {
	bool ready = false;
	pcre2_stl_string input;
	std::vector<pcre2_stl_string_view> groups;
	std::vector<std::pair<size_t, size_t>> offsets;

	pcre2_smatch(pcre2_stl_string_view input_s) : input(input_s) {}

	bool empty() const
	{
		return groups.empty();
	}

	size_t size() const
	{
		return groups.size();
	}

	pcre2_stl_string_view str(size_t i) const
	{
		return groups[i];
	}

	size_t length(size_t i) const
	{
		if (i >= offsets.size())
			throw std::out_of_range("Invalid group index");
		auto [start, end] = offsets[i];
		return end - start;
	}

	size_t position(size_t i) const
	{
		if (i >= offsets.size())
			throw std::out_of_range("Invalid group index");
		return offsets[i].first;
	}

	pcre2_stl_string prefix() const
	{
		if (offsets.empty())
			return input;
		else
			return input.substr(0, offsets[0].first);
	}

	pcre2_stl_string suffix() const
	{
		if (offsets.empty())
			return input;
		else
			return input.substr(offsets.back().second);
	}
};

using pcre2_regex_t = std::shared_ptr<pcre2_regex>;

#define pcre2_regex_match PCRE2_RENAME(pcre2_regex_match)

inline pcre2_smatch pcre2_regex_match(pcre2_regex_t &reg, pcre2_stl_string_view input, uint32_t option)
{
	pcre2_smatch result(input);
	PCRE2_SPTR input_sptr = reinterpret_cast<PCRE2_SPTR>(input.data());

	int rc = pcre2_match(
	             reg->code,
	             input_sptr,
	             result.input.size(),
	             0, // start offset
	             option,
	             reg->match_data,
	             reg->match_ctx);

	if (rc > 0) {
		PCRE2_SIZE *ovector = pcre2_get_ovector_pointer(reg->match_data);
		for (int i = 0; i < rc; ++i) {
			PCRE2_SIZE start = ovector[2 * i];
			PCRE2_SIZE end = ovector[2 * i + 1];
			result.offsets.emplace_back(start, end);
			result.groups.emplace_back(reinterpret_cast<const pcre2_stl_string::value_type *>(input_sptr + start), end - start);
		}
		result.ready = true;
	}

	return result;
}

#define pcre2_regex_replace PCRE2_RENAME(pcre2_regex_replace)

inline pcre2_stl_string pcre2_regex_replace(pcre2_regex_t &reg, pcre2_stl_string_view input, pcre2_stl_string_view fmt)
{
	pcre2_stl_string out(input.size() * 2, '\0');
	PCRE2_SIZE out_len = out.size();

	int rc = pcre2_substitute(
	             reg->code,
	             reinterpret_cast<PCRE2_SPTR>(input.data()),
	             input.size(),
	             0,
	             PCRE2_SUBSTITUTE_GLOBAL,
	             reg->match_data,
	             reg->match_ctx,
	             reinterpret_cast<PCRE2_SPTR>(fmt.data()),
	             fmt.size(),
	             reinterpret_cast<PCRE2_UCHAR *>(&out[0]),
	             &out_len);

	if (rc == PCRE2_ERROR_NOMEMORY) {
		out.resize(out_len);
		rc = pcre2_substitute(
		         reg->code,
		         reinterpret_cast<PCRE2_SPTR>(input.data()),
		         input.size(),
		         0,
		         PCRE2_SUBSTITUTE_GLOBAL,
		         reg->match_data,
		         reg->match_ctx,
		         reinterpret_cast<PCRE2_SPTR>(fmt.data()),
		         fmt.size(),
		         reinterpret_cast<PCRE2_UCHAR *>(&out[0]),
		         &out_len);
	}

	if (rc < 0)
		throw std::runtime_error("Regex replace failed");

	out.resize(out_len);
	return out;
}
