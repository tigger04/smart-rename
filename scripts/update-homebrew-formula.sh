#!/usr/bin/env bash
# ABOUTME: Automatically updates the homebrew formula with current version and hash
# ABOUTME: Run this before committing to ensure formula stays in sync

set -euo pipefail

# Get version from script
VERSION=$(grep "^VERSION=" smart-rename | cut -d'"' -f2)
echo "Updating homebrew formula to version $VERSION"

# Calculate SHA256 of the script
SHA256=$(sha256sum smart-rename | cut -d' ' -f1)
echo "Script SHA256: $SHA256"

# Check if formula directory exists
if [[ ! -d "/tmp/homebrew-tap-fix/Formula" ]]; then
    echo "Error: Formula directory not found at /tmp/homebrew-tap-fix/Formula"
    echo "Please ensure the homebrew tap is cloned there"
    exit 1
fi

# Update the formula
FORMULA_PATH="/tmp/homebrew-tap-fix/Formula/smart-rename.rb"

# Update version
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$FORMULA_PATH"

# Update SHA256
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$FORMULA_PATH"

echo "✓ Updated formula at $FORMULA_PATH"
echo "  Version: $VERSION"
echo "  SHA256: $SHA256"

# Show the diff
echo ""
echo "Formula changes:"
cd /tmp/homebrew-tap-fix
git diff Formula/smart-rename.rb