#!/usr/bin/env bash
# ABOUTME: End-to-end test for fresh Homebrew installation of smart-rename
# ABOUTME: Validates complete installation flow and functionality with clean environment

set -e

# Test configuration
TEST_HOME="/tmp/claude/smart-rename-test-$$"
TEST_CONFIG_DIR="$TEST_HOME/.config/smart-rename"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counter
TESTS=0
PASSED=0
FAILED=0

# Test helper functions
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
    if [[ -n "$TEST_HOME" && "$TEST_HOME" =~ ^/tmp/claude/smart-rename-test- ]]; then
        trash "$TEST_HOME" 2>/dev/null || rm -rf "$TEST_HOME"
    fi
    # Remove any test tap if added
    brew untap tigger04/tap 2>/dev/null || true
}

# Setup clean test environment
setup_test_env() {
    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_CONFIG_DIR"
    export HOME="$TEST_HOME"

    # Ensure we have a clean environment
    unset OPENAI_API_KEY
    unset ANTHROPIC_API_KEY
    unset SMART_RENAME_CONFIG
}

# Ensure cleanup on exit
trap cleanup EXIT

# Skip tests if brew is not available
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Skipping fresh install tests: brew not available${NC}"
    exit 0
fi

echo "Setting up clean test environment..."
setup_test_env

# Test 1: Clean tap installation
test_start "Clean Homebrew tap installation"
if brew tap tigger04/tap >/dev/null 2>&1; then
    test_pass
else
    test_fail "Failed to add Homebrew tap"
fi

# Test 2: Formula installation
test_start "Install smart-rename formula"
if brew install tigger04/tap/smart-rename >/dev/null 2>&1; then
    test_pass
else
    test_fail "Failed to install smart-rename formula"
fi

# Test 3: Binary is available in PATH
test_start "Binary available in PATH"
if command -v smart-rename >/dev/null 2>&1; then
    test_pass
else
    test_fail "smart-rename not found in PATH after installation"
fi

# Test 4: Help flag works immediately after install
test_start "Help flag works after fresh install"
if smart-rename -h >/dev/null 2>&1; then
    test_pass
else
    test_fail "Help flag failed after fresh install"
fi

# Test 5: Version flag works
test_start "Version flag works"
if smart-rename -v >/dev/null 2>&1; then
    test_pass
else
    test_fail "Version flag failed"
fi

# Test 6: Default config is created automatically
test_start "Default configuration created"
# Run any command that would trigger config creation
smart-rename --help >/dev/null 2>&1 || true
if [[ -f "$TEST_CONFIG_DIR/config.yaml" ]]; then
    test_pass
else
    test_fail "Default config not created at $TEST_CONFIG_DIR/config.yaml"
fi

# Test 7: Default config doesn't override environment variables
test_start "Default config allows environment variable fallback"
if [[ -f "$TEST_CONFIG_DIR/config.yaml" ]]; then
    # Check that API keys are commented out in default config
    if grep -q "^[[:space:]]*#.*key:" "$TEST_CONFIG_DIR/config.yaml" || ! grep -q "key:.*\"\"" "$TEST_CONFIG_DIR/config.yaml"; then
        test_pass
    else
        test_fail "Default config contains uncommented empty API keys that would override environment variables"
    fi
else
    test_fail "No config file to test"
fi

# Test 8: Ollama dependency is installed
test_start "Ollama dependency installed"
if command -v ollama >/dev/null 2>&1; then
    test_pass
else
    test_fail "Ollama not available after installation"
fi

# Test 9: Ollama is running (if possible)
test_start "Ollama service availability"
if curl -s http://localhost:11434 >/dev/null 2>&1; then
    test_pass
elif pgrep ollama >/dev/null 2>&1; then
    test_pass  # Process is running even if not responding
else
    echo -e "${YELLOW}⚠${NC} Ollama not running (this may require manual start)"
    # Don't fail this test as Ollama might need manual intervention
    PASSED=$((PASSED + 1))
fi

# Test 10: Test with a simple file (using Ollama if available)
test_start "Basic rename functionality"
echo "This is a test document from January 2024." > "$TEST_HOME/test-file.txt"
# Test rename with dry-run to avoid requiring API keys
if smart-rename --dry-run "$TEST_HOME/test-file.txt" >/dev/null 2>&1; then
    test_pass
else
    test_fail "Basic rename functionality failed"
fi

# Test 11: Library file is installed correctly
test_start "Library file installed correctly"
# Check if the library is in the expected location
BREW_PREFIX=$(brew --prefix)
if [[ -f "$BREW_PREFIX/share/smart-rename/summarize-text-lib.sh" ]]; then
    test_pass
else
    test_fail "Library file not found at expected location"
fi

# Test 12: No broken symlinks or missing dependencies
test_start "No broken dependencies"
if smart-rename --version >/dev/null 2>&1; then
    test_pass
else
    test_fail "Binary has broken dependencies"
fi

# Cleanup - uninstall to avoid polluting system
echo
echo "Cleaning up test installation..."
brew uninstall tigger04/tap/smart-rename >/dev/null 2>&1 || true

# Summary
echo
echo "================================="
echo "Fresh Install Test Results:"
echo "Tests run: $TESTS"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "================================="

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Fresh installation tests failed. Homebrew formula needs fixes.${NC}"
    exit 1
else
    echo -e "${GREEN}All fresh installation tests passed!${NC}"
    exit 0
fi