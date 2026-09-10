#!/usr/bin/env bash
# Format all C++ source files in the parsergen C++ project.
# Requires astyle:  https://astyle.sourceforge.net/
# Options:  -A4  attach braces to the end of lines (Linux/Java style)
#           -t   use tabs for indentation
#           -n   do not create .orig backup files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")/cpp"

if ! command -v astyle &> /dev/null; then
    echo "error: astyle not found. Install it from https://astyle.sourceforge.net/"
    exit 1
fi

echo "Formatting C++ sources..."

find "$PROJECT_ROOT" \
    -name covscript-regex -prune -o \
    -name utfcpp -prune -o \
    -name build -prune -o \
    -name cni -prune -o \
    \( -name '*.cpp' -o -name '*.hpp' \) -print0 \
    | xargs -0 astyle -A4 -t -n

echo "Done."
