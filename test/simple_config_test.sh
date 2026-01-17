#!/usr/bin/env bash
# Test simple config parsing without Python dependency

# Simple config parser that extracts key values from YAML-like files
parse_simple_config() {
   local config_file="$1"

   echo "Loading config from: $config_file"

   # Extract values using grep and sed - much more reliable than Python
   local openai_key=$(grep -A10 "^[[:space:]]*openai:" "$config_file" | grep -E "^[[:space:]]*key:[[:space:]]*[\"']" | head -1 | sed -E 's/.*key:[[:space:]]*["\047]([^"\047]*)["\047].*/\1/')
   local claude_key=$(grep -A10 "^[[:space:]]*claude:" "$config_file" | grep -E "^[[:space:]]*key:[[:space:]]*[\"']" | head -1 | sed -E 's/.*key:[[:space:]]*["\047]([^"\047]*)["\047].*/\1/')
   local ollama_url=$(grep -A10 "^[[:space:]]*ollama:" "$config_file" | grep -E "^[[:space:]]*url:[[:space:]]*[\"']" | head -1 | sed -E 's/.*url:[[:space:]]*["\047]([^"\047]*)["\047].*/\1/')

   echo "OpenAI key: '$openai_key'"
   echo "Claude key: '$claude_key'"
   echo "Ollama URL: '$ollama_url'"

   # Only set if not empty
   [[ -n "$openai_key" ]] && export OPENAI_API_KEY="$openai_key"
   [[ -n "$claude_key" ]] && export CLAUDE_API_KEY="$claude_key"
   [[ -n "$ollama_url" ]] && export OLLAMA_API_URL="$ollama_url"
}

# Test it
parse_simple_config ~/.config/smart-rename/config.yaml