# Homebrew Formula Management

This project automatically manages its Homebrew formula through a global git pre-push hook.

## How It Works

1. **Detection**: The git hook detects this is a Homebrew project by:
   - Finding `.homebrew-formula` file (points to formula location)
   - Or auto-detecting formula at `/tmp/homebrew-tap-fix/Formula/smart-rename.rb`

2. **Version Check**: Extracts version from the `VERSION=` line in the script

3. **SHA256 Calculation**: Computes SHA256 hash of the main `smart-rename` script

4. **Auto-Update**: If version or SHA doesn't match the formula, it:
   - Updates the formula automatically
   - Blocks the push until formula is committed to homebrew tap

## Manual Override

- **Explicit formula path**: Create `.homebrew-formula` with path to formula
- **Skip checks**: Create `.no-homebrew` file to disable formula checking

## Formula Location

The Homebrew formula is stored in the separate `tigoss/homebrew-tap` repository at:
```
/tmp/homebrew-tap-fix/Formula/smart-rename.rb
```

This formula contains:
- `version`: The current version string
- `sha256`: SHA256 hash of the script file
- Installation instructions for Homebrew

## Workflow

1. Make changes to `smart-rename` script
2. Update `VERSION=` in the script
3. Attempt to push → hook auto-updates formula
4. Commit and push formula changes to homebrew-tap
5. Push smart-rename changes

The hook ensures the formula is always in sync with the actual script.