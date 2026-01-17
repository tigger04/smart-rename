#!/usr/bin/env bash
# ABOUTME: Tests for receipt/invoice amount decimal normalisation
# ABOUTME: Verifies that amounts are always formatted with two decimal places

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the normalisation logic by extracting it
# We test the regex patterns directly since the function is embedded in process_file

passed=0
failed=0

test_normalise() {
    local input="$1"
    local expected="$2"
    local description="$3"
    local result="$input"

    # Strip leading/trailing hyphens and collapse multiple consecutive hyphens
    result=$(echo "$result" | sed 's/^-*//; s/-*$//; s/-\{2,\}/-/g')

    # Apply the same normalisation logic as in smart-rename
    if [[ "$result" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]+)-([0-9]{2})-(.+)$ ]]; then
        # Case: hyphen used as decimal separator (e.g., 198-75 instead of 198.75)
        local date_part="${BASH_REMATCH[1]}"
        local amount_whole="${BASH_REMATCH[2]}"
        local amount_decimal="${BASH_REMATCH[3]}"
        local rest="${BASH_REMATCH[4]}"
        result="${date_part}-${amount_whole}.${amount_decimal}-${rest}"
    elif [[ "$result" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]+)-([^0-9].*)$ ]]; then
        # Case: whole number without decimals (e.g., 100 instead of 100.00)
        local date_part="${BASH_REMATCH[1]}"
        local amount="${BASH_REMATCH[2]}"
        local rest="${BASH_REMATCH[3]}"
        result="${date_part}-${amount}.00-${rest}"
    elif [[ "$result" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]+\.[0-9])-([^0-9].*)$ ]]; then
        # Case: single decimal place (e.g., 100.5 instead of 100.50)
        local date_part="${BASH_REMATCH[1]}"
        local amount="${BASH_REMATCH[2]}"
        local rest="${BASH_REMATCH[3]}"
        result="${date_part}-${amount}0-${rest}"
    fi

    # Reject 0.00 amounts - these are not real invoices/receipts
    if [[ "$result" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-0\.00-(.+)$ ]]; then
        result="${BASH_REMATCH[1]}"
    fi

    if [[ "$result" == "$expected" ]]; then
        echo "PASS: $description"
        echo "      Input:    $input"
        echo "      Expected: $expected"
        echo "      Got:      $result"
        ((passed++)) || true
    else
        echo "FAIL: $description"
        echo "      Input:    $input"
        echo "      Expected: $expected"
        echo "      Got:      $result"
        ((failed++)) || true
    fi
    echo ""
}

echo "=== Testing decimal normalisation ==="
echo ""

# Test hyphen as decimal separator
test_normalise "2025-12-10-198-75-greystones-vets-invoice" \
               "2025-12-10-198.75-greystones-vets-invoice" \
               "Hyphen as decimal separator (198-75 -> 198.75)"

# Test whole number without decimals
test_normalise "2025-12-03-111-visa-receipt-dental-care-ireland" \
               "2025-12-03-111.00-visa-receipt-dental-care-ireland" \
               "Whole number without decimals (111 -> 111.00)"

test_normalise "2025-11-19-100-receipt-st-vincents-private-hospital" \
               "2025-11-19-100.00-receipt-st-vincents-private-hospital" \
               "Whole number without decimals (100 -> 100.00)"

test_normalise "2025-01-21-250-eu-consultation-appointment-prof-james-mccarthy" \
               "2025-01-21-250.00-eu-consultation-appointment-prof-james-mccarthy" \
               "Whole number without decimals (250 -> 250.00)"

# Test already correct format (should not change)
test_normalise "2024-01-15-123.45-office-supplies" \
               "2024-01-15-123.45-office-supplies" \
               "Already correct format (123.45 unchanged)"

test_normalise "2024-02-28-100.00-monthly-subscription" \
               "2024-02-28-100.00-monthly-subscription" \
               "Already correct format (100.00 unchanged)"

# Test single decimal place
test_normalise "2024-03-15-99.5-partial-refund" \
               "2024-03-15-99.50-partial-refund" \
               "Single decimal place (99.5 -> 99.50)"

# Test larger amounts
test_normalise "2024-04-01-1500-annual-subscription" \
               "2024-04-01-1500.00-annual-subscription" \
               "Larger whole number (1500 -> 1500.00)"

test_normalise "2024-04-01-1500-50-annual-subscription" \
               "2024-04-01-1500.50-annual-subscription" \
               "Larger amount with hyphen decimal (1500-50 -> 1500.50)"

# Test 0.00 rejection (not a real invoice)
test_normalise "2024-05-01-0.00-meeting-notes-project" \
               "meeting-notes-project" \
               "Zero amount rejected (0.00 stripped, not an invoice)"

test_normalise "2024-05-01-0-some-document" \
               "some-document" \
               "Zero amount rejected (0 -> 0.00 -> stripped)"

# Test hyphen stripping (garbage from local models)
test_normalise "-------2024-01-15-49.99-amazon-order" \
               "2024-01-15-49.99-amazon-order" \
               "Leading hyphens stripped"

test_normalise "warranty-guide-mini-pc----" \
               "warranty-guide-mini-pc" \
               "Trailing hyphens stripped"

test_normalise "---warranty---guide---mini---pc---" \
               "warranty-guide-mini-pc" \
               "Multiple consecutive hyphens collapsed"

# Summary
echo "=== Summary ==="
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
