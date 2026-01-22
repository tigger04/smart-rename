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
Trying Ollama (qwen2.5:7b)...
✓ Got response from Ollama
Generated name: 2026-01-15-54.97-three-bill.pdf
📎 e134-a1cf-4b4b-af65-ccf83c5270cb.pdf →
🆕 2026-01-15-54.97-three-bill.pdf(y/N):
```

That looks satisfactory to me, so the file will now be called `2026-01-15-54.97-three-bill.pdf`

*This is just one example, and leans into my own preference for naming scheme. You may configure the prompt, the format, to whatever system suits your own taste.*

## How does it work?

- It looks inside the file, and feeds it into an LLM.
- WAIT! I see alarm bells ringing for many of you. The DEFAULT is to use a LOCAL and LIGHTWEIGHT LLM that runs on your computer. No API tokens, no sending your data to Anthropic or OpenAI. That is how this thing works by default.
- You CAN if you choose plug it in to Anthropic or OpenAI if you want to use their models. Entirely up to you.

## Features

- Analyze file content and generate smart filenames
- Special formatting for receipts/invoices (YYYY-MM-DD-amount-description)
- Support for multiple currencies with configurable base currency
- Batch processing with pattern matching (regex or glob)
- Multiple AI provider support (OpenAI, Claude, Ollama)
- Interactive or automatic rename mode

## Supported File Types

### Currently Supported
- [x] PDF documents
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
- [ ] Microsoft Word documents (DOCX)
- [ ] Microsoft Excel spreadsheets (XLSX) - with data analysis
- [ ] Microsoft PowerPoint presentations (PPTX)
- [ ] RTF documents
- [ ] OpenDocument formats (ODT, ODS, ODP)
- [ ] Email files (EML, MSG)
- [ ] Video files (MP4, MOV) - extract first frame

## Quick Start

### MacOS
```bash sh
brew install tigger04/tap/smart-rename
```

### Dependencies

The following are installed automatically via Homebrew:
- `fd` - fast file finder
- `yq` - YAML parser
- `jq` - JSON parser
- `poppler` - PDF text extraction (provides `pdftotext`)

### Other platforms
- Linux package managers coming soon, meanwhile see the Dev install guide below

## Configuration

The tool automatically detects available AI providers and uses the first available one. Configuration is loaded in this order:

1. **Environment variables** (highest priority)
   - `OPENAI_API_KEY`
   - `CLAUDE_API_KEY`

2. **YAML config file**: `~/.config/smart-rename/config.yaml`
   - The default config is copied here on first use, and should be intuitive to customize

3. **Built-in defaults**

### YAML Configuration Features

- **Custom prompts**: Configure the AI prompt with placeholders
- **API settings**: All providers and models in one place
- **Abbreviations**: Clean YAML format for custom abbreviations

Example YAML structure:
```yaml
prompts:
  rename: |
    Your custom prompt with {{BASE_CURRENCY}} and {{ABBREVIATIONS}} placeholders

currency:
  base: "USD"

abbreviations:
  myorg: "My Organization"
```

### Auto-Detection

- If only one API key is provided, that provider becomes the default
- If multiple keys are available, preference order: OpenAI → Claude → Ollama
- If no API keys but Ollama is running locally, uses Ollama
- If all are provided, the default can be set in `config.yaml`

### Local AI with Ollama

The default local model is **Qwen 2.5 7B**, chosen for:
- Excellent instruction following and document comprehension
- Reliable structured output for filename generation
- Runs well on 8GB+ RAM (Apple Silicon optimised)
- Good balance of speed and quality

The model is automatically pulled on first use. To use a different model, set `api.ollama.model` in your config.

**Optional: Custom Modelfile**

For optimized local processing, create a custom model with tuned parameters:

```bash
# Create ~/.ollama/modelfiles/smart-rename.Modelfile
cat > ~/.ollama/modelfiles/smart-rename.Modelfile << 'EOF'
FROM qwen2.5:7b

SYSTEM """You generate concise, descriptive filenames.
Rules:
- Output only the filename, nothing else
- No extension, lowercase, use hyphens
- For receipts/invoices: YYYY-MM-DD-amount.cc-description
- Amount always includes exactly two decimal places
- Be specific, preserve key names, dates, figures"""

PARAMETER temperature 0.2
PARAMETER num_ctx 8192
EOF

# Build it
ollama create smart-rename -f ~/.ollama/modelfiles/smart-rename.Modelfile
```

Then set `model: smart-rename` in your config to use it.

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

# Use specific AI provider
smart-rename --claude document.pdf
smart-rename --openai receipt.jpg
```

## CLI switches

### Search Options
- `-r, --recursive`: Search files recursively
- `-g, --glob`: Treat pattern as glob instead of regex

### AI Models
- `-l, --ollama[=model]`: Use Ollama API
- `-o, --openai[=model]`: Use OpenAI API
- `--claude`: Use Claude API
- `--prompt=TEXT`: Custom prompt

### Rename Options
- `-y, --yes`: Auto-rename without confirmation

## Filename Format

### Regular Documents
- Format: `descriptive-name-YY-MM-DD.ext`
- Uses current date if not found in content

### Receipts/Invoices
- Format: `YYYY-MM-DD-amount.cc-description.ext` (amount always includes two decimal places)
- Examples: `2024-01-15-123.45-office-supplies.pdf`, `2024-02-28-100.00-monthly-subscription.pdf`
- Amount in base currency (base currency configurable, default EUR)
- Non-base currency: `YYYY-MM-DD-CUR-amount.cc-description.ext` where CUR is the ISO currency code.

### Abbreviations (Configurable)
The tool comes with a few example abbreviations, adjust to your own needs in `config.yaml`
- svph = St. Vincent's Private Hospital
- svuh = St. Vincent's University Hospital
- nrh = National Rehabilitation Hospital
- mater = Mater Misericordiae University Hospital

## Examples

```bash
# Rename all PDF receipts in current directory
smart-rename -g "receipt*.pdf"
> 

# Process all documents recursively with auto-rename
smart-rename -r -y ".*\.(pdf|jpg|png)$"

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
| `make release` | Full release: test → bump → commit → tag → formula → brew-upgrade |
| `make bump` | Increment patch version (X.Y.Z → X.Y.Z+1) |
| `make tag` | Create and push git tag for current VERSION |
| `make formula` | Update Homebrew formula with version and SHA256 |
| `make brew-upgrade` | Upgrade local Homebrew installation |

The release process automatically:
- Increments the patch version (e.g., 5.20.0 → 5.20.1)
- Commits the version bump
- Creates and pushes a git tag
- Updates the Homebrew formula with new version and SHA256
- Upgrades the local Homebrew installation
- Requires a clean git working directory before starting

## License

MIT License - See LICENSE file for details
