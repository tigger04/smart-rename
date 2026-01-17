#!/usr/bin/env bash
# ABOUTME: Library for text summarization tools with AI model support
# ABOUTME: Provides OpenAI, Claude, and Ollama integration with flexible configuration

# Check for bash v3.2+
if [ "${BASH_VERSINFO[0]}" -lt 3 ] || ([ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]); then
   echo "This script requires bash 3.2 or higher." >&2
   echo "Current version: ${BASH_VERSION}" >&2
   exit 1
fi

# Simple YAML parser for basic key: value pairs
parse_yaml() {
   local yaml_file="$1"
   local prefix="$2"
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')

   sed -ne "s|^\($s\):|\1|" \
       -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
       -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$yaml_file" |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# Load YAML config into variables
load_yaml_config() {
   local yaml_file="$1"
   if [[ -f "$yaml_file" ]]; then
      # Parse YAML and evaluate the output
      eval $(parse_yaml "$yaml_file" "yaml_")

      # Map YAML config to our variables
      [[ -n "${yaml_api_openai_key:-}" ]] && export OPENAI_API_KEY="$yaml_api_openai_key"
      [[ -n "${yaml_api_claude_key:-}" ]] && export CLAUDE_API_KEY="$yaml_api_claude_key"
      [[ -n "${yaml_api_ollama_url:-}" ]] && export OLLAMA_API_URL="$yaml_api_ollama_url"
      [[ -n "${yaml_api_openai_model:-}" ]] && openai_model="$yaml_api_openai_model"
      [[ -n "${yaml_api_claude_model:-}" ]] && claude_model="$yaml_api_claude_model"
      [[ -n "${yaml_api_ollama_model:-}" ]] && ollama_model="$yaml_api_ollama_model"
      [[ -n "${yaml_default_provider:-}" ]] && active_function="$yaml_default_provider"
      [[ -n "${yaml_currency_base:-}" ]] && base_currency="$yaml_currency_base"
      [[ -n "${yaml_prompts_rename:-}" ]] && yaml_prompt_template="$yaml_prompts_rename"

      # Load abbreviations from YAML
      for var in $(compgen -v yaml_abbreviations_); do
         key="${var#yaml_abbreviations_}"
         abbreviations["$key"]="${!var}"
      done
   fi
}

# Load configuration
load_config() {
   local config_dir="$HOME/.config/smart-rename"
   local config_file="$config_dir/config"
   local yaml_config_file="$config_dir/config.yaml"

   # Set defaults
   active_function=""
   ollama_model="mistral"
   openai_model="gpt-4o-mini"
   claude_model="claude-3-5-sonnet-20241022"
   base_currency="EUR"  # Base currency for receipt naming
   source=STDIN
   source_identifier=""
   output_mode=STDOUT
   yaml_prompt_template=""

   # Default abbreviations (medical facilities example)
   declare -gA abbreviations=(
      ["svph"]="St. Vincent's Private Hospital"
      ["svuh"]="St. Vincent's University Hospital"
      ["nrh"]="National Rehabilitation Hospital"
      ["mater"]="Mater Misericordiae University Hospital"
   )

   # Create config directory if it doesn't exist
   if [[ ! -d "$config_dir" ]]; then
      mkdir -p "$config_dir"
   fi

   # Create default YAML config if it doesn't exist
   if [[ ! -f "$yaml_config_file" ]] && [[ -f "$(dirname "${BASH_SOURCE[0]}")/config.example.yaml" ]]; then
      cp "$(dirname "${BASH_SOURCE[0]}")/config.example.yaml" "$yaml_config_file"
   fi

   # Load YAML config first
   load_yaml_config "$yaml_config_file"

   # Load from shell config file if exists (for backwards compatibility)
   if [[ -f "$config_file" ]]; then
      source "$config_file"
   fi

   # Override with environment variables if set
   [[ -n "${OPENAI_API_KEY:-}" ]] && openai_available=true || openai_available=false
   [[ -n "${CLAUDE_API_KEY:-}" ]] && claude_available=true || claude_available=false
   [[ -n "${OLLAMA_API_URL:-}" ]] && ollama_available=true || ollama_available=false

   # Check if ollama is running locally
   if [[ -z "${OLLAMA_API_URL:-}" ]] && command -v ollama >/dev/null 2>&1; then
      if ollama list >/dev/null 2>&1; then
         ollama_available=true
      fi
   fi

   # Auto-detect default if not set
   if [[ -z "$active_function" ]]; then
      if [[ "$openai_available" == true ]]; then
         active_function="openai"
      elif [[ "$claude_available" == true ]]; then
         active_function="claude"
      elif [[ "$ollama_available" == true ]]; then
         active_function="ollama"
      else
         echo "⚠️ No AI service available. Please set OPENAI_API_KEY, CLAUDE_API_KEY, or ensure Ollama is running." >&2
         echo "You can also create a config file at ~/.config/smart-rename/config" >&2
         exit 1
      fi
   fi

   # Override default from config or env
   [[ -n "${DEFAULT_AI:-}" ]] && active_function="${DEFAULT_AI}"
}

# Initialize configuration
load_config

# Simple info function for logging
hline() {
   echo "️🔷️ $*" >&2
}

info() {
   echo "ℹ️ $*" >&2
}

# Ollama API handler
ollama() {
   # Check if using remote or local ollama
   if [[ -n "${OLLAMA_API_URL:-}" ]]; then
      # Use remote Ollama API
      result=$(curl "${OLLAMA_API_URL}/api/generate" \
         -s \
         --max-time 60 \
         --connect-timeout 10 \
         -d "$(jq -n --arg model "$ollama_model" --arg prompt "$prompt" \
            '{model: $model, prompt: $prompt, stream: false}')" 2>/dev/null | jq -r '.response' 2>/dev/null)

      if [[ $? -ne 0 || -z "$result" ]]; then
         echo "❌ Remote Ollama request failed or timed out." >&2
         echo "   URL: ${OLLAMA_API_URL}" >&2
         exit 1
      fi
      output_result "$result"
      return
   fi

   # Use local ollama
   if ! command -v ollama >/dev/null 2>&1; then
      echo "❌ Ollama not found locally and OLLAMA_API_URL not set." >&2
      echo "Install Ollama or set OLLAMA_API_URL in ~/.config/smart-rename/config" >&2
      exit 1
   fi

   # Check if the model is available (with timeout)
   if ! timeout 10 ollama list 2>/dev/null | grep -q "^$ollama_model:"; then
      echo "⚠️ Model '$ollama_model' not found locally." >&2
      echo "Available models:" >&2
      ollama list >&2
      echo >&2
      read -p "Download '$ollama_model'? (y/N): " -n 1 -r >&2
      echo >&2
      if [[ "$REPLY" == [yY] ]]; then
         hline "Downloading model: $ollama_model"
         ollama pull "$ollama_model" || {
            echo "❌ Failed to download model '$ollama_model'." >&2
            exit 1
         }
      else
         echo "❌ Cannot proceed without the model. Exiting." >&2
         exit 1
      fi
   fi

   # Run with timeout and error handling
   result=$(timeout 60 ollama run "$ollama_model" "$prompt" 2>/dev/null)
   if [[ $? -ne 0 ]]; then
      echo "❌ Ollama request failed or timed out." >&2
      echo "   Model: $ollama_model" >&2
      echo "   Check if Ollama service is running: brew services restart ollama" >&2
      exit 1
   fi
   output_result "$result"
}

# OpenAI API handler
openai() {
   # Check if API key is available
   if [[ -z "${OPENAI_API_KEY:-}" ]]; then
      # Try loading from legacy location
      if [[ -f ~/.ssh/.openai-api-key.sh ]]; then
         # shellcheck source=/dev/null
         source ~/.ssh/.openai-api-key.sh
      fi
   fi

   if [[ -z "${OPENAI_API_KEY:-}" ]]; then
      echo "❌ OpenAI API key not found. Please set OPENAI_API_KEY environment variable." >&2
      echo "Or add it to ~/.config/smart-rename/config as: export OPENAI_API_KEY='your-key'" >&2
      exit 1
   fi

   result=$(curl https://api.openai.com/v1/chat/completions \
      -s \
      --max-time 60 \
      --connect-timeout 10 \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg prompt "$prompt" --arg model "$openai_model" \
         '{
            model: $model,
            messages: [
              {
                role: "user",
                content: $prompt
               }
            ]
      }')" 2>/dev/null | jq -r '.choices[0].message.content' 2>/dev/null)

   if [[ $? -ne 0 || -z "$result" || "$result" == "null" ]]; then
      echo "❌ OpenAI API request failed or timed out." >&2
      echo "   Model: $openai_model" >&2
      echo "   Check your API key and network connection." >&2
      exit 1
   fi
   output_result "$result"
}

# Claude API handler
claude() {
   # Check if API key is available
   if [[ -z "${CLAUDE_API_KEY:-}" ]]; then
      # Try loading from legacy location
      if [[ -f ~/.ssh/.claude-api-key.sh ]]; then
         # shellcheck source=/dev/null
         source ~/.ssh/.claude-api-key.sh
      fi
   fi

   if [[ -z "${CLAUDE_API_KEY:-}" ]]; then
      echo "❌ Claude API key not found. Please set CLAUDE_API_KEY environment variable." >&2
      echo "Or add it to ~/.config/smart-rename/config as: export CLAUDE_API_KEY='your-key'" >&2
      exit 1
   fi

   hline "Summarizing text with Claude using API"

   result=$(curl https://api.anthropic.com/v1/messages \
      -s \
      -H "x-api-key: $CLAUDE_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg prompt "$prompt" --arg model "$claude_model" \
         '{
            model: $model,
            max_tokens: 4096,
            messages: [
              {
                role: "user",
                content: $prompt
               }
            ]
      }')" | jq -r '.content[0].text')
   output_result "$result"
}

# Construct prompt from input
construct_prompt() {
   prompt="$pre_prompt"$'\n\n'"--------"$'\n'
   while IFS= read -r line; do
      prompt+=$'\n'"$line"
   done
}

# Get clipboard content
get_clipboard_content() {
   if command -v pbpaste >/dev/null 2>&1; then
      # macOS
      pbpaste
   elif command -v xclip >/dev/null 2>&1; then
      # Linux with xclip
      xclip -selection clipboard -o
   elif command -v xsel >/dev/null 2>&1; then
      # Linux with xsel
      xsel --clipboard --output
   else
      echo "‼️ No clipboard utility found (pbpaste, xclip, or xsel)" >&2
      exit 1
   fi
}

# Get selection content (with delay for copy operation)
get_selection_content() {
   sleep 0.3
   get_clipboard_content
}

# Output result to various destinations
output_result() {
   local result="$1"

   case "$output_mode" in
   STDOUT)
      echo "$result"
      ;;
   NOTIFICATION)
      if command -v notify >/dev/null 2>&1; then
         notify "$result"
      elif command -v osascript >/dev/null 2>&1; then
         # macOS fallback using osascript - escape quotes and limit length
         local notification_text
         notification_text="${result//\"/\\\"}"
         # Truncate if too long for notifications
         if [ ${#notification_text} -gt 200 ]; then
            notification_text="${notification_text:0:197}..."
         fi
         osascript -e "display notification \"$notification_text\" with title \"Text Summary\""
      else
         echo "‼️ ~/bin/notify not found and no notification fallback available" >&2
         echo "$result"
      fi
      ;;
   DIALOG)
      if command -v dialog >/dev/null 2>&1; then
         dialog "$result"
      elif command -v osascript >/dev/null 2>&1; then
         # macOS fallback using osascript
         osascript -e "display dialog \"$result\" with title \"Text Summary\""
      else
         echo "‼️ ~/bin/dialog not found and no dialog fallback available" >&2
         echo "$result"
      fi
      ;;
   TYPE)
      if command -v mactype >/dev/null 2>&1; then
         echo "$result" | mactype
      else
         echo "⚠️ ~/bin/mactype not found - outputting to stdout instead" >&2
         echo "$result"
      fi
      ;;
   PASTE)
      if command -v pbcopy >/dev/null 2>&1; then
         # macOS - copy to clipboard
         echo "$result" | pbcopy
         echo "📋 Result copied to clipboard" >&2
      elif [[ "$OSTYPE" == "darwin"* ]]; then
         # macOS - attempt to paste using skhd
         echo "$result" | pbcopy
         echo "⚠️ skhd paste not implemented - result copied to clipboard instead" >&2
      elif command -v xclip >/dev/null 2>&1; then
         # Linux with xclip
         echo "$result" | xclip -selection clipboard
         echo "📋 Result copied to clipboard" >&2
      elif command -v xsel >/dev/null 2>&1; then
         # Linux with xsel
         echo "$result" | xsel --clipboard --input
         echo "📋 Result copied to clipboard" >&2
      else
         echo "‼️ No clipboard utility found" >&2
         echo "$result"
      fi
      ;;
   *)
      echo "$result"
      ;;
   esac
}

