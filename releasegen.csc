import regex

@begin
var header =
"# Release Date: " + to_string(runtime.local_time()) +
"# Copyright (C) 2017-2023 Michael Lee(李登淳)\n" +
"# Github:  https://github.com/mikecovlee\n"
@end

var ignore = regex.build("^\\s*(#.*)?$")
var pkg_rename = regex.build("^package\\s+parsergen_debug\\s*$")
var ign_next  = regex.build("^\\s*#\\%debug\\s*$")
var beg_block = regex.build("^\\s*#\\~debug\\s*$")
var end_block = regex.build("^\\s*#\\!debug\\s*$")

var ifs = iostream.ifstream("./parsergen_debug.csp")
var ofs = iostream.ofstream("./parsergen.csp")

var in_block = false
var ign_once = false

ofs.println(ifs.getline() + " Release")
ofs.println(header)

while ifs.good() && !ifs.eof()
    var line = ifs.getline()
    if ign_once
        ign_once = false
        continue
    end
    if !in_block
        if pkg_rename.match(line).size() > 0
            ofs.println("package parsergen")
            continue
        end
        if ign_next.match(line).size() > 0
            # system.out.println("IGN Once")
            ign_once = true
            continue
        end
        if beg_block.match(line).size() > 0
            # system.out.println("IGN Begin")
            in_block = true
            continue
        end
        if ignore.match(line).size() > 0
            continue
        end
        ofs.println(line)
    else
        if end_block.match(line).size() > 0
            # system.out.println("IGN End")
            in_block = false
            continue
        end
    end
end