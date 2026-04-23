#!/bin/bash
set -euo pipefail

BIN=.build/debug/MacDjVuPackageTests.xctest/Contents/MacOS/MacDjVuPackageTests
PROF=.build/debug/codecov/default.profdata

report=$(xcrun llvm-cov report "$BIN" \
    --instr-profile "$PROF" \
    --ignore-filename-regex='Tests/')

# Parse the TOTAL line: "TOTAL  ...  65.85%  ..."
# Line coverage is the 10th field.
total=$(echo "$report" | awk '/^TOTAL/{print $10}')

echo "## Test coverage: ${total}"
echo ""
echo '```'
echo "$report"
echo '```'
