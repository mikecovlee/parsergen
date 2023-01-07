@charset: gbk

import parsergen, unicode

constant syntax = parsergen.syntax

var cvt = new unicode.codecvt.gbk

@begin
var losu_lexical = {
    # GBK
    "zh_id"  : unicode.build_wregex(cvt.local2wide("^[\\uB0A1-\\uF7FE\\u8140-\\uA0FE\\uAA40-\\uFEA0\\uA996]+$")),
    # UTF8
    #"zh_id"  : unicode.build_wregex(cvt.local2wide("^[\\u4E00-\\u9FA5\\u9FA6-\\u9FEF\\u3007]+$")),
    "id"  : unicode.build_wregex(cvt.local2wide("^[A-Za-z_]\\w*$")),
    "num" : unicode.build_wregex(cvt.local2wide("^[0-9]+\\.?([0-9]+)?$")),
    "str" : unicode.build_wregex(cvt.local2wide("^(\"|\"([^\"]|\\\\\")*\"?)$")),
    "sig" : unicode.build_wregex(cvt.local2wide("^(#|\\+|/|-|\\*|<|<=|>|>=|=|!=?|==|&|;|,|\\(|\\)|\\[|\\]|\\{|\\})$")),
    "ign" : unicode.build_wregex(cvt.local2wide("^(\\s+|//?.*|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$")),
    "err" : unicode.build_wregex(cvt.local2wide("^(!|/)$"))
}.to_hash_map()
@end

var ifs = iostream.ifstream(context.cmd_args[1])
var input = new string
var code_buff = new array
while ifs.good() && !ifs.eof()
    var line = ifs.getline()
    input += line + "\n"
    for i = 0, i < line.size, ++i
        if line[i] == '\t'
            line.assign(i, ' ')
        end
    end
    code_buff.push_back(line)
end
var lexer = new parsergen.unicode_lexer_type
lexer.cvt = cvt
var token_buff = lexer.run(losu_lexical, input)
if !lexer.error_log.empty()
    parsergen.print_header("Compilation Error")
    parsergen.print_error(context.cmd_args[1], code_buff, lexer.error_log)
    system.exit(0)
end
parsergen.print_header("Lexer Output")
var max_align = to_string(token_buff.size).size
foreach i in range(token_buff.size)
    link it = token_buff[i]
    var align = max_align - to_string(i).size
    system.out.print("CP = " + i)
    foreach x in range(align) do system.out.print(' ')
    system.out.println("  Type = " + it.type + "\tData = " + it.data + "\tPos = (" + it.pos[0] + ", " + it.pos[1] + ")")
end