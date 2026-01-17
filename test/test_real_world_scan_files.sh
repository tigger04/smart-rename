#!/usr/bin/env bash
# ABOUTME: Test that smart-rename actually works with real-world pattern matching
# ABOUTME: This test would have caught the "scan" pattern matching bug

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/smart-rename"
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Testing real-world pattern matching..."
cd "$TEST_DIR"

# Create scan files like user had
for i in {1..5}; do
    echo "Scan document number $i content" > "scan$i.pdf"
done

echo "Created test files:"
ls -la scan*.pdf

# Test 1: Pattern should find files, not try to read "scan" as a file
echo -e "\nTest 1: Pattern 'scan' should find scan* files"
OUTPUT=$("$SCRIPT" scan 2>&1 | head -5 || true)

if echo "$OUTPUT" | grep -q "Error reading file: scan"; then
    echo "❌ FAILED: Script tried to read 'scan' as a file instead of pattern"
    echo "Output: $OUTPUT"
    exit 1
elif echo "$OUTPUT" | grep -q "Found.*files"; then
    echo "✅ PASSED: Script correctly found files matching pattern"
else
    echo "❌ FAILED: Unexpected output"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 2: Should work with glob pattern
echo -e "\nTest 2: Glob pattern should work"
OUTPUT=$("$SCRIPT" -g "scan*.pdf" 2>&1 | head -5 || true)

if echo "$OUTPUT" | grep -q "Found.*files"; then
    echo "✅ PASSED: Glob pattern works"
else
    echo "❌ FAILED: Glob pattern didn't find files"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 3: Should handle regex properly
echo -e "\nTest 3: Regex pattern"
OUTPUT=$("$SCRIPT" 'scan[0-9]+\.pdf' 2>&1 | head -5 || true)

if echo "$OUTPUT" | grep -q "Found.*files"; then
    echo "✅ PASSED: Regex pattern works"
else
    echo "❌ FAILED: Regex pattern didn't find files"
    echo "Output: $OUTPUT"
    exit 1
fi

echo -e "\n✅ All real-world pattern tests passed!"