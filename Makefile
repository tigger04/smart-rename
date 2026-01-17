#!/usr/bin/make -f
# ABOUTME: Build configuration for smart-rename project
# ABOUTME: Provides test targets, development installation, and release automation

.PHONY: test install uninstall clean help release bump tag formula brew-upgrade

# Configuration
SCRIPT := smart-rename
FORMULA_PATH := $(shell brew --repository tigger04/tap 2>/dev/null)/Formula/smart-rename.rb
VERSION := $(shell grep '^VERSION=' $(SCRIPT) | cut -d'"' -f2)
SHA256 := $(shell shasum -a 256 $(SCRIPT) | awk '{print $$1}')

# Default target
help:
	@echo "Available targets:"
	@echo "  test         - Run all tests"
	@echo "  release      - Full release: test, bump, commit, tag, formula, brew-upgrade"
	@echo "  bump         - Increment patch version (X.Y.Z -> X.Y.Z+1)"
	@echo "  tag          - Create and push git tag for current VERSION"
	@echo "  formula      - Update Homebrew formula with current VERSION and SHA"
	@echo "  brew-upgrade - Upgrade local Homebrew installation"
	@echo "  install      - Development install to /usr/local/bin (requires sudo)"
	@echo "  uninstall    - Remove installed files (requires sudo)"
	@echo "  clean        - Clean up test artifacts"
	@echo ""
	@echo "Current version: $(VERSION)"
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

# Increment patch version (X.Y.Z -> X.Y.Z+1)
bump:
	@OLD_VERSION=$$(grep '^VERSION=' $(SCRIPT) | cut -d'"' -f2); \
	NEW_VERSION=$$(echo "$$OLD_VERSION" | awk -F. '{$$NF = $$NF + 1;} 1' OFS=.); \
	echo "Bumping version: $$OLD_VERSION -> $$NEW_VERSION"; \
	sed -i.bak "s/^VERSION=\"$$OLD_VERSION\"/VERSION=\"$$NEW_VERSION\"/" $(SCRIPT) && rm -f $(SCRIPT).bak

# Full release workflow
release: test
	@echo "=== Starting release ==="
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: Working directory not clean. Commit changes first."; \
		exit 1; \
	fi
	@$(MAKE) bump
	@NEW_VERSION=$$(grep '^VERSION=' $(SCRIPT) | cut -d'"' -f2); \
	echo "=== Releasing v$$NEW_VERSION ==="; \
	git add $(SCRIPT) && \
	git commit -m "chore: bump version to $$NEW_VERSION" && \
	git push origin master && \
	git tag "v$$NEW_VERSION" && \
	git push origin "v$$NEW_VERSION" && \
	echo "Tagged and pushed v$$NEW_VERSION"
	@$(MAKE) formula
	@$(MAKE) brew-upgrade
	@echo "=== Release complete ==="

# Create and push git tag
tag:
	@echo "Creating tag v$(VERSION)..."
	@if git rev-parse "v$(VERSION)" >/dev/null 2>&1; then \
		echo "Tag v$(VERSION) already exists"; \
	else \
		git tag "v$(VERSION)" && \
		git push origin "v$(VERSION)" && \
		echo "Tag v$(VERSION) pushed"; \
	fi

# Update Homebrew formula (re-reads version/sha dynamically)
formula:
	@echo "Updating Homebrew formula..."
	@if [ -z "$(FORMULA_PATH)" ] || [ ! -f "$(FORMULA_PATH)" ]; then \
		echo "Error: Formula not found. Is tigger04/tap tapped?"; \
		exit 1; \
	fi
	@CURRENT_VERSION=$$(grep '^VERSION=' $(SCRIPT) | cut -d'"' -f2); \
	CURRENT_SHA=$$(shasum -a 256 $(SCRIPT) | awk '{print $$1}'); \
	echo "  Version: $$CURRENT_VERSION"; \
	echo "  SHA256:  $$CURRENT_SHA"; \
	sed -i.bak "s|url \"https://raw.githubusercontent.com/tigger04/smart-rename/v[^\"]*|url \"https://raw.githubusercontent.com/tigger04/smart-rename/v$$CURRENT_VERSION|" "$(FORMULA_PATH)"; \
	sed -i.bak "s|sha256 \"[^\"]*\"|sha256 \"$$CURRENT_SHA\"|" "$(FORMULA_PATH)"; \
	sed -i.bak "s|version \"[^\"]*\"|version \"$$CURRENT_VERSION\"|" "$(FORMULA_PATH)" && rm -f "$(FORMULA_PATH).bak"; \
	cd "$$(dirname "$(FORMULA_PATH)")" && \
		git add smart-rename.rb && \
		git commit -m "smart-rename $$CURRENT_VERSION" && \
		git push
	@echo "Formula updated and pushed"

# Upgrade local Homebrew installation
brew-upgrade:
	@echo "Upgrading local installation..."
	@brew upgrade tigger04/tap/smart-rename || brew reinstall tigger04/tap/smart-rename
	@echo "Installed version: $$(smart-rename --version)"