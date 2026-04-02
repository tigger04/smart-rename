#!/usr/bin/make -f
# ABOUTME: Build configuration for smart-rename project
# ABOUTME: Provides test targets, development installation, and release automation

.PHONY: test install uninstall clean help release bump tag formula brew-upgrade sync

# Configuration
SCRIPT := smart-rename
FORMULA_PATH := $(shell brew --repository tigger04/tap 2>/dev/null)/Formula/smart-rename.rb
VERSION := $(shell grep '^VERSION=' $(SCRIPT) | cut -d'"' -f2)

# Default target
help:
	@echo "Available targets:"
	@echo "  test         - Run all tests"
	@echo "  release      - Full release: test, bump, commit, tag, formula, brew-upgrade"
	@echo "  bump         - Increment patch version (X.Y.Z -> X.Y.Z+1)"
	@echo "  tag          - Create and push git tag for current VERSION"
	@echo "  formula      - Update Homebrew formula with current VERSION and SHA"
	@echo "  brew-upgrade - Upgrade local Homebrew installation"
	@echo "  install      - Development install: symlink to ~/.local/bin"
	@echo "  uninstall    - Remove symlinks from ~/.local/bin"
	@echo "  sync         - Git add, commit, pull, push"
	@echo "  clean        - Clean up test artifacts"
	@echo ""
	@echo "Current version: $(VERSION)"
	@echo ""
	@echo "For production installation, use Homebrew:"
	@echo "  brew tap tigger04/tap"
	@echo "  brew install smart-rename"

# Run tests
test:
	@echo "Running config loading tests..."
	@./test/test_config_loading.sh
	@echo "Running decimal normalisation tests..."
	@./test/test_decimal_normalisation.sh
	@echo "Running Makefile sed pattern tests..."
	@./test/test_makefile_sed.sh
	@echo "Running provider preference tests..."
	@./test/test_provider_preference.sh
	@echo "Running config path tests..."
	@./test/test_config_paths.sh
	@echo "Running Modelfile tests..."
	@./test/test_modelfile.sh
	@echo "Running classification tests..."
	@./test/test_classification.sh
	@echo "Running config CLI tests..."
	@./test/test_config_cli.sh
	@echo "Running file format tests..."
	@./test/test_file_formats.sh
	@echo "Running error handling tests..."
	@./test/test_error_handling.sh
	@echo "Running excluded words tests..."
	@./test/test_excluded_words.sh
	@echo "Running Nix packaging tests..."
	@./test/test_nix_build.sh
	@echo "All tests passed!"

# Development install: symlink into ~/.local/bin (no sudo required)
install: smart-rename
	@echo "Installing symlinks to ~/.local/bin..."
	@mkdir -p "$(HOME)/.local/bin" "$(HOME)/.local/share/smart-rename"
	@ln -sf "$(CURDIR)/smart-rename" "$(HOME)/.local/bin/smart-rename"
	@ln -sf "$(CURDIR)/config.example.yaml" "$(HOME)/.local/share/smart-rename/config.example.yaml"
	@ln -sf "$(CURDIR)/smart-rename.Modelfile" "$(HOME)/.local/share/smart-rename/smart-rename.Modelfile"
	@echo "Installed: $(HOME)/.local/bin/smart-rename"

# Uninstall: remove symlinks from ~/.local/bin and ~/.local/share
uninstall:
	@echo "Removing symlinks from ~/.local/bin..."
	@rm -f "$(HOME)/.local/bin/smart-rename"
	@rm -f "$(HOME)/.local/share/smart-rename/config.example.yaml"
	@rm -f "$(HOME)/.local/share/smart-rename/smart-rename.Modelfile"
	@rmdir "$(HOME)/.local/share/smart-rename" 2>/dev/null || true
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

# Full release workflow (SKIP_TESTS=1 to bypass when tests already passed)
release:
ifeq ($(SKIP_TESTS),1)
	@echo "Skipping tests (SKIP_TESTS=1)"
else
	@$(MAKE) test
endif
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

# Update Homebrew formula (computes SHA from GitHub tarball)
formula:
	@echo "Updating Homebrew formula..."
	@if [ -z "$(FORMULA_PATH)" ] || [ ! -f "$(FORMULA_PATH)" ]; then \
		echo "Error: Formula not found. Is tigger04/tap tapped?"; \
		exit 1; \
	fi
	@CURRENT_VERSION=$$(grep '^VERSION=' $(SCRIPT) | cut -d'"' -f2); \
	TARBALL_URL="https://github.com/tigger04/smart-rename/archive/refs/tags/v$${CURRENT_VERSION}.tar.gz"; \
	echo "  Version:  $$CURRENT_VERSION"; \
	echo "  Tarball:  $$TARBALL_URL"; \
	echo "  Fetching SHA256..."; \
	CURRENT_SHA=$$(curl -sL "$$TARBALL_URL" | shasum -a 256 | awk '{print $$1}'); \
	echo "  SHA256:   $$CURRENT_SHA"; \
	sed -i.bak "s|url \"https://github.com/tigger04/smart-rename/archive/refs/tags/v[^\"]*\.tar\.gz\"|url \"$$TARBALL_URL\"|" "$(FORMULA_PATH)"; \
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

# Git sync: add all, commit, pull (merge), push, update submodules
sync:
	@if [ -f .gitmodules ]; then \
		echo "Updating submodules..."; \
		git submodule sync --recursive && \
		git submodule update --init --recursive; \
	fi
	@if [ -z "$$(git status --porcelain)" ]; then \
		echo "Nothing to commit, pulling..."; \
	else \
		MSG=$${MSG:-"sync: update"}; \
		git add --all && \
		git commit -m "$$MSG"; \
	fi
	@git pull --rebase=false && git push
