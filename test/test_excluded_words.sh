#!/usr/bin/env bash
# ABOUTME: Tests excluded_words config feature — suppresses specific words from AI-generated filenames
# ABOUTME: Validates config loading, prompt modification logic, and no-op behaviour when list is empty

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

pass_if() {
    local test_name="$1"
    local condition="$2"

    if [[ "$condition" == "true" ]]; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        failed=$((failed + 1))
    fi
    echo ""
}

echo "=== Testing excluded_words config feature ==="
echo ""

fake_share="$TEMP_DIR/share"
mkdir -p "$fake_share"
cp "$PROJECT_ROOT/config.example.yaml" "$fake_share/"

# --- RT-34.1: Non-empty excluded_words list populates EXCLUDED_WORDS ---
echo "--- RT-34.1: Non-empty excluded_words populates EXCLUDED_WORDS ---"
echo ""

if ! command -v yq >/dev/null 2>&1; then
    echo "SKIP: yq not available, skipping YAML config tests"
    echo ""
else
    # Single word
    cat > "$TEMP_DIR/single_word_config.yaml" <<'YAML'
excluded_words:
  - paul
YAML

    cat > "$TEMP_DIR/test_single_word.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/single_word_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

PROMPT_TEMPLATE=""
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o-mini"
CLAUDE_MODEL="claude-haiku-4-5-20251001"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)
PROVIDER_PREFERENCE_NAME=(openai claude ollama)
EXCLUDED_WORDS=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "COUNT=\${#EXCLUDED_WORDS[@]}"
echo "WORD0=\${EXCLUDED_WORDS[0]:-}"
SCRIPT
    chmod +x "$TEMP_DIR/test_single_word.sh"

    result=$("$TEMP_DIR/test_single_word.sh" 2>/dev/null)
    count=$(echo "$result" | grep '^COUNT=' | cut -d= -f2)
    word0=$(echo "$result" | grep '^WORD0=' | cut -d= -f2)

    assert_eq "RT-34.1: single excluded_word loads one entry" "1" "$count"
    assert_eq "RT-34.1: single excluded_word value is correct" "paul" "$word0"

    # Multiple words
    cat > "$TEMP_DIR/multi_word_config.yaml" <<'YAML'
excluded_words:
  - paul
  - smith
  - acme
YAML

    cat > "$TEMP_DIR/test_multi_word.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/multi_word_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

PROMPT_TEMPLATE=""
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o-mini"
CLAUDE_MODEL="claude-haiku-4-5-20251001"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)
PROVIDER_PREFERENCE_NAME=(openai claude ollama)
EXCLUDED_WORDS=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "COUNT=\${#EXCLUDED_WORDS[@]}"
echo "WORDS=\${EXCLUDED_WORDS[*]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_multi_word.sh"

    result=$("$TEMP_DIR/test_multi_word.sh" 2>/dev/null)
    count=$(echo "$result" | grep '^COUNT=' | cut -d= -f2)
    words=$(echo "$result" | grep '^WORDS=' | cut -d= -f2)

    assert_eq "RT-34.1: multiple excluded_words loads correct count" "3" "$count"
    assert_eq "RT-34.1: multiple excluded_words loads all values" "paul smith acme" "$words"

    # --- RT-34.2: Absent or empty excluded_words leaves EXCLUDED_WORDS empty ---
    echo "--- RT-34.2: Absent/empty excluded_words leaves EXCLUDED_WORDS empty ---"
    echo ""

    cat > "$TEMP_DIR/no_excluded_config.yaml" <<'YAML'
api:
  ollama:
    model: test-model
YAML

    cat > "$TEMP_DIR/test_no_excluded.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/no_excluded_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

PROMPT_TEMPLATE=""
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o-mini"
CLAUDE_MODEL="claude-haiku-4-5-20251001"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)
PROVIDER_PREFERENCE_NAME=(openai claude ollama)
EXCLUDED_WORDS=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "COUNT=\${#EXCLUDED_WORDS[@]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_no_excluded.sh"

    result=$("$TEMP_DIR/test_no_excluded.sh" 2>/dev/null)
    count=$(echo "$result" | grep '^COUNT=' | cut -d= -f2)
    assert_eq "RT-34.2: absent excluded_words key leaves EXCLUDED_WORDS empty" "0" "$count"

    cat > "$TEMP_DIR/empty_excluded_config.yaml" <<'YAML'
excluded_words: []
YAML

    cat > "$TEMP_DIR/test_empty_excluded.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$TEMP_DIR/empty_excluded_config.yaml"
CONFIG_DIR="$TEMP_DIR"
SMART_RENAME_SHARE_DIR="$fake_share"

PROMPT_TEMPLATE=""
CLASSIFY_PROMPT=""
RECEIPT_PROMPT=""
BASE_CURRENCY="EUR"
OLLAMA_MODEL="smart-rename"
OPENAI_MODEL="gpt-4o-mini"
CLAUDE_MODEL="claude-haiku-4-5-20251001"
MAX_CONTENT_LENGTH=5000
API_TIMEOUT=30
PROVIDER_PREFERENCE_CLASSIFY=(ollama openai claude)
PROVIDER_PREFERENCE_NAME=(openai claude ollama)
EXCLUDED_WORDS=()

