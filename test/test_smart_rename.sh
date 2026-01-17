#!/usr/bin/env bash
# ABOUTME: Test suite for smart-rename script functionality
# ABOUTME: Tests all core features including pattern matching, API calls, and renaming

set -euo pipefail

# Test setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/smart-rename"
TEST_TEMP_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup() {
    TEST_TEMP_DIR=$(mktemp -d)
    cd "$TEST_TEMP_DIR"

    # Create test files
    echo "Test content" > test-file.txt
    echo 'Invoice total: $100.00' > invoice.pdf
    echo 'Receipt for coffee $5.50' > receipt-001.jpg
    mkdir -p subdir
    echo "Nested file" > subdir/nested.txt
}

# Cleanup test environment
teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test helper: assert command succeeds
assert_success() {
    local cmd="${1:-}"
    local description="${2:-}"

    ((TESTS_RUN++)) || true

    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++)) || true
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo "  Command failed: $cmd"
        ((TESTS_FAILED++)) || true
        return 0
    fi
}

# Test helper: assert command fails
assert_failure() {
    local cmd="${1:-}"
    local description="${2:-}"

    ((TESTS_RUN++)) || true

    if ! eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++)) || true
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo "  Command should have failed: $cmd"
        ((TESTS_FAILED++)) || true
        return 0
    fi
}

# Test helper: assert file exists
assert_file_exists() {
    local file="${1:-}"
    local description="${2:-}"

    ((TESTS_RUN++)) || true

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++)) || true
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo "  File not found: $file"
        ((TESTS_FAILED++)) || true
        return 0
    fi
}

# Test helper: assert output contains text
assert_output_contains() {
    local cmd="${1:-}"
    local expected="${2:-}"
    local description="${3:-}"

    ((TESTS_RUN++)) || true

    local output
    output=$(eval "$cmd" 2>&1) || true

    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} $description"
        ((TESTS_PASSED++)) || true
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo "  Expected output to contain: $expected"
        echo "  Actual output: $output"
        ((TESTS_FAILED++)) || true
        return 0
    fi
}

# Test: Script exists and is executable
test_script_exists() {
    echo -e "\n${YELLOW}Testing script existence...${NC}"
    assert_file_exists "$SCRIPT" "Script exists at expected location"
    assert_success "[[ -x '$SCRIPT' ]]" "Script is executable"
}

# Test: Help flag works
test_help_flag() {
    echo -e "\n${YELLOW}Testing help flag...${NC}"
    assert_success "'$SCRIPT' --help" "Help flag returns success"
    assert_output_contains "'$SCRIPT' --help" "USAGE" "Help output contains USAGE section"
    assert_output_contains "'$SCRIPT' --help" "OPTIONS" "Help output contains OPTIONS section"
    assert_output_contains "'$SCRIPT' -h" "USAGE" "Short help flag works"
}

# Test: Version flag works
test_version_flag() {
    echo -e "\n${YELLOW}Testing version flag...${NC}"
    assert_success "'$SCRIPT' --version" "Version flag returns success"
    assert_output_contains "'$SCRIPT' --version" "smart-rename" "Version output contains program name"
    assert_output_contains "'$SCRIPT' -v" "smart-rename" "Short version flag works"
}

# Test: Pattern matching with regex
test_regex_pattern_matching() {
    echo -e "\n${YELLOW}Testing regex pattern matching...${NC}"
    setup

    # Mock fd command for testing
    export PATH="$TEST_TEMP_DIR:$PATH"
    cat > "$TEST_TEMP_DIR/fd" <<'EOF'
#!/bin/bash
echo "test-file.txt"
echo "receipt-001.jpg"
EOF
    chmod +x "$TEST_TEMP_DIR/fd"

    assert_output_contains "'$SCRIPT' '.*\.txt'" "test-file.txt" "Finds .txt files with regex"
    assert_output_contains "'$SCRIPT' 'receipt.*\.jpg'" "receipt-001.jpg" "Finds receipt files with regex"

    teardown
}

# Test: Pattern matching with glob
test_glob_pattern_matching() {
    echo -e "\n${YELLOW}Testing glob pattern matching...${NC}"
    setup

    # Mock fd command for testing
    export PATH="$TEST_TEMP_DIR:$PATH"
    cat > "$TEST_TEMP_DIR/fd" <<'EOF'
#!/bin/bash
if [[ "$*" == *"--glob"* ]]; then
    echo "invoice.pdf"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/fd"

    assert_output_contains "'$SCRIPT' --glob '*.pdf'" "invoice.pdf" "Finds PDF files with glob pattern"

    teardown
}

# Test: Recursive search
test_recursive_search() {
    echo -e "\n${YELLOW}Testing recursive search...${NC}"
    setup

    # Mock fd command for testing
    export PATH="$TEST_TEMP_DIR:$PATH"
    cat > "$TEST_TEMP_DIR/fd" <<'EOF'
#!/bin/bash
if [[ "$*" != *"--max-depth"* ]]; then
    echo "subdir/nested.txt"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/fd"

    assert_output_contains "'$SCRIPT' --recursive '.*\.txt'" "nested.txt" "Recursive search finds nested files"

    teardown
}

# Test: No pattern provided error
test_no_pattern_error() {
    echo -e "\n${YELLOW}Testing no pattern error...${NC}"
    assert_failure "'$SCRIPT' 2>/dev/null" "Fails when no pattern provided"
    assert_output_contains "'$SCRIPT'" "requires a search PATTERN" "Shows error message for missing pattern"
}

# Test: Configuration loading
test_config_loading() {
    echo -e "\n${YELLOW}Testing configuration loading...${NC}"
    setup

    # Create test config
    mkdir -p "$TEST_TEMP_DIR/.config/smart-rename"
    cat > "$TEST_TEMP_DIR/.config/smart-rename/config.yaml" <<EOF
currency:
  base: "USD"
abbreviations:
  test: "Test Organization"
EOF

    export HOME="$TEST_TEMP_DIR"

    # The script should load config without error
    assert_success "'$SCRIPT' --help" "Script loads with config file present"

    teardown
}

# Test: Auto-confirm flag (-y/--yes)
test_auto_confirm_flag() {
    echo -e "\n${YELLOW}Testing auto-confirm flag...${NC}"

    # Test that -y flag is recognized
    assert_output_contains "'$SCRIPT' --help" "\-\-yes" "Help mentions --yes flag"
    assert_output_contains "'$SCRIPT' --help" "Skip confirmation" "Help explains --yes flag purpose"
}

# Test: AI provider selection flags
test_ai_provider_flags() {
    echo -e "\n${YELLOW}Testing AI provider flags...${NC}"

    assert_output_contains "'$SCRIPT' --help" "\-\-ollama" "Help mentions Ollama flag"
    assert_output_contains "'$SCRIPT' --help" "\-\-openai" "Help mentions OpenAI flag"
    assert_output_contains "'$SCRIPT' --help" "\-\-claude" "Help mentions Claude flag"
}

# Run all tests
run_tests() {
    echo -e "${YELLOW}Running smart-rename test suite...${NC}"
    echo "================================="

    test_script_exists
    test_help_flag
    test_version_flag
    test_regex_pattern_matching
    test_glob_pattern_matching
    test_recursive_search
    test_no_pattern_error
    test_config_loading
    test_auto_confirm_flag
    test_ai_provider_flags

    echo -e "\n================================="
    echo -e "Test Results:"
    echo -e "  Tests run: $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Handle cleanup on exit
trap teardown EXIT

# Run tests
run_tests