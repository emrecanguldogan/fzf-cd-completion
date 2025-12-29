#!/usr/bin/env bash

# =========================================================
# SHELL CHECK
# =========================================================

# Checks bash version to ensure the script runs in Bash.
# Zsh, Fish, etc. do not have this variable.
if [ -z "$BASH_VERSION" ]; then
    printf "\033[0;31m[ERROR] This widget is designed strictly for Bash.\033[0m\n"
    printf "You seem to be running it from an unsupported shell (sh, zsh, fish etc.).\n\n"
    
    printf "To install with conflict detection (bind -x), switch to Bash and run:\n"
    printf "  \033[1msource setup.sh\033[0m\n\n"
    
    printf "Alternatively, you can run:\n"
    printf "  \033[1mbash setup.sh\033[0m\n\n"
    printf "(Note: This mode cannot detect existing 'bind -x' key conflicts).\n"
    
    # Universal exit: works for both sourced and executed scripts
    return 1 2>/dev/null || exit 1
fi

# =========================================================
# 2. MAIN SETUP FUNCTION
# =========================================================

run_setup_wizard() {
    # --- Configuration ---
    local INSTALL_DIR="$HOME/.fzf-cd-completion"
    local SCRIPT_NAME="fzf_cd_completion.sh"
    local RC_FILE="$HOME/.bashrc"

    # Colors & Styling
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local CYAN='\033[0;36m'
    local BOLD='\033[1m'
    local NC='\033[0m' # No Color

    echo -e "${BLUE}${BOLD}🚀 fzf_cd_completion Setup Wizard${NC}"
    echo "---------------------------------------------------"

    # --- Step 1: Environment Checks ---
    if ((BASH_VERSINFO[0] < 4)); then
        echo -e "${RED}[ERROR] Bash version 4.0 or higher is required.${NC}"
        return 1
    fi

    if ! command -v fzf &> /dev/null; then
        echo -e "${RED}[ERROR] 'fzf' command not found. Please install fzf first.${NC}"
        return 1
    fi

    local SED_CMD="sed"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v gsed &> /dev/null; then
             echo -e "${YELLOW}[WARNING] macOS detected. 'gnu-sed' is required (brew install gnu-sed).${NC}"
             return 1
        fi
        SED_CMD="gsed"
    fi

    # --- Step 2: File Installation / Verification ---
    echo -e "${BLUE}[*] Checking installation files...${NC}"
    
    local SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    mkdir -p "$INSTALL_DIR"

    if [[ "$SOURCE_DIR" != "$INSTALL_DIR" ]]; then
        local FILES=("$SCRIPT_NAME" "LICENSE" "README.md" "setup.sh")
        for file in "${FILES[@]}"; do
            if [[ -f "$SOURCE_DIR/$file" ]]; then
                cp "$SOURCE_DIR/$file" "$INSTALL_DIR/"
                echo "    -> Copied: $file"
            else
                if [[ "$file" == "$SCRIPT_NAME" ]]; then
                    echo -e "${RED}[ERROR] Missing critical file: $file${NC}"
                    return 1
                fi
            fi
        done
        echo -e "${GREEN}    -> Files installed to $INSTALL_DIR${NC}"
    else
        echo -e "${GREEN}    -> Script running from install dir. Skipping copy.${NC}"
    fi

    # --- Helper Functions (Nested) ---
    
    translate_to_fzf() {
        local raw="$1"
        local char_code="$2"
        
        # 1. Handle Function Keys & Arrows
        case "$raw" in
            *"\eOP"|*"\EOP") echo "f1"; return ;;
            *"\eOQ"|*"\EOQ") echo "f2"; return ;;
            *"\eOR"|*"\EOR") echo "f3"; return ;;
            *"\eOS"|*"\EOS") echo "f4"; return ;;
            *"\e[15~") echo "f5"; return ;;
            *"\e[17~") echo "f6"; return ;;
            *"\e[18~") echo "f7"; return ;;
            *"\e[19~") echo "f8"; return ;;
            *"\e[20~") echo "f9"; return ;;
            *"\e[21~") echo "f10"; return ;;
            *"\e[23~") echo "f11"; return ;;
            *"\e[24~") echo "f12"; return ;;
            *"\e[A")   echo "up"; return ;;
            *"\e[B")   echo "down"; return ;;
            *"\e[C")   echo "right"; return ;;
            *"\e[D")   echo "left"; return ;;
            *"\e[Z")   echo "btab"; return ;; 
        esac

        # 2. Handle Control Keys
        if [[ "$raw" =~ \\C-([a-z]) ]]; then
            echo "ctrl-${BASH_REMATCH[1]}"; return
        fi
        
        # 3. Handle Alt Keys
        if [[ "$raw" =~ \\e([a-zA-Z0-9]) ]]; then
            echo "alt-${BASH_REMATCH[1]}"; return
        fi
        
        # 4. Special Keys
        case "$char_code" in
            9) echo "tab" ;;
            127) echo "bspace" ;;
            27) echo "esc" ;;
        esac
    }

    capture_key() {
        echo -e "${YELLOW}👉 Press the desired key combination NOW...${NC}" >&2
        
        read -rsn1 input
        if [[ "$input" == $'\e' ]]; then
            read -rsn5 -t 0.1 rest
            input="$input$rest"
        fi
        
        # -- Bash Format Calculation --
        local raw_esc
        raw_esc=$(printf "%q" "$input")

        # Clean output
        local bash_seq="${raw_esc#$\'}"
        bash_seq="${bash_seq%\'}"
        bash_seq="${bash_seq//\\E/\\e}"
        
        # Detect Ctrl keys manually
        local char_code=0
        if [[ ${#input} -eq 1 ]]; then
            char_code=$(printf "%d" "'$input")
            if (( char_code >= 1 && char_code <= 26 )); then
                 local char=$(printf "\\$(printf '%03o' $((char_code + 96)))")
                 bash_seq="\\C-$char"
            fi
        fi

        # -- FZF Format Translation --
        local fzf_name
        fzf_name=$(translate_to_fzf "$bash_seq" "$char_code")
        [[ -z "$fzf_name" ]] && fzf_name="unknown-key"

        echo "${bash_seq}|${fzf_name}"
    }

    check_collision() {
        local seq="$1"
        local collision_info=""
        
        # 1. Check Standard Bindings
        local out_p
        out_p=$(bind -p 2>/dev/null | grep -F "\"$seq\"") || true

        # 2. Check Macro/Command Bindings
        local out_x
        out_x=$(bind -X 2>/dev/null | grep -F "\"$seq\"") || true
        
        if [[ -n "$out_p" ]]; then collision_info="$out_p";
        elif [[ -n "$out_x" ]]; then collision_info="$out_x (External Command/Widget)"; fi

        if [[ -n "$collision_info" ]]; then
            # Escape backslashes for visual display in echo -e
            local visual_seq="${seq//\\/\\\\}"
            echo -e "${RED}[WARNING] Key sequence '${visual_seq}' is already bound via:${NC}" >&2
            echo "    $collision_info" >&2
            return 0 # Collision Exists
        fi
        return 1 # No Collision
    }

    # --- Step 3: Interactive Key Binding Configuration ---
    echo -e "\n${BLUE}[*] Configure Key Binding${NC}"
    echo -e "Which key do you want to use to trigger the fuzzy completion?"

    local options=("F1 (Default)" "Alt-K (Recommended)" "Custom Key (Press your own)")
    PS3=$'\n> Select an option (1-3): '
    
    local SELECTED_SEQ=""
    local SELECTED_FZF_NAME=""

    select opt in "${options[@]}"; do
        case $REPLY in
            1) SELECTED_SEQ='"\eOP"'; SELECTED_FZF_NAME="f1"; break ;;
            2) SELECTED_SEQ='"\ek"'; SELECTED_FZF_NAME="alt-k"; break ;;
            3)
                while true; do
                    RESULT=$(capture_key)
                    RAW_SEQ="${RESULT%%|*}"
                    FZF_NAME="${RESULT##*|}"
                    
                    if [[ "$FZF_NAME" == "unknown-key" ]]; then
                        echo -e "${RED}[ERROR] Could not identify FZF key name for '$RAW_SEQ'.${NC}" >&2
                        echo -e "${YELLOW}Supported: Ctrl-x, Alt-x, F1-F12, Tab...${NC}" >&2
                        continue
                    fi
                    
                    # Visual escape correction for display
                    local VISUAL_SEQ="${RAW_SEQ//\\/\\\\}"
                    echo -e "Detected: ${CYAN}\"$VISUAL_SEQ\"${NC} -> FZF: ${CYAN}$FZF_NAME${NC}" >&2
                    
                    if check_collision "$RAW_SEQ"; then
                        echo -e "${YELLOW}Overwriting might break existing shortcuts.${NC}" >&2
                        read -p "Collision detected! Use anyway? (y/N): " confirm < /dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            SELECTED_SEQ="\"$RAW_SEQ\""; SELECTED_FZF_NAME="$FZF_NAME"; break
                        fi
                    else
                        SELECTED_SEQ="\"$RAW_SEQ\""; SELECTED_FZF_NAME="$FZF_NAME"; break
                    fi
                    echo "Let's try again..." >&2
                done
                break
                ;;
            *) echo "Invalid option. Please try again.";;
        esac
    done

    # --- Step 4: Update .bashrc ---
    echo -e "\n${BLUE}[*] Updating $RC_FILE...${NC}"

    # Ask for backup
    # < /dev/tty ensures reading from keyboard even when sourced
    echo -n "Do you want to create a backup of .bashrc? (Y/n): "
    read -r backup_choice < /dev/tty
    # Default to Yes if empty
    backup_choice=${backup_choice:-y}

    if [[ "$backup_choice" =~ ^[Yy] ]]; then
        local BACKUP_FILE="${RC_FILE}.bak.$(date +%s)"
        cp "$RC_FILE" "$BACKUP_FILE"
        echo -e "${GREEN}    -> Backup created at:${NC} $BACKUP_FILE"
    else
        echo -e "${YELLOW}    -> Skipping backup.${NC}"
    fi

    # Clean old configuration
    $SED_CMD -i '/# --- fzf_cd_completion start ---/,/# --- fzf_cd_completion end ---/d' "$RC_FILE"
    
    # Ensure newline at EOF
    [[ $(tail -c1 "$RC_FILE" | wc -l) -eq 0 ]] && echo "" >> "$RC_FILE"

    # Append New Configuration
    cat <<EOT >> "$RC_FILE"
