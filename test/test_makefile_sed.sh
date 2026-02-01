#!/usr/bin/env bash
# ABOUTME: Tests for Makefile sed patterns used in formula and bump targets
# ABOUTME: Validates that version updates and URL replacements work correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034 # PROJECT_ROOT used for context
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

passed=0
failed=0

# Create temp directory for test files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

test_sed() {
    local test_name="$1"
    local input="$2"
    local sed_pattern="$3"
    local expected="$4"

    echo "$input" > "$TEMP_DIR/test_input"

    # Apply sed (using .bak extension as in actual Makefile)
    sed -i.bak "$sed_pattern" "$TEMP_DIR/test_input"
    rm -f "$TEMP_DIR/test_input.bak"

    local result
    result=$(cat "$TEMP_DIR/test_input")

    if [[ "$result" == "$expected" ]]; then
        echo "PASS: $test_name"
        passed=$((passed + 1))
    else
        echo "FAIL: $test_name"
        echo "      Input:    $input"
        echo "      Pattern:  $sed_pattern"
        echo "      Expected: $expected"
        echo "      Got:      $result"
        failed=$((failed + 1))
    fi
    echo ""
}

echo "=== Testing Makefile sed patterns ==="
echo ""

echo "--- Formula tarball URL update tests ---"
echo ""

# Test: Tarball URL pattern update
test_sed "Formula tarball URL update" \
    'url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.23.0.tar.gz"' \
    's|url "https://github.com/tigger04/smart-rename/archive/refs/tags/v[^"]*\.tar\.gz"|url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.23.1.tar.gz"|' \
    'url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.23.1.tar.gz"'

# Test: Version bump from 5.23.0 to 5.24.0
test_sed "Formula tarball URL version bump (5.23.0 -> 5.24.0)" \
    'url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.23.0.tar.gz"' \
    's|url "https://github.com/tigger04/smart-rename/archive/refs/tags/v[^"]*\.tar\.gz"|url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.24.0.tar.gz"|' \
    'url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.24.0.tar.gz"'

# Test: Major version bump
test_sed "Formula tarball URL major version bump (5.23.1 -> 6.0.0)" \
    'url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.23.1.tar.gz"' \
    's|url "https://github.com/tigger04/smart-rename/archive/refs/tags/v[^"]*\.tar\.gz"|url "https://github.com/tigger04/smart-rename/archive/refs/tags/v6.0.0.tar.gz"|' \
    'url "https://github.com/tigger04/smart-rename/archive/refs/tags/v6.0.0.tar.gz"'

echo "--- Formula SHA256 update tests ---"
echo ""

test_sed "Formula SHA256 update" \
    'sha256 "abc123def456"' \
    's|sha256 "[^"]*"|sha256 "newsha256hash"|' \
    'sha256 "newsha256hash"'

echo "--- Formula version update tests ---"
echo ""

test_sed "Formula version string update" \
    'version "5.23.0"' \
    's|version "[^"]*"|version "5.23.1"|' \
    'version "5.23.1"'

echo "--- Script VERSION bump tests ---"
echo ""

test_sed "Script VERSION bump (patch)" \
    'VERSION="5.23.0"' \
    's/^VERSION="5.23.0"/VERSION="5.23.1"/' \
    'VERSION="5.23.1"'

test_sed "Script VERSION bump (minor)" \
    'VERSION="5.19.9"' \
    's/^VERSION="5.19.9"/VERSION="5.19.10"/' \
    'VERSION="5.19.10"'

echo "--- Full formula file test ---"
echo ""

# Test with a complete mock formula file (tarball format)
MOCK_FORMULA='class SmartRename < Formula
  desc "AI-powered file renaming tool"
  homepage "https://github.com/tigger04/smart-rename"
  url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.23.0.tar.gz"
  sha256 "oldhash123"
  license "MIT"
  version "5.23.0"
end'

echo "$MOCK_FORMULA" > "$TEMP_DIR/mock_formula.rb"

# Apply all three sed patterns as in Makefile
NEW_VERSION="5.23.1"
NEW_SHA="newhash456"
TARBALL_URL="https://github.com/tigger04/smart-rename/archive/refs/tags/v${NEW_VERSION}.tar.gz"

sed -i.bak "s|url \"https://github.com/tigger04/smart-rename/archive/refs/tags/v[^\"]*\.tar\.gz\"|url \"${TARBALL_URL}\"|" "$TEMP_DIR/mock_formula.rb"
sed -i.bak "s|sha256 \"[^\"]*\"|sha256 \"${NEW_SHA}\"|" "$TEMP_DIR/mock_formula.rb"
sed -i.bak "s|version \"[^\"]*\"|version \"${NEW_VERSION}\"|" "$TEMP_DIR/mock_formula.rb" && rm -f "$TEMP_DIR/mock_formula.rb.bak"

EXPECTED_FORMULA='class SmartRename < Formula
  desc "AI-powered file renaming tool"
  homepage "https://github.com/tigger04/smart-rename"
  url "https://github.com/tigger04/smart-rename/archive/refs/tags/v5.23.1.tar.gz"
  sha256 "newhash456"
  license "MIT"
  version "5.23.1"
end'

RESULT=$(cat "$TEMP_DIR/mock_formula.rb")

if [[ "$RESULT" == "$EXPECTED_FORMULA" ]]; then
    echo "PASS: Full formula file update (tarball format)"
    passed=$((passed + 1))
else
    echo "FAIL: Full formula file update (tarball format)"
    echo "Expected:"
    echo "$EXPECTED_FORMULA"
    echo ""
    echo "Got:"
    echo "$RESULT"
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
