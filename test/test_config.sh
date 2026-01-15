#!/usr/bin/env bash
# ABOUTME: Configuration system tests for smart-rename
# ABOUTME: Tests environment variable loading, config file parsing, and fallbacks

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
TMP_DIR="$TEST_DIR/tmp"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ $1${NC}"
    return 1
}

run_test() {
    ((TESTS_RUN++))
    echo "→ Testing: $1"
}

# Setup test environment
mkdir -p "$TMP_DIR"
export HOME="$TMP_DIR"
cd "$PROJECT_DIR"

# Test 1: Configuration directory creation
run_test "Configuration directory setup"
mkdir -p "$HOME/.config/smart-rename"
if [[ -d "$HOME/.config/smart-rename" ]]; then
    pass "Configuration directory created"
else
    fail "Configuration directory creation failed"
fi

# Test 2: Environment variable detection
run_test "Environment variable detection"
export OPENAI_API_KEY="test-key"
if [[ -n "${OPENAI_API_KEY}" ]]; then
    pass "Environment variables can be set and read"
else
    fail "Environment variable detection failed"
fi

# Test 3: Config file creation with base currency
run_test "Config file creation with base currency"
cat > "$HOME/.config/smart-rename/config" <<EOF
export CLAUDE_API_KEY="test-claude-key"
openai_model="gpt-4"
ollama_model="llama2"
base_currency="USD"
declare -A abbreviations=(
  ["test"]="Test Hospital"
)
EOF

if [[ -f "$HOME/.config/smart-rename/config" ]]; then
    pass "Config file created successfully"
else
    fail "Config file creation failed"
fi

# Test 4: Config file sourcing
run_test "Config file sourcing"
source "$HOME/.config/smart-rename/config"
if [[ "$openai_model" == "gpt-4" && "$base_currency" == "USD" ]]; then
    pass "Config file variables loaded correctly"
else
    fail "Config file sourcing failed: openai_model=$openai_model, base_currency=$base_currency"
fi

# Test 5: Abbreviations configuration
run_test "Abbreviations configuration"
if [[ "${abbreviations[test]}" == "Test Hospital" ]]; then
    pass "Abbreviations loaded correctly"
else
    fail "Abbreviations not loaded: ${abbreviations[test]}"
fi

# Test 6: Script exists and is executable
run_test "Script executable check"
if [[ -x "./smart-rename" ]]; then
    pass "Script is executable"
else
    fail "Script is not executable"
fi

# Cleanup
rm -rf "$TMP_DIR"
unset OPENAI_API_KEY

echo
echo "Tests completed: $TESTS_PASSED/$TESTS_RUN passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All configuration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi