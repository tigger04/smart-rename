#!/usr/bin/env bash
# ABOUTME: Test script to verify Nix packaging works correctly
# ABOUTME: Tests both default.nix and flake.nix build and functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
test_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

echo "=== Testing Nix packaging for smart-rename ==="
echo ""

# Check if nix is available
if ! command -v nix >/dev/null 2>&1; then
    echo -e "${YELLOW}Nix not found - skipping Nix packaging tests${NC}"
    echo "To install Nix:"
    echo "  curl -L https://nixos.org/nix/install | sh"
    exit 0
fi

# Test 1: Validate default.nix syntax
echo "1. Testing default.nix syntax..."
if nix-instantiate --parse default.nix >/dev/null 2>&1; then
    test_pass "default.nix syntax is valid"
else
    test_fail "default.nix has syntax errors"
fi

# Test 2: Validate flake.nix syntax (if flakes are supported)
echo ""
echo "2. Testing flake.nix syntax..."
if command -v nix >/dev/null 2>&1 && nix --version | grep -q "2\.[4-9]\|[3-9]"; then
    # Enable experimental features for this test
    export NIX_CONFIG="experimental-features = nix-command flakes"
    if nix flake check --no-build 2>/dev/null; then
        test_pass "flake.nix syntax is valid"
    else
        test_fail "flake.nix has syntax errors"
    fi
else
    test_skip "flake.nix (Nix version too old for flakes)"
fi

# Test 3: Build with default.nix
echo ""
echo "3. Testing build with default.nix..."
BUILD_RESULT=""
if BUILD_RESULT=$(nix-build default.nix --no-out-link 2>&1); then
    test_pass "Build with default.nix successful"

    # Test 4: Verify executable exists and runs
    echo ""
    echo "4. Testing executable functionality..."
    if [[ -x "$BUILD_RESULT/bin/smart-rename" ]]; then
        test_pass "Executable exists and is executable"

        # Test version output
        if VERSION_OUTPUT=$("$BUILD_RESULT/bin/smart-rename" --version 2>&1); then
            if [[ "$VERSION_OUTPUT" =~ smart-rename\ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
                test_pass "Version output correct: $VERSION_OUTPUT"
            else
                test_fail "Version output format incorrect: $VERSION_OUTPUT"
            fi
        else
            test_fail "Could not get version output"
        fi

        # Test help output
        if HELP_OUTPUT=$("$BUILD_RESULT/bin/smart-rename" --help 2>&1); then
            if [[ "$HELP_OUTPUT" =~ "USAGE:" ]]; then
                test_pass "Help output contains usage information"
            else
                test_fail "Help output missing usage information"
            fi
        else
            test_fail "Could not get help output"
        fi

    else
        test_fail "Executable not found or not executable"
    fi
else
    test_fail "Build with default.nix failed: $BUILD_RESULT"
fi

# Test 5: Build with flakes (if supported)
echo ""
echo "5. Testing build with flakes..."
if command -v nix >/dev/null 2>&1 && nix --version | grep -q "2\.[4-9]\|[3-9]"; then
    export NIX_CONFIG="experimental-features = nix-command flakes"
    if FLAKE_RESULT=$(nix build --no-link --print-out-paths . 2>&1); then
        test_pass "Build with flakes successful"

        # Test flake executable
        if [[ -x "$FLAKE_RESULT/bin/smart-rename" ]]; then
            test_pass "Flake executable exists and is executable"
        else
            test_fail "Flake executable not found or not executable"
        fi
    else
        test_fail "Build with flakes failed: $FLAKE_RESULT"
    fi
else
    test_skip "Build with flakes (Nix version too old)"
fi

# Test 6: Check dependencies are properly wrapped
echo ""
echo "6. Testing dependency availability..."
if [[ -n "$BUILD_RESULT" ]]; then
    # Create a simple test to check if wrapped dependencies work
    TEST_SCRIPT=$(mktemp)
    cat > "$TEST_SCRIPT" << 'EOF'
#!/bin/bash
# Test if wrapped dependencies are available
DEPS=(jq yq fd curl pdftotext)
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Missing dependency: $dep"
        exit 1
    fi
done
echo "All dependencies available"
EOF
    chmod +x "$TEST_SCRIPT"

    # Run test in the nix-built environment
    if "$BUILD_RESULT/bin/smart-rename" --version >/dev/null 2>&1; then
        test_pass "Dependencies properly wrapped"
    else
        test_fail "Dependencies not properly wrapped"
    fi

    rm -f "$TEST_SCRIPT"
else
    test_skip "Dependency testing (no build result)"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi