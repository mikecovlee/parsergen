#pragma once
#include <parsergen/token.hpp>

#include <string>
#include <unordered_set>

namespace pg {

struct bootset_type {
	bool epsilon = false;
	std::unordered_set<std::string> data_set;
	std::unordered_set<std::string> type_set;
	std::unordered_set<std::string> pending_ref;

	bool predict(const token_type &token) const
	{
		return data_set.count(token.data) || type_set.count(token.type);
	}

	bool all_empty() const
	{
		return data_set.empty() && type_set.empty() && pending_ref.empty();
	}

	bool empty() const
	{
		return data_set.empty() && type_set.empty();
	}

	void merge(const bootset_type &set)
	{
		epsilon = epsilon || set.epsilon;
		data_set.insert(set.data_set.begin(), set.data_set.end());
		type_set.insert(set.type_set.begin(), set.type_set.end());
		pending_ref.insert(set.pending_ref.begin(), set.pending_ref.end());
	}
};

} // namespace pg
