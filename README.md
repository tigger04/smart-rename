sanitize: defaulting to oed + symbols
# smart-rename

AI-powered file renaming tool that generates intelligent, descriptive filenames based on file content.

## Why bother?

Example: I download my mobile phone bill from the phone company. I get a PDF document with the cryptically named: `e134-a1cf-4b4b-af65-ccf83c5270cb.pdf`

Open it, sure, I can see what it is. But how am I supposed to file that away? No sooner have I closed the file, it meaningless gibberish as far as my filesystem is concerned. And if you like to file things away as I do, it adds unnecessary manual labour in having to thoughtfully rename each file that frankly I could do without.

I have two rules of thumb when naming files:
- if it's a bill or invoice, ISO-DATE, Amount, description, in that order. ISO date is nice an unambiguous, no EU/US date mix-ups, and it sorts alphanumerically! Everyone's a winner
- if it's anything else, a very brief description, with *maybe* year and month tagged on to the end.

So for example:

``` sh
$ smart-rename e134-a1cf-4b4b-af65-ccf83c5270cb.pdf
Trying Ollama (smart-rename)...
Got response from Ollama
Generated name: 2026-01-15-54.97-three-bill.pdf
  e134-a1cf-4b4b-af65-ccf83c5270cb.pdf ->
  2026-01-15-54.97-three-bill.pdf (y/N):
```

That looks satisfactory to me, so the file will now be called `2026-01-15-54.97-three-bill.pdf`

*This is just one example, and leans into my own preference for naming scheme. You may configure the prompt, the format, to whatever system suits your own taste.*

## How does it work?

- It looks inside the file, and feeds it into an LLM.
- WAIT! I see alarm bells ringing for many of you. The DEFAULT is to use a LOCAL and LIGHTWEIGHT LLM that runs on your computer. No API tokens, no sending your data to Anthropic or OpenAI. That is how this thing works by default.
- You CAN if you choose plug it in to Anthropic or OpenAI if you want to use their models. Entirely up to you.

## Features

- Analyse file content and generate smart filenames
- Special formatting for receipts/invoices (YYYY-MM-DD-amount-description)
- Support for multiple currencies with configurable base currency
- Batch processing with pattern matching (regex or glob)
- Multiple AI provider support with configurable preference order
- Interactive or automatic rename mode
- Custom Ollama model with tuned parameters for filename generation

## Supported File Types

### Currently Supported
- [x] PDF documents (with OCR fallback for scanned PDFs)
- [x] Microsoft Word documents (DOC, DOCX)
- [x] Microsoft Excel spreadsheets (XLSX)
- [x] Microsoft PowerPoint presentations (PPTX)
- [x] RTF documents
- [x] OpenDocument formats (ODT, ODS, ODP)
- [x] Email files (EML, MSG)
- [x] Images (JPG, PNG, JPEG)
- [x] Text files (TXT)
- [x] Markdown files (MD)
- [x] HTML files
- [x] CSV files
- [x] Subtitle files (SRT, VTT, SUB)
- [x] JSON files
- [x] XML files
- [x] Source code files (any plaintext)

### On the Roadmap
- [ ] Video files (MP4, MOV) - extract first frame

## Quick Start

### macOS
```bash
brew install tigger04/tap/smart-rename
```

### Dependencies

The following are installed automatically via Homebrew:
- `fd` - fast file finder
- `yq` - YAML parser
- `jq` - JSON parser
- `poppler` - PDF text extraction (provides `pdftotext` and `pdftoppm`)
- `pandoc` - document conversion (DOCX, XLSX, PPTX, RTF, ODT/ODS/ODP)

Optional:
- `ollama` - for local AI (default provider); install with `brew install ollama`
- `tesseract` - OCR for scanned PDFs; install with `brew install tesseract`
- `msgconvert` - Outlook MSG support (Perl `Email::Outlook::Message`)

### NixOS/Nix
```bash
# Using flakes (recommended)
nix run github:tigger04/smart-rename

# Or install permanently
nix profile install github:tigger04/smart-rename

# Or add to your NixOS configuration.nix
environment.systemPackages = with pkgs; [
  (pkgs.callPackage (pkgs.fetchFromGitHub {
    owner = "tigger04";
    repo = "smart-rename";
    rev = "v5.23.0";  # Use latest version
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # Update with actual hash
  }) {})
];
```

### Other Linux platforms
- Package managers coming soon, meanwhile see the Dev install guide below

## Configuration

The tool works out of the box with sensible built-in defaults. No configuration file is needed.

### Provider Order

smart-rename uses a two-step AI process: **classify** (determine document type) then **name** (generate filename). Each step has its own provider preference order:

| Step | Default order | Rationale |
|------|--------------|-----------|
| **Classify** | Ollama -> OpenAI -> Claude | Simple task; Ollama is free and fast |
| **Name** | OpenAI -> Claude -> Ollama | Naming benefits from more capable models |

The first provider that is available and responds successfully is used.

### Optional Configuration

To customize behaviour, create a config file:

```bash
# Print the reference config and pipe to your config location
smart-rename --example-config > ~/.config/smart-rename/config.yaml

# Edit to taste
nano ~/.config/smart-rename/config.yaml
```

The config file lets you override:
- **Provider order**: Change which AI is tried first, per phase or globally
- **Models**: Use different models for each provider
- **Prompt**: Customize the filename generation prompt
- **API keys**: Store keys in the config instead of environment variables
- **Currency**: Change the base currency for invoice amounts

Example YAML structure:
```yaml
prompt:
  template: |
    Your custom prompt with {{BASE_CURRENCY}} and {{CONTENT}} placeholders

api:
  preference:
    classify:          # provider order for document classification
      - ollama
      - openai
      - claude
    name:              # provider order for filename generation
      - openai
      - claude
      - ollama
  ollama:
    model: smart-rename

currency:
  base: "USD"
```

A flat preference list (legacy format) is also supported - it applies to both phases:
```yaml
api:
  preference:
    - claude
    - openai
    - ollama
```

### Environment Variables

API keys can be set as environment variables (these take priority over config file values):
- `OPENAI_API_KEY`
- `CLAUDE_API_KEY`

### Local AI with Ollama

The default configuration uses a custom Ollama model called `smart-rename`, built from Qwen 2.5 7B with tuned parameters for filename generation. This model is automatically created on first run when Ollama is available.

The base model is **Qwen 2.5 7B** (`qwen2.5:7b`). This is the smallest model we found that reliably follows the filename format instructions - smaller 3B models tend to ignore the date-amount-vendor structure or produce inconsistent results.

**System requirements:**
- **Minimum**: 8GB RAM (model will run but may be slow)
- **Recommended**: 16GB RAM for responsive performance
- **Apple Silicon**: Runs well on M1/M2/M3 Macs with unified memory
- **Disk**: ~4.7GB for the model download

**Performance notes:**
- First run downloads the base model (~4.7GB) and creates the custom model - this only happens once
- On Apple Silicon with 16GB+, responses typically take 2-5 seconds
- On systems with less RAM, you may experience slower responses as the model swaps to disk

**Alternative**: If local performance is too slow, consider using the OpenAI or Claude APIs instead - set `OPENAI_API_KEY` or `CLAUDE_API_KEY` environment variable.

To use a different Ollama model, set `api.ollama.model` in your config file.

**Custom Modelfile**

The custom model is defined in `smart-rename.Modelfile`, which is installed alongside the script. It sets:
- Low temperature (0.2) for consistent output
- Extended context window (8192 tokens)
- System prompt tuned for filename generation

You can inspect or modify the Modelfile at `$(brew --prefix)/share/smart-rename/smart-rename.Modelfile`.

## Usage

