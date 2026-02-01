# Homebrew Formula Management

This project distributes via Homebrew using a GitHub archive tarball.

## How It Works

1. **Formula location**: The Homebrew formula lives in the `tigger04/homebrew-tap` repository
2. **Tarball URL**: Points to `https://github.com/tigger04/smart-rename/archive/refs/tags/vX.Y.Z.tar.gz`
3. **SHA256**: Computed from the tarball at release time
4. **Installed files**:
   - `bin/smart-rename` - the main executable
   - `share/smart-rename/config.example.yaml` - reference configuration
   - `share/smart-rename/smart-rename.Modelfile` - Ollama model definition
5. **inreplace**: The formula patches `SMART_RENAME_SHARE_DIR` in the script to point to `pkgshare`

## Formula Path

The formula is at:
```
$(brew --repository tigger04/tap)/Formula/smart-rename.rb
```

A pointer is stored in `.homebrew-formula` for tooling.

## Release Workflow

The `make release` target handles everything:

1. Runs tests
2. Bumps the patch version
3. Commits and pushes the version bump
4. Creates and pushes a git tag
5. Downloads the tarball from GitHub
6. Computes the SHA256 of the tarball
7. Updates the formula (URL, SHA256, version)
8. Commits and pushes the formula
9. Upgrades the local Homebrew installation

### Manual Formula Update

```bash
make formula
```

This will:
- Read the current VERSION from the script
- Fetch the tarball from GitHub and compute its SHA256
- Update the formula with `sed` patterns
- Commit and push to the homebrew-tap repo

## Configuration on Install

The formula does NOT auto-create a user config. Instead:
- Built-in defaults work out of the box
- Users who want customisation copy the reference config:
  ```bash
  cp $(brew --prefix)/share/smart-rename/config.example.yaml ~/.config/smart-rename/config.yaml
  ```

## Dependencies

Required (installed by Homebrew):
- bash, curl, fd, jq, yq, poppler

Optional (user installs separately):
- ollama (`brew install ollama`)

## Troubleshooting

### SHA mismatch on install
The SHA is computed from the GitHub tarball. If the tag was force-pushed or the tarball changed, run `make formula` to recompute.

### config.example.yaml not found
Check that the share directory exists: `ls $(brew --prefix)/share/smart-rename/`

### Custom model not created
Ensure Ollama is running: `brew services start ollama`. The model is created on first use.
