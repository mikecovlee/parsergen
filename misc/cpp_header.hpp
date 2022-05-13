#pragma once
#include <vector>
#include <stack>
#include <string>
#include <utility>

namespace parsergen
{
    using size_t = std::size_t;
    struct token_type
    {
        size_t pos[2] = {0, 0};
        std::size_t type = 0;
        std::string data;
    };
    enum class parse_state
    {
        accept, reject, eof
    };
    class parser_type
    {
        std::stack<std::string> parsing_stack;
        
        bool parse(const std::vector<token_type> input)
        {
            for (auto &token : input)
            {

            }
        }
    };
}