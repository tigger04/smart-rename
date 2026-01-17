#!/usr/bin/env bash
# ABOUTME: Test suite for Homebrew tap installation
# ABOUTME: Verifies brew tap works without LFS issues and pandoc dependency is included

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counter
TESTS=0
PASSED=0
FAILED=0

# Test helper functions
test_start() {
    TESTS=$((TESTS + 1))
    echo -n "Testing: $1... "
}

test_pass() {
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}✓${NC}"
}

test_fail() {
    FAILED=$((FAILED + 1))
    echo -e "${RED}✗${NC}"
    echo "  Error: $1"
}

# Skip tests if brew is not available
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Skipping Homebrew tests: brew not available${NC}"
    exit 0
fi

# Cleanup function
cleanup_tap() {
    brew untap tigger04/tap 2>/dev/null || true
}

# Ensure clean state
cleanup_tap

# Test 1: Tap installation should work without LFS errors
test_start "Homebrew tap installation without LFS issues"
TAP_OUTPUT=$(brew tap tigger04/tap 2>&1)
if echo "$TAP_OUTPUT" | grep -q "Tapped.*formulae"; then
    test_pass
else
    test_fail "Tap installation failed: $TAP_OUTPUT"
fi

# Test 2: Formula should exist in tap
test_start "smart-rename formula exists in tap"
if brew info tigger04/tap/smart-rename >/dev/null 2>&1; then
    test_pass
else
    test_fail "smart-rename formula not found in tap"
fi

# Test 3: Formula should include pandoc dependency
test_start "smart-rename formula includes pandoc dependency"
FORMULA_INFO=$(brew info tigger04/tap/smart-rename 2>&1)
if echo "$FORMULA_INFO" | grep -q "pandoc"; then
    test_pass
else
    test_fail "pandoc dependency not found in formula"
fi

# Test 4: Formula validation (dry run install)
test_start "Formula validation with dry-run install"
if brew install --dry-run tigger04/tap/smart-rename >/dev/null 2>&1; then
    test_pass
else
    test_fail "Formula validation failed"
fi

# Test 5: No LFS-related errors in recent tap operation
test_start "No Git LFS errors during tap operation"
RECENT_TAP=$(brew tap-info tigger04/tap 2>&1)
if echo "$RECENT_TAP" | grep -qi "lfs\|git-lfs"; then
    test_fail "LFS-related errors still present"
else
    test_pass
fi

# Cleanup
cleanup_tap

# Summary
echo ""
echo "================================="
echo "Homebrew Test Results:"
echo "Tests run: $TESTS"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi