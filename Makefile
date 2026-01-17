#!/usr/bin/make -f
# ABOUTME: Build configuration for smart-rename project
# ABOUTME: Provides test targets and development installation

.PHONY: test install uninstall clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  test      - Run all tests"
	@echo "  install   - Development install to /usr/local/bin (requires sudo)"
	@echo "  uninstall - Remove installed files (requires sudo)"
	@echo "  clean     - Clean up test artifacts"
	@echo "  help      - Show this help"
	@echo ""
	@echo "For production installation, use Homebrew:"
	@echo "  brew tap tigger04/tap"
	@echo "  brew install smart-rename"

# Run tests
test:
	@echo "Running decimal normalisation tests..."
	@./test/test_decimal_normalisation.sh
	@echo "All tests passed!"

# Development install (requires sudo)
install: smart-rename
	@echo "Installing to /usr/local/bin (requires sudo)..."
	@echo "Creating directories..."
	@sudo install -d /usr/local/bin
	@sudo install -d /usr/local/share/smart-rename
	@echo "Installing files..."
	@sudo install -m 755 smart-rename /usr/local/bin/
	@sudo install -m 644 summarize-text-lib.sh /usr/local/share/smart-rename/
	@echo "Installation complete: /usr/local/bin/smart-rename"

# Uninstall (requires sudo)
uninstall:
	@echo "Uninstalling from /usr/local (requires sudo)..."
	@sudo rm -f /usr/local/bin/smart-rename
	@sudo rm -rf /usr/local/share/smart-rename
	@echo "Uninstall complete"

# Build the executable (ensures it exists and is executable)
smart-rename:
	@if [ ! -f smart-rename ]; then \
		echo "Error: smart-rename not found in current directory"; \
		exit 1; \
	fi
	@chmod +x smart-rename

# Clean test artifacts
clean:
	rm -rf test/tmp/
	rm -f test/*.log

# Create test directories if they don't exist
test/tmp:
	mkdir -p test/tmp