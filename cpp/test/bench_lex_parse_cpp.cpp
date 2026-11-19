#include "ecs_parser.hpp"

#include <chrono>
#include <fstream>
#include <iostream>
#include <sstream>

int main(int argc, char *argv[])
{
	if (argc < 2) {
		std::cerr << "Usage: " << argv[0] << " <file>\n";
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
	int rounds = 3;

	double lex_total = 0, parse_total = 0;

	for (int i = 0; i < rounds; ++i) {
		pg::lexer_type lexer;
		auto t0 = std::chrono::high_resolution_clock::now();
		auto tokens = lexer.run(gram.lex, input);
		auto t1 = std::chrono::high_resolution_clock::now();
		lex_total += std::chrono::duration<double, std::milli>(t1 - t0).count();

		pg::parser_type parser;
		auto t2 = std::chrono::high_resolution_clock::now();
		parser.run(gram.stx, tokens);
		auto t3 = std::chrono::high_resolution_clock::now();
		parse_total += std::chrono::duration<double, std::milli>(t3 - t2).count();
	}

	double lex_avg = lex_total / rounds;
	double parse_avg = parse_total / rounds;
	double total = lex_avg + parse_avg;

	std::cout << "File: " << argv[1] << "\n";
	std::cout << "Rounds: " << rounds << "\n";
	std::cout << "Lex:   " << lex_avg << " ms (" << (lex_avg * 100.0 / total) << "%)\n";
	std::cout << "Parse: " << parse_avg << " ms (" << (parse_avg * 100.0 / total) << "%)\n";
	std::cout << "Total: " << total << " ms\n";

	return 0;
}
