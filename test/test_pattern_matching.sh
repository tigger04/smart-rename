#!/usr/bin/env bash
# ABOUTME: Test pattern matching functionality directly
# ABOUTME: Validates that smart-rename finds files correctly with various patterns

set -e

# Test configuration
TEST_DIR="/tmp/claude/pattern-test-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test counter
TESTS=0
PASSED=0
FAILED=0

test_start() {
    TESTS=$((TESTS + 1))
    echo -n "Testing: $1... "
}

test_pass() {
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}✓${NC}"
}

test_fail() {
    FAILED=$((FAILED + 1))
    echo -e "${RED}✗${NC}"
    echo "  Error: $1"
    return 1
}

# Cleanup function
cleanup() {
    if [[ -n "$TEST_DIR" && "$TEST_DIR" =~ ^/tmp/claude/pattern-test- ]]; then
        trash "$TEST_DIR" 2>/dev/null || rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

# Create test environment
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create test files
touch "scan-doc.txt" "document-scan.pdf" "other-file.txt" "scan.jpg" "noscanhere.doc"

echo "Created test files in $TEST_DIR:"
ls -la

# Test 1: Pattern matching finds files
test_start "fd finds scan files directly"
FOUND_FILES=$(fd scan --type f)
if [[ -n "$FOUND_FILES" ]]; then
    test_pass
    echo "  Found: $FOUND_FILES"
else
    test_fail "fd scan --type f found no files"
fi

# Test 2: smart-rename with clean environment
test_start "smart-rename finds scan files with clean environment"
export HOME="$TEST_DIR"
mkdir -p "$TEST_DIR/.config/smart-rename"

# Create minimal config to avoid API calls
cat > "$TEST_DIR/.config/smart-rename/config.yaml" <<EOF
api:
  openai:
    # key: ""
    model: "gpt-4o-mini"
  claude:
    # key: ""
    model: "claude-3-5-sonnet-20241022"
  ollama:
    url: "http://localhost:11434"
    model: "mistral"
default_provider: ""
prompts:
  rename: "test prompt"
currency:
  base: "EUR"
abbreviations: {}
EOF

# Test with timeout and capture both stdout and stderr
OUTPUT=$(timeout 10 env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY smart-rename --dry-run scan 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    test_pass
    echo "  Output: $OUTPUT"
elif [[ $EXIT_CODE -eq 124 ]]; then
    test_fail "Timed out - possible hang"
else
    test_fail "Exit code $EXIT_CODE, Output: $OUTPUT"
fi

# Test 3: Check for proper error message with non-matching pattern
test_start "smart-rename gives proper error for non-matching pattern"
OUTPUT=$(timeout 5 env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY smart-rename --dry-run nonexistentpattern123 2>&1)
EXIT_CODE=$?

if echo "$OUTPUT" | grep -q "No files found matching"; then
    test_pass
else
    test_fail "Expected 'No files found matching' message, got: $OUTPUT"
fi

# Summary
echo
echo "================================="
echo "Pattern Matching Test Results:"
echo "Tests run: $TESTS"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "================================="

if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi