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

inline void print_ast_impl(int indent, const std::shared_ptr<syntax_tree> &tree)
{
	if (!tree)
		return;
	std::cout << tree->root << "\n";
	for (auto &it : tree->nodes) {
		for (int i = 0; i < indent + 2; ++i)
			std::cout << ' ';
		std::cout << tree->root << " -> ";
		if (auto *tok = std::get_if<token_type>(&it)) {
			std::cout << "\"" << tok->data << "\"\n";
		}
		else if (auto *sub = std::get_if<std::shared_ptr<syntax_tree>>(&it)) {
			print_ast_impl(indent + 2, *sub);
		}
	}
}

inline void print_ast(const std::shared_ptr<syntax_tree> &tree)
{
	print_ast_impl(0, tree);
}

} // namespace pg
