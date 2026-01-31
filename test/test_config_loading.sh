#!/usr/bin/env bash
# ABOUTME: Tests that model defaults come from config.yaml, not hardcoded in scripts
# ABOUTME: Validates config loading, auto-creation, and model variable population

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
        ((passed++)) || true
    else
        echo "FAIL: $test_name"
        echo "      Expected: $expected"
        echo "      Got:      $actual"
        ((failed++)) || true
    fi
    echo ""
}

assert_not_empty() {
    local test_name="$1"
    local actual="$2"

    if [[ -n "$actual" ]]; then
        echo "PASS: $test_name (value: $actual)"
        ((passed++)) || true
    else
        echo "FAIL: $test_name"
        echo "      Expected: non-empty value"
        echo "      Got:      (empty)"
        ((failed++)) || true
    fi
    echo ""
}

echo "=== Testing config-based model loading ==="
echo ""

# --- Test 1: No hardcoded model defaults in smart-rename script ---
echo "--- Checking smart-rename has no hardcoded model defaults ---"
echo ""

# Check that OPENAI_MODEL is initialized empty
openai_default=$(grep '^OPENAI_MODEL=' "$PROJECT_ROOT/smart-rename" | head -1)
assert_eq "OPENAI_MODEL initialized empty" 'OPENAI_MODEL=""' "$openai_default"

# Check that CLAUDE_MODEL is initialized empty
claude_default=$(grep '^CLAUDE_MODEL=' "$PROJECT_ROOT/smart-rename" | head -1)
assert_eq "CLAUDE_MODEL initialized empty" 'CLAUDE_MODEL=""' "$claude_default"

# Check that OLLAMA_MODEL is initialized empty (strip any trailing comment)
ollama_default=$(grep '^OLLAMA_MODEL=' "$PROJECT_ROOT/smart-rename" | head -1 | sed 's/[[:space:]]*#.*//')
assert_eq "OLLAMA_MODEL initialized empty" 'OLLAMA_MODEL=""' "$ollama_default"

# --- Test 2: Config files contain model defaults ---
echo "--- Checking config files define model defaults ---"
echo ""

# Requires yq
if ! command -v yq >/dev/null 2>&1; then
    echo "SKIP: yq not available, skipping YAML config tests"
    echo ""
else
    # Check config.yaml
    openai_config=$(yq eval '.api.openai.model // ""' "$PROJECT_ROOT/config.yaml" 2>/dev/null)
    assert_not_empty "config.yaml defines openai model" "$openai_config"

    claude_config=$(yq eval '.api.claude.model // ""' "$PROJECT_ROOT/config.yaml" 2>/dev/null)
    assert_not_empty "config.yaml defines claude model" "$claude_config"

    ollama_config=$(yq eval '.api.ollama.model // ""' "$PROJECT_ROOT/config.yaml" 2>/dev/null)
    assert_not_empty "config.yaml defines ollama model" "$ollama_config"

    # Check config.example.yaml
    openai_example=$(yq eval '.api.openai.model // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    assert_not_empty "config.example.yaml defines openai model" "$openai_example"

    claude_example=$(yq eval '.api.claude.model // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    assert_not_empty "config.example.yaml defines claude model" "$claude_example"

    ollama_example=$(yq eval '.api.ollama.model // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    assert_not_empty "config.example.yaml defines ollama model" "$ollama_example"

    # --- Test 3: Config files are consistent with each other ---
    echo "--- Checking config files are consistent ---"
    echo ""

    assert_eq "openai model consistent across configs" "$openai_config" "$openai_example"
    assert_eq "claude model consistent across configs" "$claude_config" "$claude_example"
    assert_eq "ollama model consistent across configs" "$ollama_config" "$ollama_example"

    # --- Test 4: load_config reads models from YAML ---
    echo "--- Testing load_config reads from YAML ---"
    echo ""

    # Create a test config with custom model values
    cat > "$TEMP_DIR/test_config.yaml" <<'YAML'
api:
  openai:
    model: test-openai-model
  claude:
    model: test-claude-model
  ollama:
    model: test-ollama-model
YAML

    # Create a temp test script that exercises load_config with our test config
    cat > "$TEMP_DIR/test_load.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/test_config.yaml"
CONFIG_DIR="$TEMP_DIR"
OPENAI_MODEL=""
CLAUDE_MODEL=""
OLLAMA_MODEL=""
PROMPT_TEMPLATE=""
BASE_CURRENCY="EUR"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30

# Extract load_config function from smart-rename
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "OPENAI=\$OPENAI_MODEL"
echo "CLAUDE=\$CLAUDE_MODEL"
echo "OLLAMA=\$OLLAMA_MODEL"
SCRIPT
    chmod +x "$TEMP_DIR/test_load.sh"

    result=$("$TEMP_DIR/test_load.sh" 2>/dev/null)

    openai_loaded=$(echo "$result" | grep '^OPENAI=' | cut -d= -f2)
    claude_loaded=$(echo "$result" | grep '^CLAUDE=' | cut -d= -f2)
    ollama_loaded=$(echo "$result" | grep '^OLLAMA=' | cut -d= -f2)

    assert_eq "load_config reads openai model from YAML" "test-openai-model" "$openai_loaded"
    assert_eq "load_config reads claude model from YAML" "test-claude-model" "$claude_loaded"
    assert_eq "load_config reads ollama model from YAML" "test-ollama-model" "$ollama_loaded"
fi

# --- Test 5: No hardcoded model defaults in summarize-text-lib.sh ---
echo "--- Checking summarize-text-lib.sh has no hardcoded model defaults ---"
echo ""

# The defaults in load_config should be empty strings
# Look for the defaults section in load_config function
lib_openai=$(grep '^\s*openai_model=' "$PROJECT_ROOT/summarize-text-lib.sh" | head -1 | sed 's/.*=//')
assert_eq "summarize-text-lib.sh openai_model initialized empty" '""' "$lib_openai"

lib_claude=$(grep '^\s*claude_model=' "$PROJECT_ROOT/summarize-text-lib.sh" | head -1 | sed 's/.*=//')
assert_eq "summarize-text-lib.sh claude_model initialized empty" '""' "$lib_claude"

lib_ollama=$(grep '^\s*ollama_model=' "$PROJECT_ROOT/summarize-text-lib.sh" | head -1 | sed 's/.*=//')
assert_eq "summarize-text-lib.sh ollama_model initialized empty" '""' "$lib_ollama"

# Summary
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
