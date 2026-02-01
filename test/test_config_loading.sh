#!/usr/bin/env bash
# ABOUTME: Tests layered config loading: config.example.yaml -> user config -> emergency fallback
# ABOUTME: Validates that config.example.yaml is the single source of truth for defaults

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

passed=0
failed=0

# Create temp directory for test configs
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

assert_not_empty() {
    local test_name="$1"
    local actual="$2"

    if [[ -n "$actual" ]]; then
        echo "PASS: $test_name (value: $actual)"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Expected: non-empty value"
        echo "      Got:      (empty)"
        failed=$((failed + 1))
    fi
    echo ""
}

echo "=== Testing layered config loading ==="
echo ""

# Requires yq for most tests
if ! command -v yq >/dev/null 2>&1; then
    echo "SKIP: yq not available, skipping YAML config tests"
    echo ""
    echo "=== Summary ==="
    echo "Passed: $passed"
    echo "Failed: $failed"
    exit 0
fi

# --- Test 1: config.example.yaml is the single source of truth ---
echo "--- config.example.yaml defines all defaults ---"
echo ""

openai_example=$(yq eval '.api.openai.model // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
assert_not_empty "config.example.yaml defines openai model" "$openai_example"

claude_example=$(yq eval '.api.claude.model // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
assert_not_empty "config.example.yaml defines claude model" "$claude_example"

ollama_example=$(yq eval '.api.ollama.model // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
assert_not_empty "config.example.yaml defines ollama model" "$ollama_example"

prompt_example=$(yq eval '.prompt.template // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
assert_not_empty "config.example.yaml defines prompt template" "$prompt_example"

currency_example=$(yq eval '.currency.base // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
assert_not_empty "config.example.yaml defines base currency" "$currency_example"

pref_count=$(yq eval '.api.preference | length' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
assert_eq "config.example.yaml has 3 providers in preference" "3" "$pref_count"

# Config uses prompt.template (not prompts.rename)
old_prompt=$(yq eval '.prompts.rename // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
assert_eq "config.example.yaml does NOT use prompts.rename" "" "$old_prompt"

# Prompt template has classification-first structure and never-fabricate guardrail
if echo "$prompt_example" | grep -qi 'determine\|classify\|identify.*type'; then
    echo "PASS: Prompt template requires document type classification"
    passed=$((passed + 1))
else
    echo "FAIL: Prompt template should require document type classification"
    failed=$((failed + 1))
fi
echo ""

if echo "$prompt_example" | grep -qi 'never fabricate\|never invent\|do not invent\|do not fabricate'; then
    echo "PASS: Prompt template has never-fabricate guardrail"
    passed=$((passed + 1))
else
    echo "FAIL: Prompt template should have never-fabricate guardrail"
    failed=$((failed + 1))
fi
echo ""

if echo "$prompt_example" | grep -qi 'ONLY.*receipt\|only.*receipt'; then
    echo "PASS: Prompt template gates receipt format conditionally"
    passed=$((passed + 1))
else
    echo "FAIL: Prompt template should gate receipt format with ONLY condition"
    failed=$((failed + 1))
fi
echo ""

# --- Test 2: Defaults loaded from config.example.yaml, not hardcoded ---
echo "--- Defaults come from config.example.yaml ---"
echo ""

# Create a fake share dir with our real config.example.yaml
fake_share="$TEMP_DIR/share"
mkdir -p "$fake_share"
cp "$PROJECT_ROOT/config.example.yaml" "$fake_share/"

# No user config, but config.example.yaml available via share dir
cat > "$TEMP_DIR/test_defaults_from_example.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/nonexistent_user_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

# Emergency fallbacks — these should NOT be used when config.example.yaml is found
PROMPT_TEMPLATE=""
BASE_CURRENCY="EMERGENCY"
OLLAMA_MODEL="emergency-model"
OPENAI_MODEL="emergency-model"
CLAUDE_MODEL="emergency-model"
MAX_CONTENT_LENGTH=0
API_TIMEOUT=0
PROVIDER_PREFERENCE=()

# Extract functions from smart-rename
eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "OLLAMA=\$OLLAMA_MODEL"
echo "OPENAI=\$OPENAI_MODEL"
echo "CLAUDE=\$CLAUDE_MODEL"
echo "CURRENCY=\$BASE_CURRENCY"
echo "PREF=\${PROVIDER_PREFERENCE[*]}"
SCRIPT
chmod +x "$TEMP_DIR/test_defaults_from_example.sh"

result=$("$TEMP_DIR/test_defaults_from_example.sh" 2>/dev/null)

ollama_loaded=$(echo "$result" | grep '^OLLAMA=' | cut -d= -f2)
openai_loaded=$(echo "$result" | grep '^OPENAI=' | cut -d= -f2)
claude_loaded=$(echo "$result" | grep '^CLAUDE=' | cut -d= -f2)
currency_loaded=$(echo "$result" | grep '^CURRENCY=' | cut -d= -f2)
pref_loaded=$(echo "$result" | grep '^PREF=' | cut -d= -f2)

assert_eq "Defaults: ollama model from config.example.yaml" "$ollama_example" "$ollama_loaded"
assert_eq "Defaults: openai model from config.example.yaml" "$openai_example" "$openai_loaded"
assert_eq "Defaults: claude model from config.example.yaml" "$claude_example" "$claude_loaded"
assert_eq "Defaults: currency from config.example.yaml" "$currency_example" "$currency_loaded"
assert_eq "Defaults: preference from config.example.yaml" "ollama openai claude" "$pref_loaded"

# --- Test 3: User config overrides config.example.yaml ---
echo "--- User config overrides example defaults ---"
echo ""

cat > "$TEMP_DIR/user_config.yaml" <<'YAML'
api:
  openai:
    model: user-openai-override
  claude:
    model: user-claude-override
  ollama:
    model: user-ollama-override
  preference:
    - claude
    - ollama
currency:
  base: USD
YAML

cat > "$TEMP_DIR/test_user_override.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/user_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

PROMPT_TEMPLATE=""
BASE_CURRENCY="EMERGENCY"
OLLAMA_MODEL="emergency-model"
OPENAI_MODEL="emergency-model"
CLAUDE_MODEL="emergency-model"
MAX_CONTENT_LENGTH=0
API_TIMEOUT=0
PROVIDER_PREFERENCE=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "OLLAMA=\$OLLAMA_MODEL"
echo "OPENAI=\$OPENAI_MODEL"
echo "CLAUDE=\$CLAUDE_MODEL"
echo "CURRENCY=\$BASE_CURRENCY"
echo "PREF=\${PROVIDER_PREFERENCE[*]}"
SCRIPT
chmod +x "$TEMP_DIR/test_user_override.sh"

result=$("$TEMP_DIR/test_user_override.sh" 2>/dev/null)

ollama_loaded=$(echo "$result" | grep '^OLLAMA=' | cut -d= -f2)
openai_loaded=$(echo "$result" | grep '^OPENAI=' | cut -d= -f2)
claude_loaded=$(echo "$result" | grep '^CLAUDE=' | cut -d= -f2)
currency_loaded=$(echo "$result" | grep '^CURRENCY=' | cut -d= -f2)
pref_loaded=$(echo "$result" | grep '^PREF=' | cut -d= -f2)

assert_eq "User override: ollama model" "user-ollama-override" "$ollama_loaded"
assert_eq "User override: openai model" "user-openai-override" "$openai_loaded"
assert_eq "User override: claude model" "user-claude-override" "$claude_loaded"
assert_eq "User override: currency" "USD" "$currency_loaded"
assert_eq "User override: preference" "claude ollama" "$pref_loaded"

# --- Test 4: Emergency fallback when config.example.yaml missing ---
echo "--- Emergency fallback when no config files found ---"
echo ""

cat > "$TEMP_DIR/test_emergency.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/nonexistent_user_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$TEMP_DIR/nonexistent_share"

PROMPT_TEMPLATE=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE=(ollama openai claude)

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "OLLAMA=\$OLLAMA_MODEL"
echo "OPENAI=\$OPENAI_MODEL"
echo "PROMPT_SET=\$(if [[ -n "\$PROMPT_TEMPLATE" ]]; then echo yes; else echo no; fi)"
SCRIPT
chmod +x "$TEMP_DIR/test_emergency.sh"

result=$("$TEMP_DIR/test_emergency.sh" 2>/dev/null)

ollama_loaded=$(echo "$result" | grep '^OLLAMA=' | cut -d= -f2)
openai_loaded=$(echo "$result" | grep '^OPENAI=' | cut -d= -f2)
prompt_set=$(echo "$result" | grep '^PROMPT_SET=' | cut -d= -f2)

# Emergency fallback should still provide working values
assert_eq "Emergency fallback: ollama model" "smart-rename" "$ollama_loaded"
assert_eq "Emergency fallback: openai model" "gpt-4o" "$openai_loaded"
assert_eq "Emergency fallback: prompt is set" "yes" "$prompt_set"

# --- Test 5: Partial user config only overrides specified fields ---
echo "--- Partial user config preserves example defaults for unset fields ---"
echo ""

cat > "$TEMP_DIR/partial_config.yaml" <<'YAML'
api:
  ollama:
    model: custom-local-model
YAML

cat > "$TEMP_DIR/test_partial.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/partial_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

PROMPT_TEMPLATE=""
BASE_CURRENCY="EMERGENCY"
OLLAMA_MODEL="emergency-model"
OPENAI_MODEL="emergency-model"
CLAUDE_MODEL="emergency-model"
MAX_CONTENT_LENGTH=0
API_TIMEOUT=0
PROVIDER_PREFERENCE=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "OLLAMA=\$OLLAMA_MODEL"
echo "OPENAI=\$OPENAI_MODEL"
echo "CLAUDE=\$CLAUDE_MODEL"
echo "CURRENCY=\$BASE_CURRENCY"
SCRIPT
chmod +x "$TEMP_DIR/test_partial.sh"

result=$("$TEMP_DIR/test_partial.sh" 2>/dev/null)

ollama_loaded=$(echo "$result" | grep '^OLLAMA=' | cut -d= -f2)
openai_loaded=$(echo "$result" | grep '^OPENAI=' | cut -d= -f2)
claude_loaded=$(echo "$result" | grep '^CLAUDE=' | cut -d= -f2)
currency_loaded=$(echo "$result" | grep '^CURRENCY=' | cut -d= -f2)

# Ollama overridden by user, others should come from config.example.yaml
assert_eq "Partial: ollama model from user config" "custom-local-model" "$ollama_loaded"
assert_eq "Partial: openai model from example (not overridden)" "$openai_example" "$openai_loaded"
assert_eq "Partial: claude model from example (not overridden)" "$claude_example" "$claude_loaded"
assert_eq "Partial: currency from example (not overridden)" "$currency_example" "$currency_loaded"

# --- Test 6: No hardcoded model defaults in summarize-text-lib.sh ---
echo "--- Checking summarize-text-lib.sh has no hardcoded model defaults ---"
echo ""

if [[ -f "$PROJECT_ROOT/summarize-text-lib.sh" ]]; then
    lib_openai=$(grep '^\s*openai_model=' "$PROJECT_ROOT/summarize-text-lib.sh" | head -1 | sed 's/.*=//')
    assert_eq "summarize-text-lib.sh openai_model initialized empty" '""' "$lib_openai"

    lib_claude=$(grep '^\s*claude_model=' "$PROJECT_ROOT/summarize-text-lib.sh" | head -1 | sed 's/.*=//')
    assert_eq "summarize-text-lib.sh claude_model initialized empty" '""' "$lib_claude"

    lib_ollama=$(grep '^\s*ollama_model=' "$PROJECT_ROOT/summarize-text-lib.sh" | head -1 | sed 's/.*=//')
    assert_eq "summarize-text-lib.sh ollama_model initialized empty" '""' "$lib_ollama"
else
    echo "SKIP: summarize-text-lib.sh not found (may have been removed)"
    echo ""
fi

# Summary
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
