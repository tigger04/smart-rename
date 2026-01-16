#!/usr/bin/env bash
# ABOUTME: Test suite for installation process
# ABOUTME: Verifies make install works correctly with proper permissions

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

# Create temporary test environment
TEST_DIR="$(mktemp -d)"
TEST_PREFIX="$TEST_DIR/usr/local"
trap "rm -rf $TEST_DIR" EXIT

# Clean up any existing installations in test environment
cleanup_installation() {
    local prefix="$1"
    if [ -f "$prefix/bin/smart-rename" ]; then
        echo "  Cleaning up existing installation at $prefix..."
        rm -f "$prefix/bin/smart-rename"
    fi
    if [ -d "$prefix/share/smart-rename" ]; then
        rm -rf "$prefix/share/smart-rename"
    fi
}

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

# Test 1: Verify Makefile has install target
test_start "Makefile has install target"
if grep -q "^install:" Makefile; then
    test_pass
else
    test_fail "No install target found in Makefile"
fi

# Test 2: Check Makefile defaults to /usr/local
test_start "Makefile uses /usr/local for development install"
if grep -q "/usr/local/bin" Makefile; then
    test_pass
else
    test_fail "Makefile should use /usr/local/bin for development install"
fi

# Test 3: Check install target requires sudo
test_start "Install target mentions sudo requirement"
if grep -q "requires sudo" Makefile; then
    test_pass
else
    test_fail "Install target should mention sudo requirement"
fi

# Test 4: Check source file is executable
test_start "Source file is executable"
if [ -x "smart-rename" ]; then
    test_pass
else
    test_fail "smart-rename should be executable"
fi

# Test 5: Verify uninstall target exists
test_start "Makefile has uninstall target"
if grep -q "^uninstall:" Makefile; then
    test_pass
else
    test_fail "No uninstall target found in Makefile"
fi

# Test 6: Check help mentions Homebrew
test_start "Help target mentions Homebrew installation"
HELP_OUTPUT=$(make help 2>&1)
if echo "$HELP_OUTPUT" | grep -q "brew tap tigger04/tap"; then
    test_pass
else
    test_fail "Help should mention Homebrew tap installation"
fi

# Summary
echo ""
echo "================================="
echo "Installation Test Results:"
echo "Tests run: $TESTS"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi