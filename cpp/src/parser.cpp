#include <parsergen/parser.hpp>

#include <algorithm>
#include <iostream>

namespace pg {

void parser_type::push_stage(const std::string &root)
{
	int prev_cursor = 0;
	if (!stack.empty())
		prev_cursor = stack.front().cursor;
	stack.push_front(parse_stage{});
	auto &top = stack.front();
	top.product.root = root;
	top.cursor = prev_cursor;
}

parse_stage parser_type::pop_stage()
{
	auto stage = std::move(stack.front());
	stack.pop_front();
	return stage;
}

void parser_type::push(ast_node val)
{
	stack.front().product.nodes.push_back(std::move(val));
}

void parser_type::push_token()
{
	auto &top = stack.front();
	top.product.nodes.push_back(lex->at(top.cursor));
	++top.cursor;
}

void parser_type::error(const std::string &str, std::array<int, 2> p)
{
	parse_error err;
	err.cursor = stack.front().cursor;
	err.text = str;
	err.pos = p;
	if (err.cursor > max_cursor)
		max_cursor = err.cursor;
	error_log.push_back(std::move(err));
}

std::vector<parse_error> parser_type::get_log(int n)
{
	std::unordered_set<std::string> set;
	std::vector<parse_error> arr;
	for (auto &it : error_log) {
		if (it.cursor >= max_cursor - n && !set.count(it.text)) {
			set.insert(it.text);
			arr.push_back(it);
		}
	}
	return arr;
}

void parser_type::do_accept()
{
	auto prev_stage = pop_stage();
	push(std::make_shared<syntax_tree>(prev_stage.product));
	stack.front().cursor = prev_stage.cursor;
}

void parser_type::do_merge()
{
	auto prev_stage = pop_stage();
	auto &top = stack.front();
	for (auto &it : prev_stage.product.nodes)
		top.product.nodes.push_back(std::move(it));
	stack.front().cursor = prev_stage.cursor;
}

int parser_type::match_syntax(const syntax_seq &seq)
{
	for (auto &it : seq) {
		int result = match(it);
		if (result != parse_state::accept) {
			if (eof()) {
				if (lex->empty())
					error("Incomplete sentence", {0, 0});
				else
					error("Incomplete sentence", lex->back().pos);
			}
			else {
				error("Incomplete sentence", peek().pos);
			}
			return result;
		}
	}
	return parse_state::accept;
}

std::optional<int> parser_type::try_ignore()
{
	std::optional<int> cur;
	if (!on_ign && syn->count("ignore")) {
		std::string ign_key = "ign:" + std::to_string(stack.front().cursor);
		auto cache_it = ign_cache.find(ign_key);
		if (cache_it != ign_cache.end())
			return cache_it->second;
		if (ign_bootset && stack.front().cursor < static_cast<int>(lex->size()) &&
		    !ign_bootset->predict(lex->at(stack.front().cursor))) {
			ign_cache[ign_key] = std::nullopt;
			return std::nullopt;
		}
		on_ign = true;
		push_stage("ignore");
		if (match_syntax(syn->at("ignore")) == parse_state::accept) {
			auto prev_stage = pop_stage();
			cur = prev_stage.cursor;
		}
		else {
			pop_stage();
		}
		on_ign = false;
		ign_cache[ign_key] = cur;
	}
	return cur;
}

void parser_type::ignore()
{
	auto cur = try_ignore();
	if (cur.has_value())
		stack.front().cursor = cur.value();
}

int parser_type::predict(const std::shared_ptr<bootset_type> &set)
{
	if (eof()) {
		if (set && set->epsilon)
			return parse_state::accept;
		return parse_state::eof;
	}
	if (set && !set->empty()) {
		const auto *token = &peek();
		if (set->data_set.count(token->data) || set->type_set.count(token->type))
			return parse_state::accept;
		auto cur = try_ignore();
		if (cur.has_value() && cur.value() < static_cast<int>(lex->size())) {
			token = &lex->at(cur.value());
			if (set->data_set.count(token->data) || set->type_set.count(token->type))
				return parse_state::accept;
		}
		if (set->epsilon)
			return parse_state::accept;
		else
			return parse_state::reject;
	}
	else {
		return parse_state::accept;
	}
}

int parser_type::match(const syntax_t &it)
{
	switch (it->type) {
	case syntax_type::token: {
		if (eof()) {
			if (lex->empty())
				error("Early EOF, expected token <" + std::any_cast<std::string>(it->data) + ">", {0, 0});
			else
				error("Early EOF, expected token <" + std::any_cast<std::string>(it->data) + ">",
				      lex->back().pos);
			return parse_state::eof;
		}
		if (peek().type != std::any_cast<std::string>(it->data))
			ignore();
		if (eof())
			return parse_state::eof;
		if (peek().type == std::any_cast<std::string>(it->data)) {
			push_token();
			return parse_state::accept;
		}
		else {
			error("Unexpected token '" + peek().data + "', expected <" +
			      std::any_cast<std::string>(it->data) + ">",
			      peek().pos);
			return parse_state::reject;
		}
	}
	case syntax_type::term: {
		if (eof()) {
			if (lex->empty())
				error("Early EOF, expected token '" + std::any_cast<std::string>(it->data) + "'", {0, 0});
			else
				error("Early EOF, expected token '" + std::any_cast<std::string>(it->data) + "'",
				      lex->back().pos);
			return parse_state::eof;
		}
		if (peek().data != std::any_cast<std::string>(it->data))
			ignore();
		if (eof())
			return parse_state::eof;
		if (peek().data == std::any_cast<std::string>(it->data)) {
			push_token();
			return parse_state::accept;
		}
		else {
			error("Unexpected token '" + peek().data + "', expected '" +
			      std::any_cast<std::string>(it->data) + "'",
			      peek().pos);
			return parse_state::reject;
		}
	}
	case syntax_type::ref: {
		auto &name = std::any_cast<std::string &>(it->data);
		int result = predict(predict_cache.at(name));
		if (result != parse_state::accept)
			return result;
		std::string memo_key = name + ":" + std::to_string(stack.front().cursor);
		auto memo_it = memo_cache.find(memo_key);
		if (memo_it != memo_cache.end()) {
			auto &memo = memo_it->second;
			if (memo.result == parse_state::accept) {
				push(memo.product);
				stack.front().cursor = memo.cursor;
			}
			return memo.result;
		}
		push_stage(name);
		result = match_syntax(syn->at(name));
		if (result == parse_state::accept) {
			auto prev_stage = pop_stage();
			parse_memo memo_entry;
			memo_entry.result = parse_state::accept;
			memo_entry.cursor = prev_stage.cursor;
			memo_entry.product = std::make_shared<syntax_tree>(prev_stage.product);
			memo_cache[memo_key] = memo_entry;
			push(memo_entry.product);
			stack.front().cursor = prev_stage.cursor;
			return parse_state::accept;
		}
		else {
			pop_stage();
			parse_memo memo_entry;
			memo_entry.result = result;
			memo_entry.cursor = stack.front().cursor;
			memo_entry.product = nullptr;
			memo_cache[memo_key] = memo_entry;
			return result;
		}
	}
	case syntax_type::nlook: {
		int result = predict(it->boot);
		switch (result) {
		case parse_state::reject:
			return parse_state::accept;
		case parse_state::eof:
			return parse_state::eof;
		}
		push_stage("nlook");
		result = match_syntax(std::any_cast<syntax_seq &>(it->data));
		pop_stage();
		switch (result) {
		case parse_state::accept:
			return parse_state::reject;
		case parse_state::reject:
			return parse_state::accept;
		case parse_state::eof:
			return parse_state::eof;
		}
		return parse_state::reject;
	}
	case syntax_type::repeat: {
		while (true) {
			int result = predict(it->boot);
			switch (result) {
			case parse_state::reject:
				return parse_state::accept;
			case parse_state::eof:
				return parse_state::accept;
			}
			push_stage("repeat");
			result = match_syntax(std::any_cast<syntax_seq &>(it->data));
			switch (result) {
			case parse_state::accept:
				do_merge();
				break;
			case parse_state::reject:
				pop_stage();
				return parse_state::accept;
			case parse_state::eof:
				pop_stage();
				return parse_state::accept;
			}
		}
	}
	case syntax_type::opt: {
		int result = predict(it->boot);
		switch (result) {
		case parse_state::reject:
			return parse_state::accept;
		case parse_state::eof:
			return parse_state::accept;
		}
		push_stage("optional");
		result = match_syntax(std::any_cast<syntax_seq &>(it->data));
		switch (result) {
		case parse_state::accept:
			do_merge();
			return parse_state::accept;
		case parse_state::reject:
			pop_stage();
			return parse_state::accept;
		case parse_state::eof:
			pop_stage();
			return parse_state::accept;
		}
		return parse_state::reject;
	}
	case syntax_type::cond: {
		bool reaches_eof = false;
		auto &alternatives = std::any_cast<syntax_seq &>(it->data);
		for (auto &seq : alternatives) {
			int result = predict(seq->boot);
			switch (result) {
			case parse_state::reject:
				continue;
			case parse_state::eof:
				reaches_eof = true;
				continue;
			}
			push_stage("cond_or");
			result = match_syntax(std::any_cast<syntax_seq &>(seq->data));
			switch (result) {
			case parse_state::accept:
				do_merge();
				return parse_state::accept;
			case parse_state::reject:
				pop_stage();
				break;
			case parse_state::eof:
				reaches_eof = true;
				pop_stage();
				break;
			}
		}
		return reaches_eof ? parse_state::eof : parse_state::reject;
	}
	default:
		break;
	}
	return parse_state::reject;
}

std::shared_ptr<bootset_type> parser_type::prep_syntax(const syntax_seq &seq)
{
	auto set = std::make_shared<bootset_type>();
	bool insert_epsilon = true;
	bool scanning = false;
	for (auto &it : seq) {
		switch (it->type) {
		case syntax_type::term:
			insert_epsilon = false;
			if (!scanning) {
				set->data_set.insert(std::any_cast<std::string>(it->data));
				scanning = true;
			}
			break;
		case syntax_type::token:
			insert_epsilon = false;
			if (!scanning) {
				set->type_set.insert(std::any_cast<std::string>(it->data));
				scanning = true;
			}
			break;
		case syntax_type::ref:
			insert_epsilon = false;
			if (!scanning) {
				set->pending_ref.insert(std::any_cast<std::string>(it->data));
				scanning = true;
			}
			break;
		case syntax_type::nlook:
			if (!it->boot) {
				auto ret = prep_syntax(std::any_cast<syntax_seq &>(it->data));
				if (!ret->all_empty())
					it->boot = ret;
			}
			break;
		case syntax_type::cond: {
			insert_epsilon = false;
			bool scanned = scanning;
			auto &alternatives = std::any_cast<syntax_seq &>(it->data);
			for (auto &cond_p : alternatives) {
				if (!cond_p->boot) {
					auto ret = prep_syntax(std::any_cast<syntax_seq &>(cond_p->data));
					if (!ret->all_empty())
						cond_p->boot = ret;
				}
				if (!scanning && cond_p->boot) {
					set->merge(*cond_p->boot);
					scanned = true;
				}
			}
			scanning = scanned;
			break;
		}
		default:
			if (!it->boot) {
				auto ret = prep_syntax(std::any_cast<syntax_seq &>(it->data));
				if (!ret->all_empty())
					it->boot = ret;
			}
			if (!scanning && it->boot)
				set->merge(*it->boot);
			break;
		}
	}
	if (insert_epsilon)
		set->epsilon = true;
	return set;
}

bool parser_type::expand_pending_ref(std::shared_ptr<bootset_type> &boot)
{
	bool unsolved_ref = false;
	if (boot && !boot->pending_ref.empty()) {
		bootset_type pending_set;
		std::unordered_set<std::string> solved_ref;
		for (auto &ref : boot->pending_ref) {
			auto it = predict_cache.find(ref);
			if (it == predict_cache.end())
				throw std::runtime_error("Undefined grammar reference: " + ref);
			auto &set = it->second;
			if (!set->all_empty()) {
				if (set->pending_ref.empty()) {
					solved_ref.insert(ref);
					pending_set.merge(*set);
				}
				else {
					unsolved_ref = true;
				}
			}
		}
		boot->merge(pending_set);
		for (auto &ref : solved_ref)
			boot->pending_ref.erase(ref);
	}
	return !unsolved_ref;
}

void parser_type::solve_pending_ref()
{
	int pass = 0;
	bool unsolved_ref;
	do {
		++pass;
		unsolved_ref = false;
		for (auto &[name, seq] : *syn) {
			if (!expand_pending_ref(predict_cache.at(name)))
				unsolved_ref = true;
			for (auto &it : seq) {
				if (!expand_pending_ref(it->boot))
					unsolved_ref = true;
			}
		}
	} while (unsolved_ref && pass <= max_prediction_pass);
	if (pass > max_prediction_pass)
		throw std::runtime_error("Reaches max pass of prediction.");
}

void parser_type::init(const syntax_map_t &grammar)
{
	predict_cache.clear();
	syn_storage = grammar;
	syn = &syn_storage;
	for (auto &[name, seq] : *syn)
		predict_cache[name] = prep_syntax(seq);
	if (predict_cache.count("ignore"))
		ign_bootset = predict_cache.at("ignore");
	solve_pending_ref();
}

bool parser_type::parse(const token_list_t &lex_output)
{
	error_log.clear();
	stack.clear();
	max_cursor = 0;
	on_ign = false;
	memo_cache.clear();
	ign_cache.clear();
	lex = &lex_output;
	push_stage("begin");
	bool result = match_syntax(syn->at("begin")) == parse_state::accept && stack.size() == 1 && eof();
	lex = nullptr;
	return result;
}

bool parser_type::run(const syntax_map_t &grammar, const token_list_t &lex_output)
{
	init(grammar);
	return parse(lex_output);
}

std::shared_ptr<syntax_tree> parser_type::production()
{
	if (!stack.empty())
		return std::make_shared<syntax_tree>(stack.front().product);
	return nullptr;
}

// partial_parser_type

int partial_parser_type::match_syntax(const syntax_seq &seq)
{
	int begin_cur = stack.front().cursor;
	for (std::size_t idx = 0; idx < seq.size(); ++idx) {
		int result = match(seq[idx]);
		if (result != parse_state::accept) {
			if (eof()) {
				if (on_eof_hook)
					on_eof_hook(*this);
				memo_cache.clear();
				ign_cache.clear();
				stack.front().cursor = begin_cur;
				stack.front().product.nodes.clear();
				idx = static_cast<std::size_t>(-1); // loop's ++idx resets to 0
				if (eof()) {
					if (lex->empty())
						error("Incomplete sentence", {0, 0});
					else
						error("Incomplete sentence", lex->back().pos);
				}
				else {
					continue;
				}
			}
			else {
				error("Incomplete sentence", peek().pos);
			}
			return result;
		}
	}
	return parse_state::accept;
}

// recovering_parser_type

recovering_parser_type::recovering_parser_type()
{
	sync_types.insert("endl");
}

int recovering_parser_type::find_sync_after(int pos)
{
	int i = pos;
	while (i < static_cast<int>(lex->size())) {
		if (sync_types.count(lex->at(i).type) || lex->at(i).data == ";")
			return i + 1;
		++i;
	}
	return static_cast<int>(lex->size());
}

bool recovering_parser_type::parse_with_recovery(const token_list_t &lex_output)
{
	all_errors.clear();
	int start = 0;
	int max_retries = 100;
	int retries = 0;
	while (start < static_cast<int>(lex_output.size()) && retries < max_retries) {
		error_log.clear();
		stack.clear();
		max_cursor = 0;
		on_ign = false;
		memo_cache.clear();
		ign_cache.clear();
		lex = &lex_output;
		push_stage("begin");
		stack.front().cursor = start;
		if (parser_type::match_syntax(syn->at("begin")) == parse_state::accept && stack.size() == 1 && eof()) {
			lex = nullptr;
			return true;
		}
		auto err = get_log(0);
		if (!err.empty())
			all_errors.push_back(err[0]);
		int next = find_sync_after(max_cursor);
		if (next <= start)
			next = start + 1;
		start = next;
		++retries;
	}
	lex = nullptr;
	return all_errors.empty();
}

} // namespace pg
