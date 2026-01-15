# smart-rename

AI-powered file renaming tool that generates intelligent, descriptive filenames based on file content.

## Features

- Analyze file content and generate smart filenames
- Special formatting for receipts/invoices (YYYY-MM-DD-amount-description)
- Support for multiple currencies with configurable base currency
- Batch processing with pattern matching (regex or glob)
- Multiple AI provider support (OpenAI, Claude, Ollama)
- Interactive or automatic rename mode

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/smart-rename.git
cd smart-rename

# Make executable
chmod +x smart-rename

# Optional: Link to PATH
ln -s "$(pwd)/smart-rename" /usr/local/bin/smart-rename
```

## Configuration

The tool looks for configuration in the following order:
1. Environment variables: `OPENAI_API_KEY`, `CLAUDE_API_KEY`, `OLLAMA_API_URL`
2. Config file: `~/.config/smart-rename/config`

### Example config file

```bash
# ~/.config/smart-rename/config
export OPENAI_API_KEY="your-openai-key"
export CLAUDE_API_KEY="your-claude-key"
export DEFAULT_AI="openai"  # or "claude" or "ollama"

# Model configurations
openai_model="gpt-4o-mini"
claude_model="claude-3-5-sonnet-20241022"
ollama_model="mistral"

# Base currency for receipts (default: EUR)
base_currency="EUR"  # Can be USD, GBP, etc.
```

## Usage

```bash
# Process files matching pattern (interactive mode)
smart-rename "receipt.*\.pdf"

# Auto-rename without confirmation
smart-rename -y invoice.pdf

# Search recursively
smart-rename -r "*.docx"

# Use glob pattern instead of regex
smart-rename -g "*.pdf"

# Use specific AI provider
smart-rename --claude document.pdf
smart-rename --openai receipt.jpg
```

## Options

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
- Format: `YYYY-MM-DD-amount-description.ext`
- Amount in base currency (configurable, default EUR)
- Other currencies: `YYYY-MM-DD-CUR-amount-description.ext`

### Medical Abbreviations
The tool recognizes common medical facility abbreviations:
- svph = St. Vincent's Private Hospital
- svuh = St. Vincent's University Hospital
- nrh = National Rehabilitation Hospital
- mater = Mater Misericordiae University Hospital

## Examples

```bash
# Rename all PDF receipts in current directory
smart-rename -g "receipt*.pdf"

# Process all documents recursively with auto-rename
smart-rename -r -y ".*\.(pdf|jpg|png)$"

# Use custom base currency (USD instead of EUR)
echo 'base_currency="USD"' >> ~/.config/smart-rename/config
smart-rename receipt.pdf
```

## License

MIT License - See LICENSE file for details