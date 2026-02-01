#!/usr/bin/env bash
# ABOUTME: Tests that the smart-rename.Modelfile exists and has correct structure
# ABOUTME: Validates FROM directive, SYSTEM prompt, and PARAMETER settings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

passed=0
failed=0

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
    local file="$3"

    if grep -q "$expected" "$file"; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Expected file to contain: $expected"
        failed=$((failed + 1))
    fi
    echo ""
}

echo "=== Testing Modelfile ==="
echo ""

MODELFILE="$PROJECT_ROOT/smart-rename.Modelfile"

# --- Test 1: Modelfile exists ---
echo "--- Modelfile exists ---"
echo ""

if [[ -f "$MODELFILE" ]]; then
    echo "PASS: smart-rename.Modelfile exists"
    passed=$((passed + 1))
else
    echo "FAIL: smart-rename.Modelfile not found"
    failed=$((failed + 1))
    echo ""
    echo "=== Summary ==="
    echo "Passed: $passed"
    echo "Failed: $failed"
    exit 1
fi
echo ""

# --- Test 2: Has ABOUTME comments ---
echo "--- Has ABOUTME comments ---"
echo ""
assert_contains "Modelfile has ABOUTME comment" "^# ABOUTME:" "$MODELFILE"

# --- Test 3: FROM directive uses qwen2.5:7b ---
echo "--- FROM directive ---"
echo ""

from_line=$(grep '^FROM ' "$MODELFILE" | head -1)
assert_eq "FROM directive is qwen2.5:7b" "FROM qwen2.5:7b" "$from_line"

# --- Test 4: Has generic SYSTEM prompt (no receipt/amount contamination) ---
echo "--- SYSTEM prompt ---"
echo ""
assert_contains "Has SYSTEM directive" '^SYSTEM """' "$MODELFILE"
assert_contains "System prompt mentions instructions" 'instruction' "$MODELFILE"

# SYSTEM prompt must NOT mention receipts/invoices/amounts — those go in per-call prompts
modelfile_system=$(sed -n '/^SYSTEM """/,/"""/p' "$MODELFILE")
if echo "$modelfile_system" | grep -qi "receipt\|invoice\|amount\|decimal"; then
    echo "FAIL: SYSTEM prompt must NOT mention receipt/invoice/amount (per-call prompts handle this)"
    failed=$((failed + 1))
else
    echo "PASS: SYSTEM prompt is generic — no receipt/amount contamination"
    passed=$((passed + 1))
fi
echo ""

# --- Test 5: Has temperature parameter ---
echo "--- PARAMETER settings ---"
echo ""
assert_contains "Has temperature parameter" '^PARAMETER temperature' "$MODELFILE"
assert_contains "Has num_ctx parameter" '^PARAMETER num_ctx' "$MODELFILE"

# Verify temperature is low (for deterministic output)
temp_line=$(grep '^PARAMETER temperature' "$MODELFILE" | head -1)
assert_eq "Temperature is 0.2" "PARAMETER temperature 0.2" "$temp_line"

# --- Test 6: ensure_custom_model references Modelfile ---
echo "--- ensure_custom_model references Modelfile ---"
echo ""

if grep -q 'smart-rename.Modelfile' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: smart-rename script references smart-rename.Modelfile"
    passed=$((passed + 1))
else
    echo "FAIL: smart-rename script does not reference smart-rename.Modelfile"
    failed=$((failed + 1))
fi
echo ""

# --- Test 7: Default OLLAMA_MODEL matches custom model name ---
echo "--- Default model is smart-rename ---"
echo ""

default_model=$(grep '^OLLAMA_MODEL=' "$PROJECT_ROOT/smart-rename" | head -1)
assert_eq "Default OLLAMA_MODEL is smart-rename" 'OLLAMA_MODEL="smart-rename"' "$default_model"

# --- Test 8: Config example uses smart-rename model ---
echo "--- Config example uses smart-rename model ---"
echo ""

if command -v yq >/dev/null 2>&1; then
    config_model=$(yq eval '.api.ollama.model' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    assert_eq "config.example.yaml ollama model is smart-rename" "smart-rename" "$config_model"
else
    echo "SKIP: yq not available"
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
