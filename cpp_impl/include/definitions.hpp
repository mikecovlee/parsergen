#pragma once
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
}