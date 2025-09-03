# BEGIN ash
CONFIG_DIR="$HOME/.config/ash"
CONFIG_FILE="$CONFIG_DIR/config.json"
CHAT_HISTORY="$CONFIG_DIR/conversation.json"
CHATGPT_MAX_HISTORY=15

__get_attr() {
  local key="$1"
  local attr=$(jq -r --arg k "$key" '.[$k]' "$CONFIG_FILE")
  if [[ -z "$attr" || "$attr" == "null" ]]; then
    echo "$1 not specified in config file $CONFIG_FILE" >&2
    return 1
  fi 

  echo "$attr"
}

__init_ash() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE" >&2
    return 1
  fi

  if [[ ! -f "$CHAT_HISTORY" ]]; then
    cat > "$CHAT_HISTORY" <<EOF
[
    {
        "role": "system",
        "content": "You are a helpful assistant working in a terminal. You are to act as an extension of the shell and reply with short and precise responses. If the user provides something that appears to be a mistyped command, simply answer with 'Did you mean to use the following command?', followed by the actual command. LaTeX and Markdown isnt supported so only use supported terminal formatting schemes."
    }
]
EOF
  fi
}

__load_conversation() {
  if [[ -f "$CHAT_HISTORY" ]]; then
    cat "$CHAT_HISTORY"
  else
    echo "[]"
  fi
}

__save_conversation() {
  local messages="$1"
  printf '%s' "$messages" > "$CHAT_HISTORY"
}

__trim_conversation() {
  local messages="$1"
  local count=$(printf '%s' "$messages" | jq '. | length')
  if [[ $count -gt $CHATGPT_MAX_HISTORY ]]; then
    printf '%s' "$messages" | jq ".[0:1] + .[-$((CHATGPT_MAX_HISTORY-1)):]"
  else
    printf '%s' "$messages"
  fi
}

__exec_and_wait() {
  local tmp
  tmp=$(mktemp) || tmp="/tmp/$$.out"

  # Start the command in background redirecting its stdout/stderr to tmp.
  "$@" >"$tmp" 2>&1 &
  local pid=$!

  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local i=0

  # Hide cursor
  printf '\033[?25l' >&2

  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s' "${frames[i]}" >&2
    sleep 0.1
    i=$(((i + 1) % ${#frames[@]}))
  done

  # Erase spinner and restore cursor on stderr.
  printf '\r \r' >&2
  printf '\033[?25h' >&2

  wait "$pid"
  local exit_code=$?

  cat "$tmp"
  rm -f "$tmp"
  return $exit_code
}

__send_to_ollama() {
  local prompt="$1"

  __init_ash

  local messages=$(__load_conversation)
  messages=$(printf '%s' "$messages" | jq --arg prompt "$prompt" '. + [{"role": "user", "content": $prompt}]')
  messages=$(__trim_conversation "$messages")

  local json_payload
  json_payload=$(jq -n \
    --arg model "$(__get_attr 'model')" \
    --argjson messages "$messages" \
    '{
      "model": $model,
      "messages": $messages,
      "stream": false
    }')

  local response
  response=$(__exec_and_wait curl -s -X POST "http://localhost:11434/api/chat" \
    -H "Content-Type: application/json" \
    -d "$json_payload")
  local curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    echo "Error: Failed to connect to Ollama API"
    return 1
  fi

  local content
  content=$(printf '%s' "$response" | jq -r '.message.content')
  messages=$(printf '%s' "$messages" | jq --arg content "$content" '. + [{"role": "assistant", "content": $content}]')
  __save_conversation "$messages"
  echo "$content"
  return 0
}

__send_to_anthropic() {
  local prompt="$1"

  __init_ash

  local messages=$(__load_conversation)
  messages=$(printf '%s' "$messages" | jq --arg prompt "$prompt" '. + [{"role": "user", "content": $prompt}]')
  messages=$(__trim_conversation "$messages")

  local system_content
  system_content=$(printf '%s' "$messages" | jq -r '.[0] | select(.role == "system") | .content')
  local chat_messages
  chat_messages=$(printf '%s' "$messages" | jq '[.[] | select(.role != "system")]')

  local json_payload
  json_payload=$(jq -n \
    --arg model "$(__get_attr 'model')" \
    --arg system "$system_content" \
    --argjson messages "$chat_messages" \
    --arg max_tokens "4096" \
    '{
      "model": $model,
      "system": $system,
      "messages": $messages,
      "max_tokens": ($max_tokens | tonumber)
    }')

  local response
  response=$(__exec_and_wait curl -s -X POST "https://api.anthropic.com/v1/messages" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $(__get_attr 'api_key')" \
    -H "anthropic-version: 2023-06-01" \
    -d "$json_payload")
  local curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    echo "Error: Failed to connect to Claude API"
    return 1
  fi

  local content
  content=$(printf '%s' "$response" | jq -r '.content[0].text')
  messages=$(printf '%s' "$messages" | jq --arg content "$content" '. + [{"role": "assistant", "content": $content}]')
  __save_conversation "$messages"
  echo "$content"
  return 0
}

__send_to_openai() {
  local prompt="$1"

  __init_ash

  local messages=$(__load_conversation)
  messages=$(printf '%s' "$messages" | jq --arg prompt "$prompt" '. + [{"role": "user", "content": $prompt}]')
  messages=$(__trim_conversation "$messages")

  local json_payload
  json_payload=$(jq -n \
    --arg model "$(__get_attr 'model')" \
    --argjson messages "$messages" \
    '{
      "model": $model,
      "messages": $messages
    }')

  local response
  response=$(__exec_and_wait curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(__get_attr 'api_key')" \
    -d "$json_payload")
  local curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    echo "Error: Failed to connect to OpenAI API"
    return 1
  fi

  local content
  content=$(printf '%s' "$response" | jq -r '.choices[0].message.content')
  messages=$(printf '%s' "$messages" | jq --arg content "$content" '. + [{"role": "assistant", "content": $content}]')
  __save_conversation "$messages"
  echo "$content"
  return 0
}

command_not_found_handle() {
  local cmd="$1"
  shift
  local args="$*"
  local prompt="$cmd $args"
  local stdin_content=""
    
  if [[ ! -t 0 ]]; then
    stdin_content=$(cat)
    if [[ -n "$stdin_content" ]]; then
      prompt="Input data:\n$stdin_content\n\n Instruction: $prompt"
    fi
  fi
    
  local provider=$(__get_attr 'provider')
  if [[ ${#prompt} -gt 3 ]]; then
    # Convert provider to lowercase for case-insensitive matching
    provider=$(echo "$provider" | tr '[:upper:]' '[:lower:]')
    case "$provider" in 
    "openai")
      __send_to_openai "$prompt"
      ;;
    "anthropic")
      __send_to_anthropic "$prompt"
      ;;
    "ollama")
      __send_to_ollama "$prompt"
      ;;
    esac 
    return 0
  fi

  return 127
}
# END ash