```bash
# PATTERN
smart-rename [OPTIONS] [REGEX]
# -or-
smart-rename -g [OPTIONS] [GLOB]

# Process files matching pattern (interactive mode)
smart-rename "receipt.*\.pdf"

# Auto-rename without confirmation
smart-rename -y invoice.pdf

# Search recursively
smart-rename -r "\.docx$"

# Use glob pattern instead of regex
smart-rename -g "*.pdf"
```

## CLI switches

### Search Options
- `-r, --recursive`: Search files recursively
- `-g, --glob`: Treat pattern as glob instead of regex

### Rename Options
- `-y, --yes`: Auto-rename without confirmation

### Configuration
- `--example-config`: Print the reference config to stdout and exit

### Info
- `-h, --help`: Show help message
- `-v, --version`: Show version

## Filename Format

### Regular Documents
- Format: `descriptive-name.ext`
- Concise, descriptive names based on content

### Receipts/Invoices
- Format: `YYYY-MM-DD-amount-vendor-description.ext` (amount always includes two decimal places)
- Examples: `2026-01-31-124.50-smc-pharmacy-prescription.pdf`, `2026-01-31-7.99-amazon-phone-case.pdf`
- Base currency (default EUR) omits currency code
- Non-base currency: `YYYY-MM-DD-CUR-amount-vendor-description.ext` where CUR is the lowercase ISO currency code.

### Abbreviations (Configurable)
The tool comes with a few example abbreviations, adjust to your own needs in `config.yaml`
- svph = St. Vincent's Private Hospital
- svuh = St. Vincent's University Hospital
- nrh = National Rehabilitation Hospital
- mater = Mater Misericordiae University Hospital

## Important Files

| File | Purpose |
|------|---------|
| `smart-rename` | Main executable script |
| `config.example.yaml` | Reference configuration file |
| `config.yaml` | Working config (not installed; for dev use) |
| `smart-rename.Modelfile` | Ollama model definition |
| `Makefile` | Build, test, release automation |
| `summarize-text-lib.sh` | Legacy text summarization library |
| `test/test_config_cli.sh` | Tests for --example-config and stale config detection |
| `test/test_file_formats.sh` | Tests for all file format extraction (PDF OCR, DOCX, XLSX, etc.) |
| `docs/architecture.md` | Architecture and design decisions |
| `docs/vision.md` | Project vision and goals |
| `HOMEBREW.md` | Homebrew formula management |
| `test/` | Test suite |

## Development Installation

For development or manual installation:

```bash
# Clone the repository
git clone https://github.com/tigger04/smart-rename.git
cd smart-rename

# Run tests
make test

# Install to /usr/local/bin (requires sudo)
sudo make install

# Uninstall
sudo make uninstall
```

## Release Workflow

For maintainers releasing new versions:

```bash
# 1. Make your changes and commit them
git add -A && git commit -m "feat: description" && git push

# 2. Run release (auto-bumps version, tags, updates Homebrew)
make release
```

**Available make targets:**

| Target | Description |
|--------|-------------|
| `make test` | Run all tests |
| `make release` | Full release: test, bump, commit, tag, formula, brew-upgrade |
| `make bump` | Increment patch version (X.Y.Z -> X.Y.Z+1) |
| `make tag` | Create and push git tag for current VERSION |
| `make formula` | Update Homebrew formula with version and SHA256 |
| `make brew-upgrade` | Upgrade local Homebrew installation |
| `make sync` | Git add, commit, pull, push |

The release process automatically:
- Increments the patch version (e.g., 5.23.0 -> 5.23.1)
- Commits the version bump
- Creates and pushes a git tag
- Downloads the tarball and computes its SHA256
- Updates the Homebrew formula with new version, URL, and SHA256
- Upgrades the local Homebrew installation
- Requires a clean git working directory before starting

## License

MIT License - Copyright Tadg Paul - See LICENSE file for details
3 -ize corrections
5 symbol replacements
