#!/usr/bin/env bash
# ABOUTME: Tests that provider preference order is read from config and respected
# ABOUTME: Validates default order, custom order, and the get_ai_response dispatch logic

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

echo "=== Testing provider preference ==="
echo ""

# --- Test 1: Default preference order is ollama, openai, claude ---
echo "--- Default preference order ---"
echo ""

default_pref=$(grep '^PROVIDER_PREFERENCE=' "$PROJECT_ROOT/smart-rename" | head -1)
assert_eq "Default preference is (ollama openai claude)" \
    'PROVIDER_PREFERENCE=(ollama openai claude)' \
    "$default_pref"

# --- Test 2: config.example.yaml has preference list ---
echo "--- config.example.yaml has preference list ---"
echo ""

if ! command -v yq >/dev/null 2>&1; then
    echo "SKIP: yq not available"
    echo ""
else
    pref_0=$(yq eval '.api.preference[0]' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    pref_1=$(yq eval '.api.preference[1]' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    pref_2=$(yq eval '.api.preference[2]' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)

    assert_eq "config.example.yaml preference[0] is ollama" "ollama" "$pref_0"
    assert_eq "config.example.yaml preference[1] is openai" "openai" "$pref_1"
    assert_eq "config.example.yaml preference[2] is claude" "claude" "$pref_2"

    # --- Test 3: load_config reads custom preference order ---
    echo "--- load_config reads custom preference ---"
    echo ""

    cat > "$TEMP_DIR/custom_pref.yaml" <<'YAML'
api:
  preference:
    - claude
    - ollama
YAML

    # Build a test harness that sources load_config with custom config
    cat > "$TEMP_DIR/test_pref.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/custom_pref.yaml"
CONFIG_DIR="$TEMP_DIR"

# Emergency fallback defaults
PROMPT_TEMPLATE=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE=(ollama openai claude)
SMART_RENAME_SHARE_DIR=""

# Extract functions from smart-rename
eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "\${PROVIDER_PREFERENCE[*]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_pref.sh"

    result=$("$TEMP_DIR/test_pref.sh" 2>/dev/null)
    assert_eq "load_config reads custom preference (claude ollama)" "claude ollama" "$result"

    # --- Test 4: Empty/missing preference keeps default ---
    echo "--- Missing preference keeps default ---"
    echo ""

    cat > "$TEMP_DIR/no_pref.yaml" <<'YAML'
api:
  ollama:
    model: test-model
YAML

    cat > "$TEMP_DIR/test_no_pref.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/no_pref.yaml"
CONFIG_DIR="$TEMP_DIR"

PROMPT_TEMPLATE=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE=(ollama openai claude)
SMART_RENAME_SHARE_DIR=""

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "\${PROVIDER_PREFERENCE[*]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_no_pref.sh"

    result=$("$TEMP_DIR/test_no_pref.sh" 2>/dev/null)
    assert_eq "Missing preference keeps default (ollama openai claude)" "ollama openai claude" "$result"
fi

# --- Test 5: get_ai_response dispatches to provider functions ---
echo "--- get_ai_response uses PROVIDER_PREFERENCE ---"
echo ""

# Verify the function exists and uses PROVIDER_PREFERENCE
if grep -q 'for provider in "\${PROVIDER_PREFERENCE\[@\]}"' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: get_ai_response iterates over PROVIDER_PREFERENCE"
    passed=$((passed + 1))
else
    echo "FAIL: get_ai_response does not iterate over PROVIDER_PREFERENCE"
    failed=$((failed + 1))
fi
echo ""

# Verify try_ollama, try_openai, try_claude functions exist
for fn in try_ollama try_openai try_claude; do
    if grep -q "^${fn}()" "$PROJECT_ROOT/smart-rename"; then
        echo "PASS: Function ${fn}() exists"
        passed=$((passed + 1))
    else
        echo "FAIL: Function ${fn}() missing"
        failed=$((failed + 1))
    fi
done
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
