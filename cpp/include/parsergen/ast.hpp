#pragma once
#include <parsergen/token.hpp>

#include <iostream>
#include <memory>
#include <string>
#include <variant>
#include <vector>

namespace pg {

struct syntax_tree;

using ast_node = std::variant<token_type, std::shared_ptr<syntax_tree>>;

struct syntax_tree {
	std::string root;
	std::vector<ast_node> nodes;
};

inline void print_ast_impl(const std::string &indent, const std::shared_ptr<syntax_tree> &tree)
{
	if (!tree)
		return;
	for (auto &it : tree->nodes) {
		if (auto *sub = std::get_if<std::shared_ptr<syntax_tree>>(&it)) {
			std::cout << indent << "(" << (*sub)->root << "\n";
			print_ast_impl(indent + "  ", *sub);
			std::cout << indent << ")\n";
		}
		else if (auto *tok = std::get_if<token_type>(&it)) {
			std::cout << indent << "[" << tok->type << " " << tok->data << "]\n";
		}
	}
}

inline void print_ast(const std::shared_ptr<syntax_tree> &tree)
{
	print_ast_impl("", tree);
}

} // namespace pg
