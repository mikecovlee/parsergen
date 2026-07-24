#include "ecs_parser.hpp"

#include <fstream>
#include <iostream>
#include <sstream>

static void dump_ast(const std::shared_ptr<pg::syntax_tree> &tree, const std::string &indent)
{
	if (!tree)
		return;
	for (auto &node : tree->nodes) {
		if (auto *sub = std::get_if<std::shared_ptr<pg::syntax_tree>>(&node)) {
			std::cout << indent << "(" << (*sub)->root << "\n";
			dump_ast(*sub, indent + "  ");
			std::cout << indent << ")\n";
		}
		else if (auto *tok = std::get_if<pg::token_type>(&node)) {
			std::cout << indent << "[" << tok->type << " " << tok->data << "]\n";
		}
	}
}

int main(int argc, char *argv[])
{
	if (argc < 2) {
		std::cerr << "Usage: " << argv[0] << " <file.ecs>\n";
		return 1;
	}

	std::ifstream ifs(argv[1]);
	if (!ifs.good()) {
		std::cerr << "Cannot open file: " << argv[1] << "\n";
		return 1;
	}
	std::stringstream ss;
	ss << ifs.rdbuf();
	std::string input = ss.str();
	if (!input.empty() && input.back() != '\n')
		input += '\n';

	auto gram = ecs_parser::make_grammar();

	pg::generator gen;
	gen.show_prompt = false;
	gen.stop_on_error = true;
	gen.add_grammar("ecs-lang", std::move(gram));

	if (gen.from_string("ecs-lang", input)) {
		std::cout << "PARSE OK\n";
		dump_ast(gen.ast(), "");
	}
	else {
		std::cout << "PARSE FAIL\n";
		for (auto &e : gen.get_errors())
			std::cout << "  Line " << (e.pos[1] + 1) << ": " << e.text << "\n";
	}

	return 0;
}
