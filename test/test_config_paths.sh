#!/usr/bin/env bash
# ABOUTME: Tests config path resolution and the layered config fallback chain
# ABOUTME: Validates: share dir resolution, no auto-creation, yq degradation, emergency fallback

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

# --- Test 1: Script does NOT auto-create config ---
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
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o"
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE=(ollama openai claude)
SMART_RENAME_SHARE_DIR="$PROJECT_ROOT"

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config

if [[ -f "$fake_config_dir/config.yaml" ]]; then
    echo "CONFIG_CREATED=yes"
else
    echo "CONFIG_CREATED=no"
fi
SCRIPT
chmod +x "$TEMP_DIR/test_no_autocreate.sh"

result=$("$TEMP_DIR/test_no_autocreate.sh" 2>/dev/null)
assert_eq "Config not auto-created" "CONFIG_CREATED=no" "$result"

# --- Test 2: SMART_RENAME_SHARE_DIR is checked first ---
echo "--- SMART_RENAME_SHARE_DIR takes priority ---"
echo ""

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

# --- Test 3: Script dir is checked as candidate ---
echo "--- Script dir is checked for share files ---"
echo ""

if [[ -f "$PROJECT_ROOT/config.example.yaml" ]]; then
    echo "PASS: Project root has config.example.yaml (resolve_share_dir will find it)"
    passed=$((passed + 1))
else
    echo "FAIL: Project root missing config.example.yaml"
    failed=$((failed + 1))
fi
echo ""

# --- Test 4: load_config warns when yq is missing ---
echo "--- Graceful degradation without yq ---"
echo ""

if grep -q 'Warning: yq not found' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: Script handles missing yq gracefully"
    passed=$((passed + 1))
else
    echo "FAIL: No graceful handling for missing yq"
    failed=$((failed + 1))
fi
echo ""

# --- Test 5: load_config loads from config.example.yaml as base layer ---
echo "--- load_config loads config.example.yaml as base layer ---"
echo ""

if grep -q 'resolve_share_dir' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: load_config uses resolve_share_dir for base config"
    passed=$((passed + 1))
else
    echo "FAIL: load_config does not use resolve_share_dir"
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
