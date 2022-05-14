#pragma once
#include <unordered_map>
#include <vector>
#include <stack>
#include <string>
#include <utility>

#define parsergen_log(msg)

namespace parsergen
{
    struct symbol_table_t
    {
        std::unordered_map<std::size_t, std::string> token_type2sym;
        std::unordered_map<std::string, std::size_t> token_sym2type;
    };
    struct token_t
    {
        std::size_t pos[2] = {0, 0};
        std::string type;
        std::string data;
    };
    enum class parse_state
    {
        accept, reject, eof, null
    };
    class parser_t
    {
        const symbol_table_t* sym_table = nullptr;
        std::stack<std::string> parsing_stack;
        std::vector<token_t> input;
        size_t cursor_pos = 0;
    public:
        inline const token_t& peek() const
        {
            return input[cursor_pos + 1];
        }
        inline const token_t& get() const
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
        virtual parse_state match_begin() = 0;

        virtual void ignore() {}

        inline parse_state match_token(const std::string& value)
        {

        }

        inline parse_state match_term(const std::string& value)
        {
            
        }
    };
}