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

# --- RT-36.9: Emergency fallback classify preference is ollama, openai, claude ---
echo "--- RT-36.9: Emergency fallback classify preference ---"
echo ""

default_classify=$(grep '^PROVIDER_PREFERENCE_CLASSIFY=' "$PROJECT_ROOT/smart-rename" | head -1 || echo "NOT_FOUND")
assert_eq "RT-36.9: Default classify preference is (ollama openai claude)" \
    'PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)' \
    "$default_classify"

# --- RT-36.10: Emergency fallback name preference is openai, claude, ollama ---
echo "--- RT-36.10: Emergency fallback name preference ---"
echo ""

default_name=$(grep '^PROVIDER_PREFERENCE_NAME=' "$PROJECT_ROOT/smart-rename" | head -1 || echo "NOT_FOUND")
assert_eq "RT-36.10: Default name preference is (openai claude ollama)" \
    'PROVIDER_PREFERENCE_NAME=(openai claude ollama)' \
    "$default_name"

# --- RT-36.1: Default classify preference from config.example.yaml ---
echo "--- RT-36.1: config.example.yaml classify preference ---"
echo ""

if ! command -v yq >/dev/null 2>&1; then
    echo "SKIP: yq not available"
    echo ""
else
    classify_0=$(yq eval '.api.preference.classify[0] // "null"' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null || echo "null")
    classify_1=$(yq eval '.api.preference.classify[1] // "null"' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null || echo "null")
    classify_2=$(yq eval '.api.preference.classify[2] // "null"' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null || echo "null")

    assert_eq "RT-36.1: config.example.yaml classify[0] is ollama" "ollama" "$classify_0"
    assert_eq "RT-36.1: config.example.yaml classify[1] is openai" "openai" "$classify_1"
    assert_eq "RT-36.1: config.example.yaml classify[2] is claude" "claude" "$classify_2"

    # --- RT-36.3: Default name preference from config.example.yaml ---
    echo "--- RT-36.3: config.example.yaml name preference ---"
    echo ""

    name_0=$(yq eval '.api.preference.name[0] // "null"' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null || echo "null")
    name_1=$(yq eval '.api.preference.name[1] // "null"' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null || echo "null")
    name_2=$(yq eval '.api.preference.name[2] // "null"' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null || echo "null")

    assert_eq "RT-36.3: config.example.yaml name[0] is openai" "openai" "$name_0"
    assert_eq "RT-36.3: config.example.yaml name[1] is claude" "claude" "$name_1"
    assert_eq "RT-36.3: config.example.yaml name[2] is ollama" "ollama" "$name_2"

    # --- RT-36.2: Custom classify preference from config is respected ---
    echo "--- RT-36.2: load_config reads custom classify preference ---"
    echo ""

    cat > "$TEMP_DIR/custom_phase_pref.yaml" <<'YAML'
api:
  preference:
    classify:
      - claude
      - ollama
    name:
      - openai
YAML

    cat > "$TEMP_DIR/test_phase_pref.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/custom_phase_pref.yaml"
CONFIG_DIR="$TEMP_DIR"

# Emergency fallback defaults
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
SMART_RENAME_SHARE_DIR=""
EXCLUDED_WORDS=()

# Extract functions from smart-rename
eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "CLASSIFY=\${PROVIDER_PREFERENCE_CLASSIFY[*]}"
echo "NAME=\${PROVIDER_PREFERENCE_NAME[*]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_phase_pref.sh"

    result=$("$TEMP_DIR/test_phase_pref.sh" 2>/dev/null)
    classify_loaded=$(echo "$result" | grep '^CLASSIFY=' | cut -d= -f2)
    name_loaded=$(echo "$result" | grep '^NAME=' | cut -d= -f2)
    assert_eq "RT-36.2: Custom classify preference (claude ollama)" "claude ollama" "$classify_loaded"

    # --- RT-36.4: Custom name preference from config is respected ---
    echo "--- RT-36.4: load_config reads custom name preference ---"
    echo ""

    assert_eq "RT-36.4: Custom name preference (openai)" "openai" "$name_loaded"

    # --- RT-36.5: Flat preference list populates both classify and name arrays ---
    echo "--- RT-36.5: Flat preference populates both arrays ---"
    echo ""

    cat > "$TEMP_DIR/flat_pref.yaml" <<'YAML'
api:
  preference:
    - claude
    - ollama
