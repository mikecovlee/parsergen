#pragma once
#include <unordered_map>
#include <unordered_set>
#include <stdexcept>
#include <vector>
#include <stack>
#include <string>
#include <utility>
#include <array>

namespace parsergen {
	struct token_type final {
		std::array<std::size_t, 2> pos = {0, 0};
		std::string type;
		std::string data;
	};
	class syntax_tree final {
		struct node_index {
			std::size_t actual_idx = 0;
			bool is_child = false;
			node_index() = default;
			node_index(std::size_t idx, bool child) : actual_idx(idx), is_child(child) {}
		};
		std::vector<token_type> token_nodes;
		std::vector<syntax_tree> child_nodes;
		std::vector<node_index> node_idxs;
	public:
		std::string root_tag = "DEFAULT_PARSERGEN_ROOT_TAG";
		syntax_tree() = default;
		explicit syntax_tree(std::string tag) : root_tag(std::move(tag)) {}
		syntax_tree(const syntax_tree&) = default;
		syntax_tree(syntax_tree &&) noexcept = default;
		~syntax_tree() = default;
		syntax_tree &operator=(const syntax_tree &) = default;
		void add_node(token_type token)
		{
			token_nodes.emplace_back(std::move(token));
			node_idxs.emplace_back(token_nodes.size() - 1, false);
		}
		void add_node(syntax_tree tree)
		{
			child_nodes.emplace_back(std::move(tree));
			node_idxs.emplace_back(child_nodes.size() - 1, true);
		}
		token_type &get_token(std::size_t idx)
		{
			if (idx >= node_idxs.size())
				throw std::out_of_range("parsergen::syntax_tree::get_token");
			if (node_idxs[idx].is_child)
				throw std::runtime_error("get child node in parsergen::syntax_tree::get_token");
			return token_nodes[node_idxs[idx].actual_idx];
		}
		const token_type &get_token(std::size_t idx) const
		{
			if (idx >= node_idxs.size())
				throw std::out_of_range("parsergen::syntax_tree::get_token");
			if (node_idxs[idx].is_child)
				throw std::runtime_error("get child node in parsergen::syntax_tree::get_token");
			return token_nodes[node_idxs[idx].actual_idx];
		}
		syntax_tree &get_tree(std::size_t idx)
		{
			if (idx >= node_idxs.size())
				throw std::out_of_range("parsergen::syntax_tree::get_tree");
			if (!node_idxs[idx].is_child)
				throw std::runtime_error("get token node in parsergen::syntax_tree::get_tree");
			return child_nodes[node_idxs[idx].actual_idx];
		}
		const syntax_tree &get_tree(std::size_t idx) const
		{
			if (idx >= node_idxs.size())
				throw std::out_of_range("parsergen::syntax_tree::get_tree");
			if (!node_idxs[idx].is_child)
				throw std::runtime_error("get token node in parsergen::syntax_tree::get_tree");
			return child_nodes[node_idxs[idx].actual_idx];
		}
		bool is_child(std::size_t idx) const
		{
			if (idx >= node_idxs.size())
				throw std::out_of_range("parsergen::syntax_tree::is_child");
			return node_idxs[idx].is_child;
		}
		inline std::size_t size() const
		{
			return node_idxs.size();
		}
		inline bool empty() const
		{
			return node_idxs.empty();
		}
		void merge(const syntax_tree& tree)
		{
			if (&tree != this) {
				for (std::size_t i = 0; i < tree.size(); ++i) {
					if (tree.is_child(i))
						add_node(tree.get_tree(i));
					else
						add_node(tree.get_token(i));
				}
			}
		}
	};
	enum class parse_state {
		accept, reject, eof
	};
	struct parse_stage final {
		syntax_tree production;
		std::size_t cursor = 0;
		parse_stage() = delete;
		parse_stage(std::string tag, std::size_t cur) : production(std::move(tag)), cursor(cur) {}
	};
	struct parse_error final {
		std::array<std::size_t, 2> pos = {0, 0};
		std::size_t cursor = 0;
		std::string text;
		parse_error() = default;
		parse_error(std::array<std::size_t, 2> p, std::size_t c, std::string txt) : cursor(c), text(std::move(txt)) {}
	};
	class parser_type {
	protected:
		// Error Handling
		std::vector<parse_error> error_log;
		std::size_t max_cursor = 0;
		// Parsing
		std::stack<parse_stage> parsing_stack;
		std::vector<token_type> input;
	public:
		parser_type() = default;
		virtual ~parser_type() = default;
		virtual parse_state match_begin() = 0;
		void push_stage(const std::string& name)
		{
			std::size_t prev_cursor = 0;
			if (!parsing_stack.empty())
				prev_cursor = parsing_stack.top().cursor;
			parsing_stack.emplace(name, prev_cursor);
		}
		void pop_stage()
		{
			parsing_stack.pop();
		}
		template<typename T>
		void push(T&& val)
		{
			parsing_stack.top().production.add_node(std::forward<T>(val));
		}
		void push_token()
		{
			auto &top = parsing_stack.top();
			top.production.add_node(input[top.cursor++]);
		}
		inline std::size_t cursor() const
		{
			return parsing_stack.top().cursor;
		}
		inline const token_type& peek() const
		{
			return input[cursor() + 1];
		}
		inline const token_type& get() const
		{
			return input[cursor()];
		}
		inline bool eof() const
		{
			return cursor() >= input.size() - 1;
		}
		void error(std::string msg, std::array<std::size_t, 2> pos)
		{
			std::size_t current = cursor();
			if (current > max_cursor)
				max_cursor = current;
			error_log.emplace_back(pos, current, msg);
		}
		std::vector<parse_error> get_error_log(std::size_t n = 0)
		{
			std::unordered_set<std::string> set;
			std::vector<parse_error> arr;
			for (auto &it : error_log) {
				if (it.cursor >= max_cursor - n && set.count(it.text) == 0) {
					set.insert(it.text);
					arr.emplace_back(it);
				}
			}
			return move(arr);
		}
		void accept()
		{
			parse_stage prev_stage = std::move(parsing_stack.top());
			parsing_stack.pop();
			push(prev_stage.production);
			parsing_stack.top().cursor = prev_stage.cursor;
		}
		void merge()
		{
			parse_stage prev_stage = std::move(parsing_stack.top());
			parsing_stack.pop();
			parsing_stack.top().production.merge(prev_stage.production);
			parsing_stack.top().cursor = prev_stage.cursor;
		}
		virtual parse_state ignore()
		{
			return eof() ? parse_state::eof : parse_state::accept;
		}
		inline parse_state match_token(const std::string& value)
		{
			if (eof()) {
				error("Early EOF", input.back().pos);
				return parse_state::eof;
			}
			if (peek().type != value && ignore() == parse_state::eof) {
				error("Early EOF", input.back().pos);
				return parse_state::eof;
			}
			if (peek().type == value) {
				push_token();
				return parse_state::accept;
			}
			else {
				error("Unexpected Token", peek().pos);
				return parse_state::reject;
			}
		}
		inline parse_state match_term(const std::string& value)
		{
			if (eof()) {
				error("Early EOF", input.back().pos);
				return parse_state::eof;
			}
			if (peek().data != value && ignore() == parse_state::eof) {
				error("Early EOF", input.back().pos);
				return parse_state::eof;
			}
			if (peek().data == value) {
				push_token();
				return parse_state::accept;
			}
			else {
				error("Unexpected Token", peek().pos);
				return parse_state::reject;
			}
		}
	};
	class parser_with_ign : public parser_type {
		bool on_ign = false;
	public:
		virtual parse_state match_ignore() = 0;
		parse_state ignore() override
		{
			if (!on_ign) {
				on_ign = true;
				parse_state state = match_ignore();
				if (state == parse_state::accept) {
					std::size_t cursor = this->parsing_stack.top().cursor;
					pop_stage();
					this->parsing_stack.top().cursor = cursor;
				}
				else
					pop_stage();
				on_ign = false;
				return state;
			}
			else
				return eof() ? parse_state::eof : parse_state::accept;
		}
	};
}