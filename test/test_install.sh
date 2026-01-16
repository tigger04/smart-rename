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

# Test 2: Check if we can detect Homebrew prefix
test_start "Detecting Homebrew installation"
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew --prefix)
    if [ -d "$BREW_PREFIX" ]; then
        test_pass
        echo "  Found Homebrew at: $BREW_PREFIX"
    else
        test_fail "Homebrew command exists but prefix not found"
    fi
else
    test_fail "Homebrew not installed"
fi

# Test 3: Test installation to custom PREFIX (simulating user install)
test_start "Installation to custom PREFIX"
# Ensure clean state before installation
cleanup_installation "$TEST_PREFIX"
mkdir -p "$TEST_PREFIX/bin"
mkdir -p "$TEST_PREFIX/share"

if make install PREFIX="$TEST_PREFIX" >/dev/null 2>&1; then
    # Check if files were installed
    if [ -f "$TEST_PREFIX/bin/smart-rename" ] && [ -f "$TEST_PREFIX/share/smart-rename/summarize-text-lib.sh" ]; then
        test_pass
    else
        test_fail "Files not installed to expected locations"
    fi
else
    test_fail "make install failed with custom PREFIX"
fi

# Test 4: Verify installed binary is executable
test_start "Installed binary is executable"
if [ -x "$TEST_PREFIX/bin/smart-rename" ]; then
    test_pass
else
    test_fail "Binary not executable"
fi

# Test 5: Test Homebrew-style installation (if Homebrew is available)
if command -v brew >/dev/null 2>&1; then
    test_start "Homebrew-compatible installation"
    BREW_TEST_DIR="$TEST_DIR/homebrew"
    # Ensure clean state before installation
    cleanup_installation "$BREW_TEST_DIR"
    mkdir -p "$BREW_TEST_DIR/bin"
    mkdir -p "$BREW_TEST_DIR/share"

    if make install PREFIX="$BREW_TEST_DIR" >/dev/null 2>&1; then
        if [ -f "$BREW_TEST_DIR/bin/smart-rename" ]; then
            test_pass
        else
            test_fail "Failed to install to Homebrew-style directory"
        fi
    else
        test_fail "make install failed for Homebrew-style PREFIX"
    fi
fi

# Test 6: Verify uninstall target exists
test_start "Makefile has uninstall target"
if grep -q "^uninstall:" Makefile; then
    test_pass
else
    test_fail "No uninstall target found in Makefile"
fi

# Test 7: Test uninstall functionality
test_start "Uninstall removes installed files"
UNINSTALL_TEST_DIR="$TEST_DIR/uninstall_test"
cleanup_installation "$UNINSTALL_TEST_DIR"
mkdir -p "$UNINSTALL_TEST_DIR/bin"
mkdir -p "$UNINSTALL_TEST_DIR/share"

# First install
if make install PREFIX="$UNINSTALL_TEST_DIR" >/dev/null 2>&1; then
    # Then uninstall
    if make uninstall PREFIX="$UNINSTALL_TEST_DIR" >/dev/null 2>&1; then
        # Check files are removed
        if [ ! -f "$UNINSTALL_TEST_DIR/bin/smart-rename" ] && [ ! -d "$UNINSTALL_TEST_DIR/share/smart-rename" ]; then
            test_pass
        else
            test_fail "Files not properly removed after uninstall"
        fi
    else
        test_fail "make uninstall failed"
    fi
else
    test_fail "Initial installation for uninstall test failed"
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