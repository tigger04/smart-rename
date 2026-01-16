# smart-rename

AI-powered file renaming tool that generates intelligent, descriptive filenames based on file content.

## Features

- Analyze file content and generate smart filenames
- Special formatting for receipts/invoices (YYYY-MM-DD-amount-description)
- Support for multiple currencies with configurable base currency
- Batch processing with pattern matching (regex or glob)
- Multiple AI provider support (OpenAI, Claude, Ollama)
- Interactive or automatic rename mode

## Quick Start

```bash
brew tap tigger04/tap
brew install smart-rename
```

## Configuration

The tool automatically detects available AI providers and uses the first available one. Configuration is loaded in this order:

1. **Environment variables** (highest priority)
2. **Config file**: `~/.config/smart-rename/config`
3. **Built-in defaults**

### Quick Setup

```bash
# Create config directory
mkdir -p ~/.config/smart-rename

# Copy example config
cp config.example ~/.config/smart-rename/config

# Edit with your API keys
nano ~/.config/smart-rename/config
```

### Configuration Options

```bash
# ~/.config/smart-rename/config

# API Keys (set at least one)
export OPENAI_API_KEY="sk-..."
export CLAUDE_API_KEY="sk-ant-..."
# export OLLAMA_API_URL="http://localhost:11434"  # Optional: remote Ollama

# Default provider (optional - auto-detects if not set)
export DEFAULT_AI="openai"  # or "claude" or "ollama"

# Model configurations
openai_model="gpt-4o-mini"
claude_model="claude-3-5-sonnet-20241022"
ollama_model="mistral"

# Base currency for receipts (default: EUR)
base_currency="EUR"  # Can be USD, GBP, etc.

# Custom abbreviations (these are defaults, customize as needed)
declare -A abbreviations=(
  ["svph"]="St. Vincent's Private Hospital"
  ["svuh"]="St. Vincent's University Hospital"
  ["nrh"]="National Rehabilitation Hospital"
  ["mater"]="Mater Misericordiae University Hospital"
  # Add your own custom abbreviations here
)
```

### Auto-Detection

- If only one API key is provided, that provider becomes the default
- If multiple keys are available, preference order: OpenAI → Claude → Ollama
- If no API keys but Ollama is running locally, uses Ollama

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

### Abbreviations (Configurable)
The tool comes with default medical facility abbreviations which can be customized in the config file:
- svph = St. Vincent's Private Hospital
- svuh = St. Vincent's University Hospital
- nrh = National Rehabilitation Hospital
- mater = Mater Misericordiae University Hospital

Add your own abbreviations in `~/.config/smart-rename/config`

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