#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ASH_DIR="$HOME/.config/ash"
ASH_SCRIPT_ZSH="$ASH_DIR/ash.zsh"
ASH_SCRIPT_BASH="$ASH_DIR/ash.sh"
CONFIG_FILE="$ASH_DIR/config.json"

declare -A SHELL_CONFIGS=(
    ["zsh"]="$HOME/.zshrc"
    ["bash"]="$HOME/.bashrc"
)

detect_shells() {
    local detected_shells=()

    if command -v zsh >/dev/null 2>&1; then
        detected_shells+=("zsh")
    fi

    if command -v bash >/dev/null 2>&1; then
        detected_shells+=("bash")
    fi
    # if command -v fish >/dev/null 2>&1; then
    #     detected_shells+=("fish")
    # fi

    printf '%s\n' "${detected_shells[@]}"
}

get_current_shell() {
    basename "$SHELL" 2>/dev/null || echo "unknown"
}

print_header() {
    echo -e "${BLUE}               __     ${NC}"
    echo -e "${BLUE}_____    _____|  |__  ${NC}"
    echo -e "${BLUE}\\__  \\  /  ___/  |  \\ ${NC}"
    echo -e "${BLUE} / __ \\_\\___ \\|   Y  \\ ${NC}"
    echo -e "${BLUE}(____  /____  >___|  /${NC}"
    echo -e "${BLUE}     \\/     \\/     \\/${NC}"
    echo
}

print_step() {
    echo -e "${YELLOW}>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_info() {
    echo -e "${BLUE}i${NC} $1"
}

create_ash_script() {
  print_step "Creating ash scripts..."

  local installer_dir="$(dirname "$0")"
  local zsh_source="$installer_dir/ash.zsh"
  local bash_source="$installer_dir/ash.sh"
  local zsh_url="https://raw.githubusercontent.com/NotNanook/Ash/refs/heads/main/ash.zsh"
  local bash_url="https://raw.githubusercontent.com/NotNanook/Ash/refs/heads/main/ash.sh"
  local downloaded_files=()

  mkdir -p "$ASH_DIR"

  download_file() {
    local url="$1"
    local dest="$2"
    local filename="$(basename "$dest")"

    print_info "Downloading $filename from GitHub..."
    if curl -fsSL "$url" -o "$dest"; then
      print_success "Downloaded $filename successfully"
      downloaded_files+=("$dest")
      return 0
    else
      print_error "Failed to download $filename with curl"
      return 1
    fi
  }

  prompt_download() {
    local filename="$1"
    local url="$2"
    local dest="$3"

    echo -n "Do you want to download $filename from GitHub? [y/n]: "
    read -r response
    case "$response" in
      [yY]|[yY][eE][sS])
        if download_file "$url" "$dest"; then
          return 0
        else
          return 1
        fi
        ;;
      *)
        print_info "Skipping download of $filename"
        return 1
        ;;
    esac
  }

  if [[ -f "$zsh_source" ]]; then
    cp "$zsh_source" "$ASH_SCRIPT_ZSH"
    chmod +x "$ASH_SCRIPT_ZSH"
    print_success "zsh ash script created at $ASH_SCRIPT_ZSH"
  else
    print_error "zsh ash source file not found: $zsh_source"
    if prompt_download "ash.zsh" "$zsh_url" "$zsh_source"; then
      cp "$zsh_source" "$ASH_SCRIPT_ZSH"
      chmod +x "$ASH_SCRIPT_ZSH"
      print_success "zsh ash script created at $ASH_SCRIPT_ZSH"
    fi
  fi

  if [[ -f "$bash_source" ]]; then
    cp "$bash_source" "$ASH_SCRIPT_BASH"
    chmod +x "$ASH_SCRIPT_BASH"
    print_success "bash ash script created at $ASH_SCRIPT_BASH"
  else
    print_error "bash ash source file not found: $bash_source"
    if prompt_download "ash.sh" "$bash_url" "$bash_source"; then
      cp "$bash_source" "$ASH_SCRIPT_BASH"
      chmod +x "$ASH_SCRIPT_BASH"
      print_success "bash ash script created at $ASH_SCRIPT_BASH"
    fi
  fi

  if [[ ! -f "$ASH_SCRIPT_ZSH" && ! -f "$ASH_SCRIPT_BASH" ]]; then
    print_error "No ash scripts were created"
    print_info "Please ensure 'ash.zsh' and/or 'ash.sh' are available locally or download them from GitHub"

    for file in "${downloaded_files[@]}"; do
      if [[ -f "$file" ]]; then
        rm -f "$file"
        print_info "Cleaned up downloaded file: $file"
      fi
    done

    return 1
  fi

  print_success "Ash script creation completed successfully"
}

