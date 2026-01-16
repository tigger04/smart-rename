#!/usr/bin/env bash
# ABOUTME: Test suite for YAML configuration functionality
# ABOUTME: Verifies YAML config loading, parsing, and placeholder substitution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counter
TESTS=0
PASSED=0
FAILED=0

# Create temporary test environment
TEST_DIR="$(mktemp -d)"
trap "rm -rf $TEST_DIR" EXIT

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
}

# Source the library for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/summarize-text-lib.sh"

# Test 1: Default YAML config creation
test_start "Default YAML config is created"
TEST_CONFIG_DIR="$TEST_DIR/.config/smart-rename"
mkdir -p "$TEST_CONFIG_DIR"
HOME="$TEST_DIR" load_config

if [ -f "$TEST_CONFIG_DIR/config.yaml" ]; then
    test_pass
else
    test_fail "Default config.yaml was not created"
fi

# Test 2: YAML config parsing
test_start "YAML config parsing works"
cat > "$TEST_CONFIG_DIR/config.yaml" << EOF
api:
  openai:
    key: "test-openai-key"
    model: "gpt-4"
  claude:
    key: "test-claude-key"
    model: "claude-3"
currency:
  base: "USD"
abbreviations:
  test: "Test Hospital"
  demo: "Demo Clinic"
EOF

HOME="$TEST_DIR" load_config

if [[ "$OPENAI_API_KEY" == "test-openai-key" ]] && [[ "$base_currency" == "USD" ]]; then
    test_pass
else
    test_fail "YAML config values not loaded correctly"
fi

# Test 3: Abbreviations loading from YAML
test_start "Abbreviations loaded from YAML"
if [[ "${abbreviations[test]}" == "Test Hospital" ]] && [[ "${abbreviations[demo]}" == "Demo Clinic" ]]; then
    test_pass
else
    test_fail "Abbreviations not loaded from YAML config"
fi

# Test 4: Custom prompt from YAML
test_start "Custom prompt loading from YAML"
cat > "$TEST_CONFIG_DIR/config.yaml" << EOF
prompts:
  rename: "Custom test prompt with {{BASE_CURRENCY}} and {{ABBREVIATIONS}}"
currency:
  base: "GBP"
abbreviations:
  xyz: "XYZ Hospital"
EOF

HOME="$TEST_DIR" load_config

# Test prompt building
if [[ "$yaml_prompt_template" == "Custom test prompt with {{BASE_CURRENCY}} and {{ABBREVIATIONS}}" ]]; then
    test_pass
else
    test_fail "Custom prompt not loaded from YAML"
fi

# Test 5: Prompt placeholder substitution
test_start "Prompt placeholder substitution"

# Mock the build_prompt function from smart-rename
build_prompt() {
   local prompt_template="$yaml_prompt_template"

   # Build abbreviations text
   local abbrev_text=""
   if [[ ${#abbreviations[@]} -gt 0 ]]; then
      local abbrev_list=""
      for key in "${!abbreviations[@]}"; do
         abbrev_list+="- $key = ${abbreviations[$key]}"$'\n'
      done
      abbrev_text="Utilize the following abbreviations:"$'\n'"$abbrev_list"
      abbrev_text+="Utilize any other common abbreviations as appropriate in this pattern."
   fi

   # Substitute placeholders
   prompt_template="${prompt_template//\{\{BASE_CURRENCY\}\}/${base_currency:-EUR}}"
   prompt_template="${prompt_template//\{\{ABBREVIATIONS\}\}/$abbrev_text}"

   echo "$prompt_template"
}

built_prompt=$(build_prompt)
if [[ "$built_prompt" =~ "GBP" ]] && [[ "$built_prompt" =~ "XYZ Hospital" ]]; then
    test_pass
else
    test_fail "Placeholder substitution not working correctly"
fi

# Test 6: Backwards compatibility with shell config
test_start "Backwards compatibility with shell config"
cat > "$TEST_CONFIG_DIR/config" << EOF
export OPENAI_API_KEY="shell-openai-key"
base_currency="CHF"
EOF

# Remove YAML config to test shell config
rm -f "$TEST_CONFIG_DIR/config.yaml"
HOME="$TEST_DIR" load_config

if [[ "$OPENAI_API_KEY" == "shell-openai-key" ]] && [[ "$base_currency" == "CHF" ]]; then
    test_pass
else
    test_fail "Shell config backwards compatibility broken"
fi

# Test 7: Environment variable override
test_start "Environment variable override works"
export OPENAI_API_KEY="env-openai-key"
HOME="$TEST_DIR" load_config

if [[ "$OPENAI_API_KEY" == "env-openai-key" ]]; then
    test_pass
    unset OPENAI_API_KEY
else
    test_fail "Environment variables should override config files"
    unset OPENAI_API_KEY
fi

# Summary
echo ""
echo "================================="
echo "YAML Configuration Test Results:"
echo "Tests run: $TESTS"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi