#!/usr/bin/env bash
# Simple YAML config test

set -e

# Create test config
TEST_DIR="$(mktemp -d)"
mkdir -p "$TEST_DIR/.config/smart-rename"

cat > "$TEST_DIR/.config/smart-rename/config.yaml" << 'EOF'
currency:
  base: "USD"
EOF

# Test that we have the example YAML file
if [ -f "config.example.yaml" ]; then
    echo "✓ Example YAML config exists"
else
    echo "✗ Example YAML config missing"
    exit 1
fi

# Test YAML structure
if grep -q "BASE_CURRENCY" config.example.yaml && grep -q "ABBREVIATIONS" config.example.yaml; then
    echo "✓ Example YAML contains placeholders"
else
    echo "✗ Example YAML missing placeholders"
    exit 1
fi

echo "Basic YAML tests passed"
rm -rf "$TEST_DIR"