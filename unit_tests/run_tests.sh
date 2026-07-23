#!/bin/bash
IMPORT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

echo "=============================="
echo " ParserGen Unit Tests"
echo "=============================="
echo ""

# Pre-generate parsers for codegen test
echo "--- Generate parsers ---"
output=$(cs --import-path "${IMPORT_PATH}" "${IMPORT_PATH}/misc/test_codegen_full.csc" 2>&1)
echo "$output"
output=$(cs --import-path "${IMPORT_PATH}" "${IMPORT_PATH}/misc/test_codegen_core.csc" 2>&1)
echo "$output"
echo ""

for test in "$(dirname "$0")"/test_*.csc; do
    echo "--- $(basename "$test") ---"
    output=$(cs --import-path "${IMPORT_PATH}" "$test" 2>&1)
    echo "$output"
    if echo "$output" | grep -q "Failed: 0"; then
        echo ""
    else
        FAILED=1
        echo ""
    fi
done

echo "=============================="
if [ $FAILED -eq 0 ]; then
    echo " ALL TESTS PASSED"
else
    echo " SOME TESTS FAILED"
fi
echo "=============================="
exit $FAILED