create_config_template() {
    print_step "Creating configuration template..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
    "provider": "enter-your-provider",
    "api_key": "enter-your-api-key",
    "model": "enter-your-model"
}
EOF
        print_success "Configuration template created at $CONFIG_FILE"
        print_info "Please edit $CONFIG_FILE and add your provider, key and model"
    else
        print_info "Configuration file already exists at $CONFIG_FILE"
    fi
}

is_ash_installed() {
    local shell_config="$1"
    grep -q "source.*ash\.zsh\|source.*ash/ash\.zsh\|source.*ash\.sh\|source.*ash/ash\.sh" "$shell_config" 2>/dev/null || \
    grep -q "\. .*ash\.zsh\|\. .*ash/ash\.zsh\|\. .*ash\.sh\|\. .*ash/ash\.sh" "$shell_config" 2>/dev/null
}

install_to_shell() {
    local shell="$1"
    local config_file="${SHELL_CONFIGS[$shell]}"
    local ash_script

    case "$shell" in
        "zsh")
            ash_script="$ASH_SCRIPT_ZSH"
            ;;
        "bash")
            ash_script="$ASH_SCRIPT_BASH"
            ;;
        *)
            print_error "Unsupported shell: $shell"
            return 1
            ;;
    esac

    if [[ -z "$config_file" ]]; then
        print_error "No configuration file defined for $shell"
        return 1
    fi

    if [[ ! -f "$ash_script" ]]; then
        print_error "ash script for $shell not found: $ash_script"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        touch "$config_file"
        print_info "Created $config_file"
    fi

    if is_ash_installed "$config_file"; then
        print_info "ash is already installed in $config_file"
        return 0
    fi

    cat >> "$config_file" << EOF

# BEGIN ash
if [[ -f "$ash_script" ]]; then
    source "$ash_script"
fi
# END ash
EOF

    print_success "ash installed to $config_file"
    return 0
}

check_dependencies() {
    print_step "Checking dependencies..."

    local missing_deps=()

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi

    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies and run the installer again"
        return 1
    fi

    print_success "All dependencies are available"
    return 0
}

main() {
    print_header

    if ! check_dependencies; then
        exit 1
    fi

    print_step "Detecting installed shells..."
    local detected_shells=($(detect_shells))
    local current_shell=$(get_current_shell)

    if [[ ${#detected_shells[@]} -eq 0 ]]; then
        print_error "No supported shells detected"
        print_info "Currently supported: ${!SHELL_CONFIGS[*]}"
        exit 1
    fi

    print_success "Detected shells: ${detected_shells[*]}"
    print_info "Current shell: $current_shell"
    echo

    create_ash_script

    create_config_template
    echo

    print_step "Installing ash to shell configurations..."
    local installed_to=()

    for shell in "${detected_shells[@]}"; do
        echo -n "Install ash to $shell"
        if [[ "$shell" == "$current_shell" ]]; then
            echo -n " (current shell)"
        fi
        echo -n "? [Y/n] "

        read -r response
        response=${response:-Y}

        if [[ "$response" =~ ^[Yy]$ ]]; then
            if install_to_shell "$shell"; then
                installed_to+=("$shell")
            fi
        else
            print_info "Skipped $shell installation"
        fi
        echo
    done

    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Installation Complete         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo

    if [[ ${#installed_to[@]} -gt 0 ]]; then
        print_success "ash installed to: ${installed_to[*]}"
        echo
        print_info "Next steps:"
        echo "  1. Edit $CONFIG_FILE to choose your provier, model and API key"
        echo "  2. Restart your shell"
        echo "  3. Try typing an unknown command to test ash"
    else
        print_info "No shells were configured. Run the installer again to set up ash."
    fi
}

main "$@"
