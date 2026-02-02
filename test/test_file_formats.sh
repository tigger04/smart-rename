#!/usr/bin/env bash
# ABOUTME: Tests file format support in process_file content extraction
# ABOUTME: Covers PDF OCR fallback, DOCX, XLSX, PPTX, RTF, ODT/ODS/ODP, EML/MSG

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT="$PROJECT_ROOT/smart-rename"

passed=0
failed=0

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

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

echo "=== Testing file format support ==="
echo ""

# =====================================================
# Issue #12: PDF OCR fallback
# =====================================================
echo "--- #12: PDF OCR fallback ---"
echo ""

# Test: Script handles PDF with OCR fallback structure
assert_contains "PDF case handles tesseract fallback" "tesseract" "$(grep -A 30 'pdf)' "$SCRIPT")"
assert_contains "PDF case uses pdftoppm for image conversion" "pdftoppm" "$(grep -A 30 'pdf)' "$SCRIPT")"

# Test: Script checks text quality before falling back to OCR
assert_contains "PDF checks for meaningful text before OCR" "50" "$(grep -A 30 'pdf)' "$SCRIPT")"

# =====================================================
# Issue #4: DOCX/DOC support
# =====================================================
echo "--- #4: DOCX/DOC support ---"
echo ""

# Test: Script recognises doc/docx extensions
assert_contains "Script has docx in case statement" "docx" "$(grep -E '^\s+(doc|docx)' "$SCRIPT")"

# Test: pandoc is used for DOCX extraction
assert_contains "DOCX uses pandoc" "pandoc" "$(grep -A 10 'docx' "$SCRIPT" | head -15)"

# Test: DOCX has a fallback when pandoc unavailable
assert_contains "DOCX has unzip fallback" "unzip" "$(grep -A 20 'docx' "$SCRIPT")"

# Test: Create a real DOCX and verify extraction works
if command -v pandoc >/dev/null 2>&1; then
    echo "Test content for smart-rename DOCX extraction" > "$TEMP_DIR/test_input.md"
    pandoc "$TEMP_DIR/test_input.md" -o "$TEMP_DIR/test.docx" 2>/dev/null
    if [[ -f "$TEMP_DIR/test.docx" ]]; then
        docx_content=$(pandoc --to=plain --wrap=none "$TEMP_DIR/test.docx" 2>/dev/null)
        assert_contains "DOCX extraction yields content" "smart-rename" "$docx_content"
    else
        echo "SKIP: Could not create test DOCX file"
        echo ""
    fi
else
    echo "SKIP: pandoc not available for DOCX integration test"
    echo ""
fi

# =====================================================
# Issue #7: RTF support
# =====================================================
echo "--- #7: RTF support ---"
echo ""

# Test: Script recognises rtf extension
assert_contains "Script has rtf in case statement" "rtf" "$(grep -E '^\s+rtf' "$SCRIPT")"

# Test: pandoc is used for RTF extraction
assert_contains "RTF uses pandoc" "pandoc" "$(grep -B 2 -A 10 'rtf' "$SCRIPT" | head -15)"

# Test: Create a real RTF and verify extraction works
if command -v pandoc >/dev/null 2>&1; then
    # Create a minimal RTF file
    cat > "$TEMP_DIR/test.rtf" <<'RTFEOF'
{\rtf1\ansi
Hello from RTF test document for smart-rename
}
RTFEOF
    rtf_content=$(pandoc --to=plain --wrap=none "$TEMP_DIR/test.rtf" 2>/dev/null)
    assert_contains "RTF extraction yields content" "smart-rename" "$rtf_content"
else
    echo "SKIP: pandoc not available for RTF integration test"
    echo ""
fi

# =====================================================
# Issue #5: XLSX support
# =====================================================
echo "--- #5: XLSX support ---"
echo ""

# Test: Script recognises xlsx extension
assert_contains "Script has xlsx in case statement" "xlsx" "$(grep -E '^\s+xlsx' "$SCRIPT")"

# Test: XLSX has extraction logic
assert_contains "XLSX has extraction logic" "xlsx" "$(grep -B 2 -A 10 'xlsx' "$SCRIPT")"

# =====================================================
# Issue #6: PPTX support
# =====================================================
echo "--- #6: PPTX support ---"
echo ""

