#!/usr/bin/env bash
# ABOUTME: Tests two-step classify-then-name flow for document processing
# ABOUTME: Validates classification prompt, receipt prompt, and dispatch logic

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

assert_not_empty() {
    local test_name="$1"
    local actual="$2"

    if [[ -n "$actual" ]]; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Expected: non-empty value"
        echo "      Got:      (empty)"
        failed=$((failed + 1))
    fi
    echo ""
}

assert_contains() {
    local test_name="$1"
    local pattern="$2"
    local text="$3"

    if echo "$text" | grep -qiE "$pattern"; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Expected to match: $pattern"
        echo "      In: $text"
        failed=$((failed + 1))
    fi
    echo ""
}

echo "=== Testing two-step classification ==="
echo ""

# --- Test 1: config.example.yaml has classification prompt ---
echo "--- config.example.yaml has classify and receipt prompts ---"
echo ""

if command -v yq >/dev/null 2>&1; then
    classify_prompt=$(yq eval '.prompt.classify // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    assert_not_empty "config.example.yaml has prompt.classify" "$classify_prompt"

    receipt_prompt=$(yq eval '.prompt.receipt // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    assert_not_empty "config.example.yaml has prompt.receipt" "$receipt_prompt"

    template_prompt=$(yq eval '.prompt.template // ""' "$PROJECT_ROOT/config.example.yaml" 2>/dev/null)
    assert_not_empty "config.example.yaml still has prompt.template (general naming)" "$template_prompt"

    # Classification prompt should list categories
    assert_contains "Classify prompt lists categories" "receipt.*invoice|invoice.*receipt" "$classify_prompt"
    assert_contains "Classify prompt mentions medical" "medical" "$classify_prompt"
    assert_contains "Classify prompt says output only category" "ONLY.*category|only.*category" "$classify_prompt"

    # Receipt prompt should have amount format
    assert_contains "Receipt prompt has amount format" "amount|AMOUNT" "$receipt_prompt"
    assert_contains "Receipt prompt has decimal places" "decimal" "$receipt_prompt"

    # General template should NOT mention receipt/invoice format
    if echo "$template_prompt" | grep -qi "YYYY-MM-DD-amount\|amount\.cc\|decimal places"; then
        echo "FAIL: General template should NOT contain receipt format patterns"
        failed=$((failed + 1))
    else
        echo "PASS: General template does not contain receipt format patterns"
        passed=$((passed + 1))
    fi
    echo ""
else
    echo "SKIP: yq not available"
    echo ""
fi

# --- Test 2: Script has CLASSIFY_PROMPT and RECEIPT_PROMPT globals ---
echo "--- Script has classify and receipt prompt globals ---"
echo ""

if grep -q '^CLASSIFY_PROMPT=' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: Script has CLASSIFY_PROMPT global"
    passed=$((passed + 1))
else
    echo "FAIL: Script should have CLASSIFY_PROMPT global"
    failed=$((failed + 1))
fi
echo ""

if grep -q '^RECEIPT_PROMPT=' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: Script has RECEIPT_PROMPT global"
    passed=$((passed + 1))
else
    echo "FAIL: Script should have RECEIPT_PROMPT global"
    failed=$((failed + 1))
fi
echo ""

# --- Test 3: _load_yaml_config reads classify and receipt prompts ---
echo "--- _load_yaml_config reads new prompt keys ---"
echo ""

if grep -q 'prompt.classify' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: _load_yaml_config reads prompt.classify"
    passed=$((passed + 1))
else
    echo "FAIL: _load_yaml_config should read prompt.classify"
    failed=$((failed + 1))
fi
echo ""

if grep -q 'prompt.receipt' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: _load_yaml_config reads prompt.receipt"
    passed=$((passed + 1))
else
    echo "FAIL: _load_yaml_config should read prompt.receipt"
    failed=$((failed + 1))
fi
echo ""

# --- Test 4: process_file has classification step ---
echo "--- process_file has classification step ---"
echo ""

if grep -q 'CLASSIFY_PROMPT' "$PROJECT_ROOT/smart-rename" | grep -v '^#' >/dev/null 2>&1 || grep -q 'classify' "$PROJECT_ROOT/smart-rename"; then
    # Check for the classification dispatch logic
    if grep -q 'receipt\|invoice' "$PROJECT_ROOT/smart-rename" | grep -q 'RECEIPT_PROMPT' 2>/dev/null || grep -qE 'category.*(receipt|invoice)' "$PROJECT_ROOT/smart-rename"; then
        echo "PASS: process_file dispatches receipt vs general based on category"
        passed=$((passed + 1))
    else
        echo "FAIL: process_file should dispatch to receipt prompt based on category"
        failed=$((failed + 1))
    fi
else
    echo "FAIL: process_file should have a classification step using CLASSIFY_PROMPT"
    failed=$((failed + 1))
fi
echo ""

# --- Test 5: Loaded classify/receipt prompts from config ---
echo "--- load_config populates classify and receipt prompts ---"
echo ""

if command -v yq >/dev/null 2>&1; then
    fake_share="$TEMP_DIR/share"
    mkdir -p "$fake_share"
    cp "$PROJECT_ROOT/config.example.yaml" "$fake_share/"

    cat > "$TEMP_DIR/test_classify_load.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/nonexistent.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

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

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
if [[ -n "\$CLASSIFY_PROMPT" ]]; then
    echo "CLASSIFY=loaded"
else
    echo "CLASSIFY=empty"
fi
if [[ -n "\$RECEIPT_PROMPT" ]]; then
    echo "RECEIPT=loaded"
else
    echo "RECEIPT=empty"
fi
SCRIPT
    chmod +x "$TEMP_DIR/test_classify_load.sh"

    result=$("$TEMP_DIR/test_classify_load.sh" 2>/dev/null)
    classify_status=$(echo "$result" | grep '^CLASSIFY=' | cut -d= -f2)
    receipt_status=$(echo "$result" | grep '^RECEIPT=' | cut -d= -f2)

    assert_eq "load_config populates CLASSIFY_PROMPT from config.example.yaml" "loaded" "$classify_status"
    assert_eq "load_config populates RECEIPT_PROMPT from config.example.yaml" "loaded" "$receipt_status"
else
    echo "SKIP: yq not available"
    echo ""
fi

# --- Test 6: Modelfile SYSTEM prompt is generic (no receipt mention) ---
echo "--- Modelfile SYSTEM prompt is generic ---"
echo ""

modelfile_system=$(sed -n '/^SYSTEM """/,/"""/p' "$PROJECT_ROOT/smart-rename.Modelfile")

if echo "$modelfile_system" | grep -qi "receipt\|invoice\|amount\|decimal"; then
    echo "FAIL: Modelfile SYSTEM prompt should NOT mention receipts/invoices/amounts"
    echo "      The receipt pattern should only appear in the per-call prompt"
    failed=$((failed + 1))
else
    echo "PASS: Modelfile SYSTEM prompt is generic (no receipt/invoice/amount mention)"
    passed=$((passed + 1))
fi
echo ""

# --- Test 7: Category validation ---
echo "--- Category validation in script ---"
echo ""

# The script should validate the classification response against an allowlist
if grep -qE 'receipt\|invoice\|letter\|report\|medical' "$PROJECT_ROOT/smart-rename" || \
   grep -qE 'VALID_CATEGORIES\|valid_categories\|known_categories' "$PROJECT_ROOT/smart-rename"; then
    echo "PASS: Script validates classification against known categories"
    passed=$((passed + 1))
else
    echo "FAIL: Script should validate classification response against known categories"
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