# --- fzf_cd_completion start ---
# Binding: $SELECTED_FZF_NAME
export FZF_START_KEY_SEQ='$SELECTED_SEQ'
export FZF_ACCEPT_KEY_NAME="$SELECTED_FZF_NAME"

if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    source "$INSTALL_DIR/$SCRIPT_NAME"
fi
# --- fzf_cd_completion end ---
EOT

    # Visual escape for final summary
    local FINAL_VISUAL_SEQ="${SELECTED_SEQ//\\/\\\\}"

    echo -e "${GREEN}✅ Setup Complete!${NC}"
    echo "---------------------------------------------------"
    echo -e "Key binding set to: ${CYAN}$FINAL_VISUAL_SEQ${NC} (FZF accepts with: $SELECTED_FZF_NAME)"
    echo ""
    echo -e "1. To apply changes now, run:"
    echo -e "   ${YELLOW}source $RC_FILE${NC}"
    echo ""
    echo -e "2. To change settings later (re-configure), run:"
    echo -e "   ${YELLOW}source $INSTALL_DIR/setup.sh${NC}"
    
    return 0
}

# =========================================================
# ENTRY POINT
# =========================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Sourced
    run_setup_wizard "$@"
else
    # Executed
    run_setup_wizard "$@"
    exit $?
fi