# Fetch content from URL
fetch_url_content() {
   local url="$1"
   if command -v curl >/dev/null 2>&1; then
      curl -s -L "$url" || {
         echo "❌ Failed to fetch URL: $url" >&2
         exit 1
      }
   elif command -v wget >/dev/null 2>&1; then
      wget -q -O - "$url" || {
         echo "❌ Failed to fetch URL: $url" >&2
         exit 1
      }
   else
      echo "‼️ Neither curl nor wget found" >&2
      exit 1
   fi
}

# Parse common command-line arguments
parse_common_arguments() {
   while [ $# -gt 0 ]; do
      case $1 in
      # AI Model options
      -l* | --ollama*)
         active_function=ollama
         if [[ $1 =~ =(.*)$ ]]; then
            ollama_model="${BASH_REMATCH[1]}"
         elif [[ "${1:2:1}" != "" && "${1:0:2}" == "-l" ]]; then
            # Handle -lmodel format
            ollama_model="${1:2}"
         fi
         ;;
      -o* | --openai*)
         active_function=openai
         if [[ $1 =~ =(.*)$ ]]; then
            openai_model="${BASH_REMATCH[1]}"
         elif [[ "${1:2:1}" != "" && "${1:0:2}" == "-o" ]]; then
            # Handle -omodel format
            openai_model="${1:2}"
         fi
         ;;
      --claude*)
         active_function=claude
         if [[ $1 =~ =(.*)$ ]]; then
            claude_model="${BASH_REMATCH[1]}"
         fi
         ;;
      --preprompt* | --prompt*)
         if [[ $1 =~ =(.*)$ ]]; then
            pre_prompt="${BASH_REMATCH[1]}"
         else
            shift
            pre_prompt="$1"
         fi
         ;;
      # Input modes
      -c | --clipboard)
         source=CLIPBOARD
         ;;
      -s | --selection)
         source=SELECTION
         ;;
      # Output modes
      -n | --notification)
         output_mode=NOTIFICATION
         ;;
      -d | --dialog)
         output_mode=DIALOG
         ;;
      -t | --type)
         output_mode=TYPE
         ;;
      -p | --paste)
         output_mode=PASTE
         ;;
      # File input
      -)
         source=STDIN
         ;;
      http://* | https://*)
         source=URL
         source_identifier="$1"
         ;;
      *)
         # Assume it's a file
         if [[ -f "$1" ]]; then
            source=FILE
            source_identifier="$1"
         else
            echo "‼️ Unknown argument or file not found: $1" >&2
            display_help_text_and_die
         fi
         ;;
      esac
      shift
   done
}

# Execute processing based on source
execute_processing() {
   case "$source" in
   STDIN)
      construct_prompt
      ;;
   FILE)
      if [[ -z "$source_identifier" || ! -f "$source_identifier" ]]; then
         echo "‼️ File not found: $source_identifier" >&2
         exit 1
      fi
      construct_prompt < "$source_identifier"
      ;;
   URL)
      if [[ -z "$source_identifier" ]]; then
         echo "‼️ URL not specified" >&2
         exit 1
      fi
      hline "Fetching URL: $source_identifier"
      fetch_url_content "$source_identifier" | construct_prompt
      ;;
   CLIPBOARD)
      get_clipboard_content | construct_prompt
      ;;
   SELECTION)
      get_selection_content | construct_prompt
      ;;
   *)
      echo "‼️ Unknown source: $source" >&2
      exit 1
      ;;
   esac
}