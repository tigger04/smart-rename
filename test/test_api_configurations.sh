#!/usr/bin/env bash
# ABOUTME: Comprehensive tests for API configuration scenarios
# ABOUTME: Tests all permutations of environment variables and config file settings

set -e

# Test configuration
TEST_HOME="/tmp/claude/smart-rename-api-test-$$"
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
    if [[ -n "$TEST_HOME" && "$TEST_HOME" =~ ^/tmp/claude/smart-rename-api-test- ]]; then
        trash "$TEST_HOME" 2>/dev/null || rm -rf "$TEST_HOME"
    fi
}

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_CONFIG_DIR"

    # Clear all API-related environment variables
    unset OPENAI_API_KEY
    unset ANTHROPIC_API_KEY
    unset CLAUDE_API_KEY
    unset SMART_RENAME_CONFIG
    unset CLAUDECODE
    unset CLAUDE_CODE_ENTRYPOINT
}

# Create config with specified API keys
create_config() {
    local openai_key="$1"
    local claude_key="$2"

    cat > "$TEST_CONFIG_DIR/config.yaml" <<EOF
# smart-rename YAML configuration file
api:
  openai:
EOF

    if [[ -n "$openai_key" ]]; then
        echo "    key: \"$openai_key\"" >> "$TEST_CONFIG_DIR/config.yaml"
    else
        echo "    # key: \"\"  # Set your OpenAI API key" >> "$TEST_CONFIG_DIR/config.yaml"
    fi

    cat >> "$TEST_CONFIG_DIR/config.yaml" <<EOF
    model: "gpt-4o-mini"
  claude:
EOF

    if [[ -n "$claude_key" ]]; then
        echo "    key: \"$claude_key\"" >> "$TEST_CONFIG_DIR/config.yaml"
    else
        echo "    # key: \"\"  # Set your Claude API key" >> "$TEST_CONFIG_DIR/config.yaml"
    fi

    cat >> "$TEST_CONFIG_DIR/config.yaml" <<EOF
    model: "claude-3-5-sonnet-20241022"
  ollama:
    url: "http://localhost:11434"
    model: "mistral"

default_provider: ""

prompts:
  rename: |
    Generate a concise, descriptive filename.

currency:
  base: "EUR"

abbreviations:
  test: "Test Hospital"
EOF
}

# Test help flag in various scenarios
test_help_flag() {
    local scenario="$1"
    local env_vars="$2"

    test_start "Help flag works with $scenario"

    # Use timeout to prevent hanging
    if timeout 5 env HOME="$TEST_HOME" $env_vars smart-rename -h >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Help flag failed with $scenario"
    fi
}

# Test version flag
test_version_flag() {
    local scenario="$1"
    local env_vars="$2"

    test_start "Version flag works with $scenario"

    if timeout 5 env HOME="$TEST_HOME" $env_vars smart-rename -v >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Version flag failed with $scenario"
    fi
}

# Test that actual functionality fails gracefully with fake keys
test_graceful_failure() {
    local scenario="$1"
    local env_vars="$2"

    test_start "Graceful failure with fake keys: $scenario"

    # Create a test file to try renaming
    echo "Test content for renaming" > "$TEST_HOME/test-file.txt"

    # Should fail gracefully (exit code != 0 but no crash)
    if timeout 10 env HOME="$TEST_HOME" $env_vars smart-rename --dry-run "$TEST_HOME/test-file.txt" >/dev/null 2>&1; then
        test_fail "Should have failed gracefully with fake keys"
    else
        # Check that it failed properly (not a timeout or crash)
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then  # timeout exit code
            test_fail "Timed out - possible hang with fake keys"
        else
            test_pass  # Failed gracefully as expected
        fi
    fi

    trash "$TEST_HOME/test-file.txt" 2>/dev/null || rm -f "$TEST_HOME/test-file.txt"
}

# Ensure cleanup on exit
trap cleanup EXIT

echo "Setting up test environment..."
setup_test_env

# Test 1: No config file, no environment variables
echo
echo "=== Testing with no config file and no environment variables ==="
test_help_flag "no config, no env vars" ""
test_version_flag "no config, no env vars" ""

# Test 2: Config file with commented keys, no environment variables
echo
echo "=== Testing with commented config keys and no environment variables ==="
create_config "" ""
test_help_flag "commented config keys, no env vars" ""
test_version_flag "commented config keys, no env vars" ""

# Test 3: Config file with empty string keys, no environment variables
echo
echo "=== Testing with empty config keys and no environment variables ==="
create_config '""' '""'
test_help_flag "empty config keys, no env vars" ""
test_version_flag "empty config keys, no env vars" ""

# Test 4: No config file, with environment variables
echo
echo "=== Testing with no config file and environment variables ==="
trash "$TEST_CONFIG_DIR/config.yaml" 2>/dev/null || rm -f "$TEST_CONFIG_DIR/config.yaml"
test_help_flag "no config, with env vars" "OPENAI_API_KEY=test-key-123"
test_version_flag "no config, with env vars" "OPENAI_API_KEY=test-key-123"

# Test 5: Config with commented keys, with environment variables
echo
echo "=== Testing with commented config keys and environment variables ==="
create_config "" ""
test_help_flag "commented config, with env vars" "OPENAI_API_KEY=test-key-123"
test_version_flag "commented config, with env vars" "OPENAI_API_KEY=test-key-123"

# Test 6: Config with empty keys, with environment variables (env should override)
echo
echo "=== Testing with empty config keys and environment variables ==="
create_config '""' '""'
test_help_flag "empty config, with env vars" "OPENAI_API_KEY=test-key-123"
test_version_flag "empty config, with env vars" "OPENAI_API_KEY=test-key-123"

# Test 7: Config with fake keys - should still allow help/version
echo
echo "=== Testing with fake config keys (should allow help/version) ==="
create_config "fake-openai-key-12345" "fake-claude-key-67890"
test_help_flag "fake config keys" ""
test_version_flag "fake config keys" ""

# Test 8: Config with fake keys AND fake environment variables
echo
echo "=== Testing with fake keys everywhere (should still allow help/version) ==="
test_help_flag "fake keys everywhere" "OPENAI_API_KEY=fake-env-key-123"
test_version_flag "fake keys everywhere" "OPENAI_API_KEY=fake-env-key-123"

# Test 9: Multiple fake environment variables set
echo
echo "=== Testing with multiple fake environment variables ==="
create_config "" ""
test_help_flag "multiple fake env vars" "OPENAI_API_KEY=fake1 ANTHROPIC_API_KEY=fake2"
test_version_flag "multiple fake env vars" "OPENAI_API_KEY=fake1 ANTHROPIC_API_KEY=fake2"

# Test 10: Test that Claude Code environment variables don't interfere
echo
echo "=== Testing that Claude Code variables don't interfere ==="
test_help_flag "with Claude Code vars" "CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli"
test_version_flag "with Claude Code vars" "CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli"

# Test 11: Test graceful failure with fake API keys
echo
echo "=== Testing graceful failure with fake API keys ==="
create_config "fake-openai-key-12345" ""
test_graceful_failure "fake OpenAI key in config" ""
test_graceful_failure "fake OpenAI key in env" "OPENAI_API_KEY=fake-key-xyz"

# Summary
echo
echo "================================="
echo "API Configuration Test Results:"
echo "Tests run: $TESTS"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "================================="

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some API configuration tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All API configuration tests passed!${NC}"
    exit 0
fi