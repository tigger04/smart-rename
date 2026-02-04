#!/usr/bin/env bash
# ABOUTME: Tests error handling and reporting in batch file processing
# ABOUTME: Covers Fixes #32: silent termination, error tracking, summary output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT="$PROJECT_ROOT/smart-rename"

passed=0
failed=0

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

echo "=== Testing error handling ==="
echo ""

# =====================================================
# Issue #32: Single file path has error handling
# =====================================================
echo "--- #32: Single file path error handling ---"
echo ""

# Test: process_file in single file path is wrapped with if !
script_content=$(cat "$SCRIPT")

assert_not_contains \
    "Single file path does not use bare process_file call" \
    $'if [[ -f "$PATTERN" ]]; then\n        # Single file mode\n        process_file "$PATTERN"' \
    "$script_content"

assert_contains \
    "Single file path uses if ! process_file for error handling" \
    'if ! process_file "$PATTERN"' \
    "$script_content"

# =====================================================
# Issue #32: Batch path does not use || true
# =====================================================
echo "--- #32: Batch path error handling ---"
echo ""

assert_not_contains \
    "Batch path does not use || true" \
    'process_file "$file" || true' \
    "$script_content"

assert_contains \
    "Batch path uses if ! process_file for error handling" \
    'if ! process_file "$file"' \
    "$script_content"

# =====================================================
# Issue #32: Error tracking variables exist
# =====================================================
echo "--- #32: Error tracking ---"
echo ""

assert_contains \
    "Script initialises failed_files array" \
    "failed_files=()" \
    "$script_content"

assert_contains \
    "Script initialises success_count" \
    "success_count=0" \
    "$script_content"

assert_contains \
    "Script initialises total_count" \
    "total_count=0" \
    "$script_content"

assert_contains \
    "Failed files are tracked in single file path" \
    'failed_files+=("$PATTERN")' \
    "$script_content"

assert_contains \
    "Failed files are tracked in batch path" \
    'failed_files+=("$file")' \
    "$script_content"

# =====================================================
# Issue #32: Summary output
# =====================================================
echo "--- #32: Summary output ---"
echo ""

assert_contains \
    "Script prints summary for multi-file runs" \
    'Processed ${total_count} file(s)' \
    "$script_content"

assert_contains \
    "Summary shows success count" \
    '${success_count} succeeded' \
    "$script_content"

assert_contains \
    "Summary shows failure count" \
    '${#failed_files[@]} failed' \
    "$script_content"

assert_contains \
    "Summary lists failed files" \
    'echo "  - $f" >&2' \
    "$script_content"

# =====================================================
# Issue #32: Verbose error messages in extraction
# =====================================================
echo "--- #32: Verbose error reporting in extraction ---"
echo ""

assert_contains \
    "PDF extraction failure is reported" \
    "pdftotext failed to extract text from" \
    "$script_content"

assert_contains \
    "OCR failure is reported" \
    "OCR (tesseract) failed for" \
    "$script_content"

assert_contains \
    "pdftoppm failure is reported" \
    "PDF page rendering (pdftoppm) failed for" \
    "$script_content"

assert_contains \
    "Missing OCR tools warning" \
    "PDF appears scanned but tesseract/pdftoppm not available" \
    "$script_content"

assert_contains \
    "pandoc failure is reported" \
    "pandoc failed to extract text from" \
    "$script_content"

assert_contains \
    "Empty content message is descriptive" \
    "No readable content could be extracted from" \
    "$script_content"

assert_contains \
    "Empty content suggests possible causes" \
    "empty, corrupted, password-protected" \
    "$script_content"

# =====================================================
# Issue #32: No || true anti-pattern in script
# =====================================================
echo "--- #32: No || true anti-pattern ---"
echo ""

# Count remaining || true instances (should be zero)
or_true_count=$(grep -c '|| true' "$SCRIPT" 2>/dev/null) || or_true_count=0

if [[ "$or_true_count" -eq 0 ]]; then
    echo "PASS: No || true patterns remain in script"
    passed=$((passed + 1))
else
    echo "FAIL: Found $or_true_count || true pattern(s) in script"
    grep -n '|| true' "$SCRIPT" | while read -r line; do
        echo "      $line"
    done
    failed=$((failed + 1))
fi
echo ""

# =====================================================
# Issue #32: API provider error reporting
# =====================================================
echo "--- #32: API provider error reporting ---"
echo ""

assert_contains \
    "Ollama timeout/failure is reported" \
    "Ollama request timed out or failed" \
    "$script_content"

assert_contains \
    "OpenAI API failure is reported" \
    "OpenAI API request failed" \
    "$script_content"

assert_contains \
    "Claude API failure is reported" \
    "Claude API request failed" \
    "$script_content"

# =====================================================
# Summary
# =====================================================
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi

echo "All tests passed!"