# Test: Script recognises pptx extension
assert_contains "Script has pptx in case statement" "pptx" "$(grep -E '^\s+pptx' "$SCRIPT")"

# Test: PPTX has extraction logic
assert_contains "PPTX uses pandoc" "pandoc" "$(grep -B 2 -A 10 'pptx' "$SCRIPT" | head -15)"

# =====================================================
# Issue #8: OpenDocument formats
# =====================================================
echo "--- #8: ODT/ODS/ODP support ---"
echo ""

# Test: Script recognises ODF extensions
assert_contains "Script has odt in case statement" "odt" "$(grep -E '^\s+odt' "$SCRIPT")"
assert_contains "Script has ods in case statement" "ods" "$(grep -E '^\s+od[st]' "$SCRIPT")"
assert_contains "Script has odp in case statement" "odp" "$(grep -E 'odp' "$SCRIPT" | head -1)"

# Test: ODF uses pandoc
assert_contains "ODF uses pandoc" "pandoc" "$(grep -B 2 -A 10 'odt' "$SCRIPT" | head -15)"

# Test: Create a real ODT and verify extraction works
if command -v pandoc >/dev/null 2>&1; then
    echo "Test content for smart-rename ODT extraction" > "$TEMP_DIR/test_input.md"
    pandoc "$TEMP_DIR/test_input.md" -o "$TEMP_DIR/test.odt" 2>/dev/null
    if [[ -f "$TEMP_DIR/test.odt" ]]; then
        odt_content=$(pandoc --to=plain --wrap=none "$TEMP_DIR/test.odt" 2>/dev/null)
        assert_contains "ODT extraction yields content" "smart-rename" "$odt_content"
    else
        echo "SKIP: Could not create test ODT file"
        echo ""
    fi
else
    echo "SKIP: pandoc not available for ODT integration test"
    echo ""
fi

# =====================================================
# Issue #10: Email support (EML, MSG)
# =====================================================
echo "--- #10: EML/MSG support ---"
echo ""

# Test: Script recognises eml extension
assert_contains "Script has eml in case statement" "eml" "$(grep -E '^\s+eml' "$SCRIPT")"

# Test: EML extraction parses headers
assert_contains "EML parses Subject header" "Subject" "$(grep -A 20 'eml' "$SCRIPT")"

# Test: Script recognises msg extension
assert_contains "Script has msg in case statement" "msg" "$(grep -E '^\s+msg' "$SCRIPT")"

# Test: Create a real EML and verify extraction works
cat > "$TEMP_DIR/test.eml" <<'EMLEOF'
From: sender@example.com
To: recipient@example.com
Subject: Smart-rename test email message
Date: Mon, 1 Jan 2024 12:00:00 +0000
Content-Type: text/plain; charset=utf-8

This is the body of the test email for smart-rename extraction testing.
EMLEOF

# Test EML header extraction (grep-based, no external tools needed)
eml_subject=$(grep -i "^Subject:" "$TEMP_DIR/test.eml" | head -1 | sed 's/^Subject: *//i')
assert_eq "EML Subject extraction" "Smart-rename test email message" "$eml_subject"

eml_from=$(grep -i "^From:" "$TEMP_DIR/test.eml" | head -1 | sed 's/^From: *//i')
assert_contains "EML From extraction" "sender@example.com" "$eml_from"

# =====================================================
# General: All new formats are in case statement
# =====================================================
echo "--- General: case statement coverage ---"
echo ""

# Extract the case statement for extensions
case_block=$(sed -n '/case "\$extension" in/,/esac/p' "$SCRIPT")

for ext in pdf docx doc rtf xlsx pptx odt ods odp eml msg; do
    if echo "$case_block" | grep -q "$ext"; then
        echo "PASS: Extension '$ext' handled in case statement"
        passed=$((passed + 1))
    else
        echo "FAIL: Extension '$ext' NOT handled in case statement"
        failed=$((failed + 1))
    fi
    echo ""
done

# =====================================================
# General: pandoc helper or common pattern
# =====================================================
echo "--- General: pandoc usage ---"
echo ""

# pandoc should be referenced in the script for document extraction
pandoc_count=$(grep -c "pandoc" "$SCRIPT")
if [[ "$pandoc_count" -gt 0 ]]; then
    echo "PASS: Script references pandoc ($pandoc_count times)"
    passed=$((passed + 1))
else
    echo "FAIL: Script does not reference pandoc"
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
