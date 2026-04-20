#!/usr/bin/env bash
# ABOUTME: Tests --example-config CLI option and stale config schema detection
# ABOUTME: Validates config output to stdout and warning on outdated user config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

passed=0
failed=0

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Expected: $expected"
        echo "      Got:      $actual"
        failed=$((failed + 1))
    fi
    echo ""
}

assert_contains() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == *"$expected"* ]]; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Expected to contain: $expected"
        echo "      Got:                 $actual"
        failed=$((failed + 1))
    fi
    echo ""
}

assert_not_contains() {
    local test_name="$1"
    local unexpected="$2"
    local actual="$3"

    if [[ "$actual" != *"$unexpected"* ]]; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Expected NOT to contain: $unexpected"
        echo "      Got:                     $actual"
        failed=$((failed + 1))
    fi
    echo ""
}

echo "=== Testing --example-config and stale config detection ==="
echo ""

# --- Test 1: --example-config flag exists in argument parser ---
echo "--- --example-config flag is recognised ---"
echo ""

if grep -q '\-\-example-config' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: Script recognises --example-config flag"
    passed=$((passed + 1))
else
    echo "FAIL: Script does not recognise --example-config flag"
    failed=$((failed + 1))
fi
echo ""

# --- Test 2: --example-config prints config.example.yaml to stdout ---
echo "--- --example-config prints example config to stdout ---"
echo ""

stdout_output=$("$PROJECT_ROOT/smart-rename" --example-config 2>/dev/null)
assert_contains "--example-config outputs prompt.template" "prompt:" "$stdout_output"
assert_contains "--example-config outputs api config" "api:" "$stdout_output"
assert_contains "--example-config outputs currency config" "currency:" "$stdout_output"

# --- Test 3: --example-config output matches config.example.yaml content ---
echo "--- --example-config output matches config.example.yaml ---"
echo ""

expected_content=$(cat "$PROJECT_ROOT/config.example.yaml")
assert_eq "--example-config matches config.example.yaml" "$expected_content" "$stdout_output"

# --- Test 4: --example-config exits with 0 ---
echo "--- --example-config exits cleanly ---"
echo ""

if "$PROJECT_ROOT/smart-rename" --example-config >/dev/null 2>/dev/null; then
    echo "PASS: --example-config exits with code 0"
    passed=$((passed + 1))
else
    echo "FAIL: --example-config exits with non-zero code"
    failed=$((failed + 1))
fi
echo ""

# --- Test 5: --example-config produces no stderr ---
echo "--- --example-config produces no stderr ---"
echo ""

stderr_output=$("$PROJECT_ROOT/smart-rename" --example-config 2>&1 >/dev/null)
assert_eq "--example-config produces no stderr" "" "$stderr_output"

# --- Test 6: --example-config is documented in help ---
echo "--- --example-config appears in --help ---"
echo ""

help_output=$("$PROJECT_ROOT/smart-rename" --help 2>&1)
assert_contains "--example-config is in help text" "--example-config" "$help_output"

# --- Test 7: Stale config detection - old prompts.rename key triggers warning ---
echo "--- Stale config: prompts.rename triggers warning ---"
echo ""

# Create a fake share dir with real config.example.yaml
fake_share="$TEMP_DIR/share"
mkdir -p "$fake_share"
cp "$PROJECT_ROOT/config.example.yaml" "$fake_share/"

# Create a stale config with old schema
cat > "$TEMP_DIR/stale_config.yaml" <<'YAML'
prompts:
  rename: |
    Old style single prompt
api:
  ollama:
    model: "qwen2.5:7b"
YAML

cat > "$TEMP_DIR/test_stale_warning.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/stale_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"
SCRIPT_NAME="smart-rename"

PROMPT_TEMPLATE=""
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)
PROVIDER_PREFERENCE_NAME=(openai claude ollama)

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config 2>&1
SCRIPT
chmod +x "$TEMP_DIR/test_stale_warning.sh"

stale_output=$("$TEMP_DIR/test_stale_warning.sh" 2>&1)
assert_contains "Stale config warning mentions outdated" "outdated" "$stale_output"
assert_contains "Stale config warning mentions --example-config" "--example-config" "$stale_output"

# --- Test 8: No warning when config is valid ---
echo "--- No warning for valid config ---"
echo ""

cat > "$TEMP_DIR/valid_config.yaml" <<'YAML'
prompt:
  template: |
    Custom prompt for testing
api:
  ollama:
    model: custom-model
YAML

cat > "$TEMP_DIR/test_valid_config.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/valid_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"
SCRIPT_NAME="smart-rename"

PROMPT_TEMPLATE=""
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)
PROVIDER_PREFERENCE_NAME=(openai claude ollama)

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config 2>&1
SCRIPT
chmod +x "$TEMP_DIR/test_valid_config.sh"

valid_output=$("$TEMP_DIR/test_valid_config.sh" 2>&1)
assert_not_contains "No stale warning for valid config" "outdated" "$valid_output"

# --- Test 9: No warning when no user config exists ---
echo "--- No warning when no user config ---"
echo ""

cat > "$TEMP_DIR/test_no_config.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/nonexistent_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"
SCRIPT_NAME="smart-rename"

PROMPT_TEMPLATE=""
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)
PROVIDER_PREFERENCE_NAME=(openai claude ollama)

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config 2>&1
SCRIPT
chmod +x "$TEMP_DIR/test_no_config.sh"

no_config_output=$("$TEMP_DIR/test_no_config.sh" 2>&1)
assert_not_contains "No stale warning when no user config" "outdated" "$no_config_output"

# Summary
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
