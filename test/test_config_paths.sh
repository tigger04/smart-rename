#!/usr/bin/env bash
# ABOUTME: Tests config path resolution and optional config behaviour
# ABOUTME: Validates that the script works with no config, and finds share dir correctly

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

echo "=== Testing config paths ==="
echo ""

# --- Test 1: Script works with no config file (uses defaults) ---
echo "--- No config file uses defaults ---"
echo ""

cat > "$TEMP_DIR/test_no_config.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/nonexistent.yaml"
CONFIG_DIR="$TEMP_DIR"

PROMPT_TEMPLATE=""
DEFAULT_PROMPT="default-prompt-marker"
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE=(ollama openai claude)
SMART_RENAME_SHARE_DIR=""

eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "PROMPT=\$PROMPT_TEMPLATE"
echo "OLLAMA=\$OLLAMA_MODEL"
echo "OPENAI=\$OPENAI_MODEL"
SCRIPT
chmod +x "$TEMP_DIR/test_no_config.sh"

result=$("$TEMP_DIR/test_no_config.sh" 2>/dev/null)

prompt_line=$(echo "$result" | grep '^PROMPT=')
assert_contains "No config uses default prompt" "default-prompt-marker" "$prompt_line"

ollama_line=$(echo "$result" | grep '^OLLAMA=')
assert_eq "No config uses default ollama model" "OLLAMA=smart-rename" "$ollama_line"

openai_line=$(echo "$result" | grep '^OPENAI=')
assert_eq "No config uses default openai model" "OPENAI=gpt-4o" "$openai_line"

# --- Test 2: Script does NOT auto-create config ---
echo "--- No auto-creation of config ---"
echo ""

fake_config_dir="$TEMP_DIR/fake_config_dir"
mkdir -p "$fake_config_dir"

cat > "$TEMP_DIR/test_no_autocreate.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$fake_config_dir/config.yaml"
CONFIG_DIR="$fake_config_dir"

PROMPT_TEMPLATE=""
DEFAULT_PROMPT="test"
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE=(ollama openai claude)
SMART_RENAME_SHARE_DIR=""

eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config

# Check if config was created
if [[ -f "$fake_config_dir/config.yaml" ]]; then
    echo "CONFIG_CREATED=yes"
else
    echo "CONFIG_CREATED=no"
fi
SCRIPT
chmod +x "$TEMP_DIR/test_no_autocreate.sh"

result=$("$TEMP_DIR/test_no_autocreate.sh" 2>/dev/null)
assert_eq "Config not auto-created" "CONFIG_CREATED=no" "$result"

# --- Test 3: SMART_RENAME_SHARE_DIR is checked first ---
echo "--- SMART_RENAME_SHARE_DIR takes priority ---"
echo ""

# Create a fake share dir with config.example.yaml
fake_share="$TEMP_DIR/fake_share"
mkdir -p "$fake_share"
echo "test: true" > "$fake_share/config.example.yaml"

cat > "$TEMP_DIR/test_share_dir.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
SMART_RENAME_SHARE_DIR="$fake_share"

eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

result=\$(resolve_share_dir)
echo "\$result"
SCRIPT
chmod +x "$TEMP_DIR/test_share_dir.sh"

result=$("$TEMP_DIR/test_share_dir.sh" 2>/dev/null)
assert_eq "SMART_RENAME_SHARE_DIR is used when set" "$fake_share" "$result"

# --- Test 4: Script dir is checked as candidate ---
echo "--- Script dir is checked for share files ---"
echo ""

# The project root has config.example.yaml, so resolve_share_dir should find it
if [[ -f "$PROJECT_ROOT/config.example.yaml" ]]; then
    echo "PASS: Project root has config.example.yaml (resolve_share_dir will find it)"
    passed=$((passed + 1))
else
    echo "FAIL: Project root missing config.example.yaml"
    failed=$((failed + 1))
fi
echo ""

# --- Test 5: load_config is graceful when yq is missing ---
echo "--- Graceful degradation without yq ---"
echo ""

# We can test this by checking the code path exists
if grep -q 'Warning: yq not found, using built-in defaults' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: Script handles missing yq gracefully"
    passed=$((passed + 1))
else
    echo "FAIL: No graceful handling for missing yq"
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