YAML

    cat > "$TEMP_DIR/test_flat_pref.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/flat_pref.yaml"
CONFIG_DIR="$TEMP_DIR"

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
SMART_RENAME_SHARE_DIR=""
EXCLUDED_WORDS=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "CLASSIFY=\${PROVIDER_PREFERENCE_CLASSIFY[*]}"
echo "NAME=\${PROVIDER_PREFERENCE_NAME[*]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_flat_pref.sh"

    result=$("$TEMP_DIR/test_flat_pref.sh" 2>/dev/null)
    classify_loaded=$(echo "$result" | grep '^CLASSIFY=' | cut -d= -f2)
    name_loaded=$(echo "$result" | grep '^NAME=' | cut -d= -f2)
    assert_eq "RT-36.5: Flat preference populates classify (claude ollama)" "claude ollama" "$classify_loaded"
    assert_eq "RT-36.5: Flat preference populates name (claude ollama)" "claude ollama" "$name_loaded"

    # --- RT-36.6: Per-phase config takes precedence over flat list when both present ---
    echo "--- RT-36.6: Per-phase takes precedence over flat ---"
    echo ""

    cat > "$TEMP_DIR/mixed_pref.yaml" <<'YAML'
api:
  preference:
    classify:
      - openai
    name:
      - claude
      - ollama
YAML

    cat > "$TEMP_DIR/test_mixed_pref.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/mixed_pref.yaml"
CONFIG_DIR="$TEMP_DIR"

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
SMART_RENAME_SHARE_DIR=""
EXCLUDED_WORDS=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "CLASSIFY=\${PROVIDER_PREFERENCE_CLASSIFY[*]}"
echo "NAME=\${PROVIDER_PREFERENCE_NAME[*]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_mixed_pref.sh"

    result=$("$TEMP_DIR/test_mixed_pref.sh" 2>/dev/null)
    classify_loaded=$(echo "$result" | grep '^CLASSIFY=' | cut -d= -f2)
    name_loaded=$(echo "$result" | grep '^NAME=' | cut -d= -f2)
    assert_eq "RT-36.6: Per-phase classify takes precedence (openai)" "openai" "$classify_loaded"
    assert_eq "RT-36.6: Per-phase name takes precedence (claude ollama)" "claude ollama" "$name_loaded"

    # --- Missing preference keeps default ---
    echo "--- Missing preference keeps defaults ---"
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
SMART_RENAME_SHARE_DIR=""
EXCLUDED_WORDS=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "CLASSIFY=\${PROVIDER_PREFERENCE_CLASSIFY[*]}"
echo "NAME=\${PROVIDER_PREFERENCE_NAME[*]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_no_pref.sh"

    result=$("$TEMP_DIR/test_no_pref.sh" 2>/dev/null)
    classify_loaded=$(echo "$result" | grep '^CLASSIFY=' | cut -d= -f2)
    name_loaded=$(echo "$result" | grep '^NAME=' | cut -d= -f2)
    assert_eq "Missing preference keeps classify default (ollama openai claude)" "ollama openai claude" "$classify_loaded"
    assert_eq "Missing preference keeps name default (openai claude ollama)" "openai claude ollama" "$name_loaded"
fi

# --- get_ai_response dispatches by phase ---
echo "--- get_ai_response uses phase-specific preference ---"
echo ""

# Verify the function accepts a phase parameter and uses namerefs
if grep -q 'PROVIDER_PREFERENCE_CLASSIFY' "$PROJECT_ROOT/smart-rename" && \
   grep -q 'PROVIDER_PREFERENCE_NAME' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: Script defines PROVIDER_PREFERENCE_CLASSIFY and PROVIDER_PREFERENCE_NAME"
    passed=$((passed + 1))
else
    echo "FAIL: Script should define PROVIDER_PREFERENCE_CLASSIFY and PROVIDER_PREFERENCE_NAME"
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

# Verify process_file passes phase to get_ai_response
if grep -q 'get_ai_response.*classify' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: process_file passes classify phase to get_ai_response"
    passed=$((passed + 1))
else
    echo "FAIL: process_file should pass classify phase to get_ai_response"
    failed=$((failed + 1))
fi
echo ""

if grep -q 'get_ai_response.*name' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: process_file passes name phase to get_ai_response"
    passed=$((passed + 1))
else
    echo "FAIL: process_file should pass name phase to get_ai_response"
    failed=$((failed + 1))
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
