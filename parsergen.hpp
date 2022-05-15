#pragma once
#include <unordered_map>
#include <stdexcept>
#include <vector>
#include <stack>
#include <string>
#include <utility>

#define parsergen_log(msg)

namespace parsergen {
	struct token_type final {
		std::size_t pos[2] = {0, 0};
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
	};
	enum class parse_state {
		accept, reject, eof, null
	};
	struct parse_stage final {
		syntax_tree production;
		std::size_t cursor = 0;
		parse_stage() = delete;
		parse_stage(std::string tag, std::size_t cur) : production(std::move(tag)), cursor(cur) {}
	};
	struct parse_error final {
		std::size_t pos[2] = {0, 0};
		std::size_t cursor = 0;
		std::string text;
	};
	class parser_type {
	protected:
		// Error Handling
		std::vector<parse_error> error_log;
		std::size_t max_cursor = 0;
		// Parsing
		std::stack<parse_stage> parsing_stack;
		std::vector<token_type> input;
		size_t cursor_pos = 0;
	public:
		parser_type() = default;
		virtual ~parser_type() = default;
		virtual parse_state match_begin() = 0;
		inline const token_type& peek() const
		{
			return input[cursor_pos + 1];
		}
		inline const token_type& get() const
		{
			return input[cursor_pos];
		}
		inline bool eof() const
		{
			return cursor_pos >= input.size() - 1;
		}
		void push_stage(const std::string& name)
		{

		}
		void pop_stage()
		{

		}
		void accept()
		{

		}
		void merge()
		{

		}
		virtual void ignore() {}
		inline parse_state match_token(const std::string& value)
		{

		}
		inline parse_state match_term(const std::string& value)
		{

		}
	};
	class parser_with_ign : public parser_type {
		bool on_ign = false;
	public:
		virtual parse_state match_ignore() = 0;
		void ignore() override
		{
			if (!on_ign) {
				on_ign = true;
				if (match_ignore() == parse_state::accept) {
					std::size_t cursor = this->parsing_stack.top().cursor;
					pop_stage();
					this->parsing_stack.top().cursor = cursor;
				}
				else
					pop_stage();
				on_ign = false;
			}
		}
	};
}