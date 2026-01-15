#!/usr/bin/make -f
# ABOUTME: Build configuration for smart-rename project
# ABOUTME: Provides test targets and installation helpers

.PHONY: test install clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  test     - Run all tests"
	@echo "  install  - Install to /usr/local/bin"
	@echo "  clean    - Clean up test artifacts"
	@echo "  help     - Show this help"

# Run tests
test:
	@echo "Running configuration tests..."
	@./test/test_config.sh
	@echo "Running integration tests..."
	@./test/test_integration.sh
	@echo "All tests passed!"

# Install to system
install:
	install -m 755 smart-rename /usr/local/bin/
	install -m 644 summarize-text-lib.sh /usr/local/share/smart-rename/

# Clean test artifacts
clean:
	rm -rf test/tmp/
	rm -f test/*.log

# Create test directories if they don't exist
test/tmp:
	mkdir -p test/tmp