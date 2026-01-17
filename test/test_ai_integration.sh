#!/usr/bin/env bash
# ABOUTME: Test that smart-rename actually reads files and calls AI services
# ABOUTME: Verifies the core functionality works, not just the shell structure

set -euo pipefail

# Test setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/smart-rename"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Testing AI Integration...${NC}"
echo "================================="

# Create test environment
TEST_TEMP=$(mktemp -d)
trap "rm -rf $TEST_TEMP" EXIT

cd "$TEST_TEMP"

# Test 1: Script should fail with no AI service available
echo -e "\n${YELLOW}Test 1: Behavior with no AI service${NC}"
unset OPENAI_API_KEY
unset CLAUDE_API_KEY

echo "Test document content for smart rename" > test.txt

if "$SCRIPT" -y "test.txt" 2>&1 | grep -q "No AI service available"; then
    echo -e "${GREEN}✓${NC} Correctly reports no AI service available"
else
    echo -e "${RED}✗${NC} Should report no AI service available"
    echo "Output:"
    "$SCRIPT" -y "test.txt" 2>&1 || true
fi

# Test 2: With mock Ollama
echo -e "\n${YELLOW}Test 2: Mock Ollama response${NC}"

# Create mock ollama command
cat > "$TEST_TEMP/ollama" <<'EOF'
#!/bin/bash
if [[ "$2" == "mistral" ]]; then
    echo "test-document-summary"
fi
EOF
chmod +x "$TEST_TEMP/ollama"
export PATH="$TEST_TEMP:$PATH"

echo "Test document about project planning" > planning.txt

OUTPUT=$("$SCRIPT" -y "planning.txt" 2>&1 || true)
if echo "$OUTPUT" | grep -q "test-document-summary"; then
    echo -e "${GREEN}✓${NC} Successfully calls Ollama and uses response"
else
    echo -e "${RED}✗${NC} Failed to use Ollama response"
    echo "Output: $OUTPUT"
fi

# Test 3: PDF processing (if pdftotext available)
echo -e "\n${YELLOW}Test 3: PDF file handling${NC}"
if command -v pdftotext >/dev/null 2>&1; then
    # Create a simple PDF-like file
    echo "Mock PDF content" > test.pdf

    if "$SCRIPT" -y "test.pdf" 2>&1 | grep -q "Error reading PDF\|test-document-summary"; then
        echo -e "${GREEN}✓${NC} Attempts to process PDF files"
    else
        echo -e "${RED}✗${NC} Doesn't handle PDF files properly"
    fi
else
    echo -e "${YELLOW}⚠${NC} pdftotext not available, skipping PDF test"
fi

# Test 4: Verify prompt is actually sent
echo -e "\n${YELLOW}Test 4: Verify AI prompt contains file content${NC}"

# Create mock ollama that echoes what it receives
cat > "$TEST_TEMP/ollama" <<'EOF'
#!/bin/bash
input=$(cat)
if echo "$input" | grep -q "important-test-content"; then
    echo "content-was-sent"
else
    echo "no-content-found"
fi
EOF

echo "This file contains important-test-content for verification" > verify.txt

OUTPUT=$("$SCRIPT" -y "verify.txt" 2>&1 || true)
if echo "$OUTPUT" | grep -q "content-was-sent"; then
    echo -e "${GREEN}✓${NC} File content is included in AI prompt"
else
    echo -e "${RED}✗${NC} File content not sent to AI"
    echo "Output: $OUTPUT"
fi

echo -e "\n${GREEN}AI Integration tests complete${NC}"