eval "\$(sed -n '/^_load_yaml_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^resolve_share_dir()/,/^}/p' "$PROJECT_ROOT/smart-rename")"
eval "\$(sed -n '/^load_config()/,/^}/p' "$PROJECT_ROOT/smart-rename")"

load_config
echo "COUNT=\${#EXCLUDED_WORDS[@]}"
SCRIPT
    chmod +x "$TEMP_DIR/test_empty_excluded.sh"

    result=$("$TEMP_DIR/test_empty_excluded.sh" 2>/dev/null)
    count=$(echo "$result" | grep '^COUNT=' | cut -d= -f2)
    assert_eq "RT-34.2: empty excluded_words sequence leaves EXCLUDED_WORDS empty" "0" "$count"
fi

# --- RT-34.3: Exclusion instruction appended in process_file when EXCLUDED_WORDS non-empty ---
echo "--- RT-34.3: process_file appends exclusion instruction when EXCLUDED_WORDS non-empty ---"
echo ""

# Structural check: conditional guard on EXCLUDED_WORDS array length
has_length_check=false
if grep -qE '\$\{#EXCLUDED_WORDS\[@\]\}' "$PROJECT_ROOT/smart-rename" 2>/dev/null; then
    has_length_check=true
fi
pass_if "RT-34.3: Script checks EXCLUDED_WORDS array length" "$has_length_check"

# Structural check: exclusion instruction text specific to excluded_words feature
# (avoids matching "Do NOT include a currency code" in the receipt prompt)
has_instruction_text=false
if grep -qiE 'following words in the filename|do not include.*following words' "$PROJECT_ROOT/smart-rename" 2>/dev/null; then
    has_instruction_text=true
fi
pass_if "RT-34.3: Script contains exclusion instruction text" "$has_instruction_text"

# Structural check: EXCLUDED_WORDS array elements joined into prompt
has_array_expansion=false
if grep -qE 'EXCLUDED_WORDS\[(\*|@)\]' "$PROJECT_ROOT/smart-rename" 2>/dev/null; then
    has_array_expansion=true
fi
pass_if "RT-34.3: Script expands EXCLUDED_WORDS array to build word list" "$has_array_expansion"

# --- RT-34.4: Instruction appended after naming_template selection (covers both prompt types) ---
echo "--- RT-34.4: Exclusion appended after naming_template set (covers template and receipt) ---"
echo ""

# Find line numbers — use || true so set -e doesn't fire on no-match
naming_line=$(grep -n 'local naming_template' "$PROJECT_ROOT/smart-rename" 2>/dev/null | head -1 | cut -d: -f1 || true)
excluded_line=$(grep -nE 'EXCLUDED_WORDS\[(\*|@)\]' "$PROJECT_ROOT/smart-rename" 2>/dev/null | head -1 | cut -d: -f1 || true)
# Use the naming call specifically (uses $prompt, not $classify_prompt)
ai_call_line=$(grep -n 'get_ai_response.*"\$prompt"' "$PROJECT_ROOT/smart-rename" 2>/dev/null | head -1 | cut -d: -f1 || true)

if [[ -z "$naming_line" || -z "$excluded_line" || -z "$ai_call_line" ]]; then
    echo "FAIL: RT-34.4: Could not locate all required elements"
    echo "      naming_template declaration: line ${naming_line:-not found}"
    echo "      EXCLUDED_WORDS expansion:    line ${excluded_line:-not found}"
    echo "      get_ai_response call:        line ${ai_call_line:-not found}"
    failed=$((failed + 1))
    echo ""
else
    ordered=false
    if [[ "$naming_line" -lt "$excluded_line" && "$excluded_line" -lt "$ai_call_line" ]]; then
        ordered=true
    fi
    if [[ "$ordered" == "true" ]]; then
        echo "PASS: RT-34.4: Exclusion append is after naming_template (line $naming_line) and before get_ai_response (line $ai_call_line)"
        passed=$((passed + 1))
    else
        echo "FAIL: RT-34.4: Incorrect ordering — naming_template: line $naming_line, EXCLUDED_WORDS: line $excluded_line, get_ai_response: line $ai_call_line"
        failed=$((failed + 1))
    fi
    echo ""
fi

# --- RT-34.5: No exclusion instruction added when EXCLUDED_WORDS is empty ---
echo "--- RT-34.5: No exclusion instruction added when EXCLUDED_WORDS is empty ---"
echo ""

# Structural: the append must be inside a conditional block
has_conditional=false
if grep -qE 'if \[\[.*\$\{#EXCLUDED_WORDS\[@\]\}.*-gt.*0|if \[\[.*EXCLUDED_WORDS' "$PROJECT_ROOT/smart-rename" 2>/dev/null; then
    has_conditional=true
fi
pass_if "RT-34.5: Exclusion append is guarded by a conditional on EXCLUDED_WORDS" "$has_conditional"

# Summary
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
