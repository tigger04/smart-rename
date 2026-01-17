# smart-rename

AI-powered file renaming tool that generates intelligent, descriptive filenames based on file content.

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

## License

MIT License - See LICENSE file for details
