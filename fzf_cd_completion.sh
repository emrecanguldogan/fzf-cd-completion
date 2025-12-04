#!/usr/bin/env bash

# ==============================================================================
# FZF CD Completion Widget
#
# Description:
#   A robust, context-aware directory navigation widget using fzf.
#   It handles edge cases like filenames with newlines, complex quoting/escaping,
#   and locale-specific character normalization (specifically for Turkish).
#
# Key Features:
#   1. Zero-dependency path parsing (State Machine implementation).
#   2. Safe filename handling (Null-terminated streams).
#   3. Context-aware directory listing: Lists contents of the current directory 
#      or the partial path argument
#   4. Interactive hidden file toggling (Ctrl+T) within fzf.
#   5. Locale aware fast completion: Supports Language specific character normalization
#      for accurate, case-insensitive matching. (Only Turkish support added for now)
#   6. Tilde (~) expansion preservation: Correctly handles and preserves the '~' 
#      symbol in the final Readline output.
#   7. Shortcut support: Automatically completes '..' to '../' to speed up navigation.
#   8. Flag safety: Automatically prepends the '-- ' argument delimiter before 
#      paths starting with a dash (e.g., 'cd -dir') to prevent flag misinterpretation.
#   9. Screen stability: Uses **tput smcup/rmcup** to prevent fzf from causing visual 
#      corruption in some cases
#
# Requires:
#   1. Bash version must be 4.0 or higher.
#   2. fzf (Fuzzy Finder) must be installed and available in the PATH.
#   3. Core and Terminal Compatibility: 
#       a. GNU sed for '-z' flag support (null-terminated streams), 
#           * Linux: Supported (GNU sed).
#           * MacOS: The default BSD sed **does not support** the '-z' flag.
#                    MacOS users must install GNU sed via Homebrew 'brew install gnu-sed'.
#
#       b. find for safe output flags, '-print0' and '-printf'.
#           * Linux/macOS: Generally supported by both GNU and BSD versions.
#
#       c. Standard awk for locale-aware filtering 
#
#   4. tput (smcup/rmcup) is required to properly isolate fzf in the alternate screen buffer.
#      This help preventing visual artifacts during terminal resizing/tiling.
#
# Note: Not tested in MacOS. But if requirements satisfied, the code should be working properly. 
# ==============================================================================

# -- Configuration & Defaults --
# Use parameter expansion with defaults to allow external overrides.
FZF_START_KEY_SEQ="${1:-${FZF_START_KEY_SEQ:-}}"
FZF_ACCEPT_KEY_NAME="${2:-${FZF_ACCEPT_KEY_NAME:-f1}}"

# Standard fzf options: 40% height, reverse layout for better UX near the prompt.
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} --height 40% --layout=reverse"

# Initialize persistent state for hidden directory visibility (default is off).
# This ensures the preference is remembered throughout the terminal session.
if [[ -z "${_FZF_CD_SHOW_HIDDEN:-}" ]]; then
    export _FZF_CD_SHOW_HIDDEN=0
fi

# ==============================================================================
# Helper Functions
# ==============================================================================

# -- Access Verification --
# Checks if a directory is valid, executable (traversable), and readable.
# This ensure reliable directory listing and to allow the widget to distinguish between 
# empty results and inaccessible paths for better user feedback.
_fzf_cd_check_access() {
    local target_dir="$1"
    [ -d "$target_dir" ] && [ -x "$target_dir" ] && [ -r "$target_dir" ]
}

# -- Stream Encoder --
# This utility converts the NULL-delimited path stream (from 'find -print0') 
# into a safe, newline-delimited list suitable for FZF processing.
# 1. Escapes special characters (\, \n, \r, \t) to literal strings for
#    prevent FZF from treating them as line breaks or control sequences.
# 2. Converts the NULL byte delimiter (\0) into the expected newline (\n) delimiter.
_fzf_cd_stream_encoder() {
    sed -z 's/\\/\\\\/g;s/\n/\\n/g;s/\r/\\r/g;s/\t/\\t/g' | tr '\0' '\n'
}

# -- Directory Discovery --
# Lists directories and symbolic links in the target path.
# Executes in a subshell to avoid changing the current shell's working directory.
# It uses two separate 'find' commands when including hidden files to establish a 
# display priority order before encoding the paths for FZF.
_fzf_cd_get_dirs() {
    local target_dir="$1"
    local include_hidden="${_FZF_CD_SHOW_HIDDEN}"
    
    (
        cd "$target_dir" 2>/dev/null || exit 1

        # -maxdepth 1 is used to limit the search depth to the current directory.
        # -xtype d is used to include symbolic links pointing to directories.
        # -printf '%P\0' is used to output relative paths null-terminated for safety.
        
        if [[ "$include_hidden" == "1" ]]; then
            # Hidden and visible directories are listed and sorted separately to manage 
            # their display priority within the FZF results. (First hidden then visible listed)
            find . -maxdepth 1 -mindepth 1 \( -type d -o -type l -xtype d \) -name '.*' -printf '%P\0' 2>/dev/null | _fzf_cd_stream_encoder | sort -f
            
            find . -maxdepth 1 -mindepth 1 \( -type d -o -type l -xtype d \) -not -name '.*' -printf '%P\0' 2>/dev/null | _fzf_cd_stream_encoder | sort -f
        else
            find . -maxdepth 1 -mindepth 1 \( -type d -o -type l -xtype d \) -not -name '.*' -printf '%P\0' 2>/dev/null | _fzf_cd_stream_encoder | sort -f
        fi
    )
}

# -- Path Parser (State Machine) --
# This manual parser converts the raw Readline input string, which may contain 
# complex Bash quoting and escaping, into a real, unescaped filesystem path.
#
# It securely handles: Backslash (\), Single Quote ('), Double Quote ("), and 
# ANSI C-quoting ($'...'). Using this state machine avoids the security risks 
# associated with 'eval' for path resolution.
_fzf_cd_real_path() {
    local input="$1"
    local -i i=0
    local len=${#input}
    local out=""

    # Initial States: NORMAL, ANSI_QUOTE, SINGLE_QUOTE, DOUBLE_QUOTE
    local state="NORMAL" 

    while (( i < len )); do
        local c="${input:i:1}"
        
        # === 1. NORMAL STATE: Handles initial parsing and state transitions ===
        if [[ "$state" == "NORMAL" ]]; then
            if [[ "$c" == '\' ]]; then
                # Handle standard backslash escape (e.g., 'cd file\ name')
                (( i++ ))
                [[ $i -lt $len ]] && out+="${input:i:1}"
            elif [[ "$c" == '$' ]] && [[ "${input:i+1:1}" == "'" ]]; then
                # Transition to ANSI-C Quoting mode (e.g., $'path')
                state="ANSI_QUOTE"
                (( i++ )) # Consume the '$'
            elif [[ "$c" == "'" ]]; then
                 # Transition to Single Quoting mode
                 state="SINGLE_QUOTE"
            elif [[ "$c" == '"' ]]; then
                 # Transition to Double Quoting mode
                 state="DOUBLE_QUOTE"
            else
                # Default: Append character literally
                out+="$c"
            fi
            
        # === 2. ANSI-C QUOTE STATE: Handles $'...' syntax ===
        elif [[ "$state" == "ANSI_QUOTE" ]]; then
            if [[ "$c" == "'" ]]; then
                # When the closing single quote is encountered, exit to the NORMAL state.
                state="NORMAL"
            elif [[ "$c" == '\' ]]; then
                # Handle C-style escape sequences (e.g., \n, \t, \r, \\) by converting 
                # the escaped sequence to its corresponding literal byte value.
                (( i++ ))
                local next="${input:i:1}"
                # Convert specific ANSI escapes to literal bytes
                case "$next" in
                    n) out+=$'\n' ;;
                    r) out+=$'\r' ;;
                    t) out+=$'\t' ;;
                    \\) out+='\' ;;
                    \') out+="'" ;;
                    *) out+="$next" ;;
                esac
            else
                # Append all other characters literally.
                out+="$c"
            fi
            
        # === 3. SINGLE QUOTE STATE: Handles '...' syntax ===
        elif [[ "$state" == "SINGLE_QUOTE" ]]; then
            # Inside single quotes, all characters are treated as literal content. 
            # Only the closing quote matters to transition back to the NORMAL state.
            [[ "$c" == "'" ]] && state="NORMAL" || out+="$c"
            
        # === 4. DOUBLE QUOTE STATE: Handles "..." syntax ===
        elif [[ "$state" == "DOUBLE_QUOTE" ]]; then
            if [[ "$c" == '"' ]]; then 
                # When the closing double quote is encountered, exit to the NORMAL state.
                state="NORMAL";
            
            elif [[ "$c" == '\' ]] && [[ "${input:i+1:1}" == '"' ]]; then 
                # Handles escaped double quotes (e.g., "My\"Folder"), ensuring the quote is part of the path 
                # and allowing correct completion (e.g., cd My\"Folder/sub).
                out+='"'; (( i++ ));

            else 
                # Append all other characters literally. This correctly handles non-special escapes
                # like '\\' or '\a', as the backslash is preserved in the output as per Bash rules.
                out+="$c"; 
            fi
        fi
        (( i++ ))
    done
    printf '%s' "$out"
}

### Locale Detection
# Detects current shell environment's locale setting (LANG or LC_ALL). 
# Returns the locale code (e.g., "tr") if detected, otherwise "default". 
_fzf_cd_get_lang() {
    if [[ "${LANG:-}" == *"tr_"* || "${LC_ALL:-}" == *"tr_"* ]]; then
        echo "tr"
    else
        echo "default"
    fi
}

# Store the detected locale code
_FZF_CD_LANG="$(_fzf_cd_get_lang)"

# -- Prefix Filter with Locale Support --
# Filters candidate paths that match the typed prefix using a case-insensitive comparison.
#
# This function utilizes a custom AWK implementation to provide reliable, locale-aware 
# case-conversion. This manual approach is necessary because standard shell features 
# often fail to handle character pairs consistently across different UTF-8 environments.
_fzf_cd_filter_starts_with() {
    local search_term="$1"
    local lang="$2"

    if [[ -z "$search_term" ]]; then
        return 0
    fi

    awk -v TERM="$search_term" -v LANG="$lang" '
    function norm_tr(s,    out) {
        # Manually swap problematic Turkish chars to ensure accurate lowercase conversion
        gsub("İ","i",s)
        gsub("I","ı",s)
        gsub("Ş","ş",s)
        gsub("Ğ","ğ",s)
        gsub("Ü","ü",s)
        gsub("Ö","ö",s)
        gsub("Ç","ç",s)

        # After targeted conversion, use tolower for remaining ASCII letters.
        out = tolower(s)

        # Normalize dotless/dotted i variants to plain "i" for consistency
        gsub("ı","i",out)
        return out
    }
    function norm_default(s,    out) {
        # Handles case conversion for default.
        out = tolower(s)
        return out
    }
    function normalize(s, lang,    r) {
        # Chooses the correct normalization function based on the detected locale.
        if (lang == "tr") {
            return norm_tr(s)
        } else {
            return norm_default(s)
        }
    }
    BEGIN {
        # Normalize the search term only once before processing any input lines.
        term_norm = normalize(TERM, LANG)
    }
    {
        cand = $0
        cand_norm = normalize(cand, LANG)
        # Compare the candidates normalized prefix against the search terms normalized length.
        if (substr(cand_norm,1,length(term_norm)) == term_norm) {
            print cand
        }
    }'  
}

# ==============================================================================
# Main Widget Function
# ==============================================================================
fzf-cd-widget() {
    local line_prefix current_path_arg search_term target_dir="."
    local candidates starts_with starts_with_count selected_dir result new_path path_prefix safe_new_path

    # Check if the current Readline buffer content matches the 'cd [args] path' pattern.
    if ! [[ "$READLINE_LINE" =~ ^(cd[[:space:]]+(--[[:space:]]+)?)(.*)$ ]]; then
        return
    fi

    # BASH_REMATCH[1]: Stores the command prefix, including 'cd ' and optional '-- '.
    line_prefix="${BASH_REMATCH[1]}"
    # BASH_REMATCH[3]: Stores the raw path argument entered by the user.
    current_path_arg="${BASH_REMATCH[3]}"

    # Trim trailing/leading whitespace from argument
    current_path_arg="${current_path_arg#"${current_path_arg%%[![:space:]]*}"}"
    current_path_arg="${current_path_arg%"${current_path_arg##*[![:space:]]}"}"

    # Decode the path (resolve quotes/escapes)
    local unescaped="$(_fzf_cd_real_path "$current_path_arg")"
    
    # Handle Tilde expansion (~ -> $HOME) manually to preserve it in UI later
    local home_path="$HOME"
    local is_tilda_path=0
    if [[ "$unescaped" == "~" || "$unescaped" == "~/"* ]]; then
        is_tilda_path=1
        unescaped="${unescaped/#\~/$home_path}"
    fi

    # -- Auto-Complete Parent Directory --
    # Handles direct '..' usage by completing the path immediately without invoking fzf.
    # This ensures fast navigation to the parent directory.
    if [[ "$unescaped" =~ (^|/)\.\.$ ]]; then
        local appended_parent="${unescaped}/"
        
        # Tilde (~) path handling logic...
        if [[ "$is_tilda_path" -eq 1 ]]; then
            local rel="${appended_parent#$home_path/}"
            if [[ "$appended_parent" == "$home_path" || "$appended_parent" == "$home_path/" ]]; then
                safe_new_path="~/"
            else
                safe_new_path="~/$(printf '%q' "$rel")"
            fi
        else
            safe_new_path=$(printf '%q' "$appended_parent")
        fi

        # Prevents directory paths starting with '-' from being misinterpreted as command flags (e.g., 'cd -'). 
        # Inserts '-- ' into the prefix if necessary to force interpretation as a path argument.
        if [[ "$appended_parent" == -* && "$appended_parent" != --* ]]; then
            if [[ "$line_prefix" == "cd "* && "$line_prefix" != "cd -- "* ]]; then
                line_prefix="cd -- "
            fi
        fi

        READLINE_LINE="${line_prefix}${safe_new_path}"
        READLINE_POINT=${#READLINE_LINE}
        return
    fi

    # Remove trailing backslash or space to simplify processing
    if [[ "$current_path_arg" =~ (\\|\\[[:space:]])$ ]]; then
        # Strips trailing escape characters or spaces left at the end of the input.
        # This prevents the path parser from misinterpreting incomplete escape sequences.
        unescaped="${unescaped%\\}"
        unescaped="${unescaped%" "}"
    fi

    # -- Determine Search Context --
    # Determines the current search context by splitting the user's input into 
    # the 'target directory' (where to search) and the 'search term' (what to filter for).
    if [[ -n "$unescaped" ]]; then
        if [[ "$unescaped" == */ && "$unescaped" != "/" ]]; then
            # Case 1: Input ends with '/' (e.g., 'cd /usr/local/'). Target is the directory, search term is empty.
            target_dir="${unescaped%/}"
            search_term=""
        elif [[ "$unescaped" == */* ]]; then
            # Case 2: Input contains '/' but doesn't end with it (e.g., 'cd /usr/l'). Target is parent dir, search term is 'l'.
            target_dir="${unescaped%/*}"
            search_term="${unescaped##*/}"
            [[ -z "$target_dir" ]] && target_dir="/"
        else
            # Case 3: Input is just a prefix (e.g., 'cd loc'). Target is '.', search term is the input itself.
            target_dir="."
            search_term="$unescaped"
        fi
    else
        # Case 4: Input is empty. Target is '.', search term is empty.
        target_dir="."
        search_term=""
    fi

    # Track if target directory is inaccessible
    local is_inaccessible=0

    # Handle relative paths for 'find'
    local safe_target_dir="$target_dir"
    
    # -- Path Ambiguity Check --
    # Ensure relative paths are not misinterpreted as flags or options by 'find'.
    # If the target directory is relative (not starting with '/') and begins with '.' or '-', 
    # explicitly prefix it with './' to force interpretation as a path argument.
    if [[ "$target_dir" != /* && \
          ( "$target_dir" == -* || "$target_dir" == .* ) && \
          "$target_dir" != --* && \
          "$target_dir" != "." && \
          "$target_dir" != ".." && \
          "$target_dir" != ../* ]]; then
        safe_target_dir="./$target_dir"
    fi

    # -- Fetch Candidates --
    # Gathers the list of subdirectories (candidates) for fzf, based on the determined target directory.
    if [ -d "$safe_target_dir" ] && [ "$target_dir" != "." ]; then
        # Case 1: Target is an existing directory and is NOT the current directory ('.').
        if _fzf_cd_check_access "$safe_target_dir"; then
            # Check accessibility before fetching directories.
            candidates=$(_fzf_cd_get_dirs "$safe_target_dir")
        else
            # Mark directory as inaccessible if access check fails.
            candidates=""
            is_inaccessible=1
        fi
    else
        # Case 2: Target is the current directory ('.') OR the path is invalid/non-existent.
        if [ "$target_dir" == "." ]; then
            # Target is explicitly the current directory
             candidates=$(_fzf_cd_get_dirs ".")
        else
            # Target is non-existent or invalid; no candidates to list.
             candidates=""
        fi
    fi

    local candidate_count
    candidate_count=$(printf '%s\n' "$candidates" | grep -c .) 
    
    # -- Fast Path: Single Candidate --
    # If there is only one match and no search term, auto-accept it.
    if [[ "$candidate_count" -eq 1 && -z "$search_term" ]]; then
        result=$(printf '%s\n' "$candidates" | head -n1)
    fi

    # If a result has not yet been found and a search term exists, check for a single, definitive match.
    if [[ -z "$result" && -n "$search_term" ]]; then
        # Pre-filter candidates by the search term using locale-aware case-insensitive comparison.
        starts_with=$(
            printf '%s\n' "$candidates" | _fzf_cd_filter_starts_with "$search_term" "$_FZF_CD_LANG"
        )
        starts_with_count=$(printf '%s\n' "$starts_with" | grep -c .)

        # If the prefix match yields exactly one candidate, set it as the definitive result.
        if [[ "$starts_with_count" -eq 1 ]]; then
            result=$(printf '%s\n' "$starts_with" | sed -n '1p')
        fi
    fi

    # -- Interactive Mode (FZF Loop) --
    if [[ -z "$result" ]]; then
        local fzf_output key_pressed output_lines
        local current_query="$search_term" 

        # Prevent redundant disk scan on first iteration
        local refresh_needed=0 

        # Main interaction loop: Handles FZF execution and state changes (e.g., hidden toggle).
        while true; do
            # Refresh directory list if hidden toggle changed
            if [[ "$refresh_needed" -eq 1 ]]; then
                candidates=$(_fzf_cd_get_dirs "$safe_target_dir")
                refresh_needed=0
            fi

            local hidden_status
            
            # Set the status of hidden files in the fzf header.
            if [[ "$_FZF_CD_SHOW_HIDDEN" == "1" ]]; then
                hidden_status="ON "
            else
                hidden_status="OFF"
            fi

            local header_suffix=""

            # Append an 'Inaccessible' warning suffix to the fzf header if the target directory could not be accessed.
            [[ "$is_inaccessible" -eq 1 ]] && header_suffix="[Inaccessible] "

            # Construct the final FZF header.
            local fzf_header="[Hidden: ${hidden_status}] ${header_suffix}[Ctrl+T: Show/Hide Hidden | ${FZF_ACCEPT_KEY_NAME^^}: Accept]"
            
            # Save screen state (smcup) to avoid visual artifacts during terminal resizing/tiling when fzf is on.
            tput smcup > /dev/tty 2>/dev/null || true
            
            # -- Run FZF --
            # Uses --print-query to keep user input if they don't select anything
            # Uses --expect="ctrl-t" to handle the hidden file toggle
            # Uses --no-select-1 to prevent fzf from automatically selecting the item if only one candidate is left.
            fzf_output=$(
                fzf \
                    --border \
                    --no-select-1 \
                    --query="$current_query" \
                    --print-query \
                    --expect="ctrl-t" \
                    --header="$fzf_header" \
                    --bind "${FZF_ACCEPT_KEY_NAME}:accept" \
                    --bind "ctrl-z:abort" \
                    --prompt="cd> " \
                    <<< "$candidates"
            )
            local rc=$?
            
            # Restore screen state (rmcup)
            tput rmcup > /dev/tty 2>/dev/null || true

            # Parsing Mechanism: Safely reads the multi-line output generated by fzf.
            # The three output lines are assigned to three distinct variables: Query, Key Press, and Selected Result.
            {
                read -r current_query
                read -r key_pressed
                result=$(cat)
            } < <(printf '%s' "$fzf_output")

            # Handle hidden directory toggle action
            if [[ "$key_pressed" == "ctrl-t" ]]; then
                if [[ "$_FZF_CD_SHOW_HIDDEN" == "1" ]]; then
                    _FZF_CD_SHOW_HIDDEN=0
                else
                    _FZF_CD_SHOW_HIDDEN=1
                fi
                refresh_needed=1
                continue
            fi

            # Check the exit code (rc) of the fzf process.
            if [[ $rc -eq 0 ]]; then
                # If fzf exited successfully (user made a selection), break the loop to process the result.
                break 
            else
                # If fzf was cancelled (rc != 0), clear the result and break the loop.
                result=""
                break 
            fi
        done
    fi

    # -- Final Path Construction --
    # Only proceed if a definitive result (directory candidate) was selected from fzf or determined by optimization.
    if [[ -n "$result" ]]; then
        
        # Decode escape sequences (e.g., \n, \r, \\) generated by the stream encoder.
        # This reverses any encoding applied during candidate fetching.
        printf -v result '%b' "$result"
        selected_dir="${result%/}"

        # Determine the prefix (absolute or relative) for correct path construction.
        if [[ "$unescaped" == */* ]]; then
            # Path includes a directory separator (e.g., 'usr/l' -> prefix 'usr')
            path_prefix="${unescaped%/*}"
        else
            # Path is just a prefix in the current directory (e.g., 'loc' -> prefix '.')
            path_prefix="."
        fi

        # Combine the determined prefix with the selected directory name.
        if [ -z "$path_prefix" ] || [ "$path_prefix" = "." ]; then
            # Handles 'cd loc' -> 'cd local_dir/'
            new_path="${selected_dir}"
        elif [ "$path_prefix" = "/" ]; then
            # Handles 'cd /u' -> 'cd /usr/'
            new_path="/${selected_dir}"
        else
            path_prefix="${path_prefix%/}" # Ensure no trailing slash on prefix
            if [[ -n "$selected_dir" ]]; then
                # Handles 'cd /usr/l' -> 'cd /usr/local_dir/'
                new_path="${path_prefix}/${selected_dir}"
            else
                # Edge Case: If no selection was made but a path prefix exists, use the prefix as the new path.
                # This prevents the Readline buffer from being cleared unnecessarily.
                new_path="${path_prefix}"
            fi
        fi

        # Fix absolute path construction if argument started with / (e.g., 'cd /u' must be '/usr/')
        if [[ "$current_path_arg" == /* ]]; then
            if [[ "$unescaped" == */* ]]; then
                new_path="${path_prefix}/${selected_dir}"
            else
                new_path="/${selected_dir}"
            fi
        fi

        # Ensure trailing slash for completed directory paths (e.g., 'dir' -> 'dir/')
        if [[ "$new_path" != "/" && "${new_path: -1}" != "/" ]]; then
            new_path="${new_path}/"
        fi

        # Restore Tilde (~) notation if the original input path started with it.
        if [[ "$is_tilda_path" -eq 1 ]]; then
            local path_relative_to_home="${new_path#$home_path/}"

            if [[ "$new_path" == "$home_path" || "$new_path" == "$home_path/" ]]; then
                safe_new_path="~/"
            else
                # printf %q escapes the path safely for the shell (e.g., spaces to "\ ")
                safe_new_path="~/$(printf '%q' "$path_relative_to_home")"
            fi
        else
            # Apply final shell escaping to the new path before updating the buffer.
            safe_new_path=$(printf '%q' "$new_path")
        fi

        # Handle paths starting with '-' from being misinterpreted as command flags.
        # Inserts '-- ' into the prefix if necessary to force interpretation as a path argument.
        if [[ "$new_path" == -* && "$new_path" != --* ]]; then
            if [[ "$line_prefix" == "cd "* && "$line_prefix" != "cd -- "* ]]; then
                line_prefix="cd -- "
            fi
        fi

        # Update the Readline buffer (modify what is typed on the terminal)
        READLINE_LINE="${line_prefix}${safe_new_path}"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# ==============================================================================
# Key binding
# ==============================================================================

# If a start key sequence is provided, bind the widget.
# 'bind -x' is used to execute a shell command that modifies the readline buffer.
if [[ -n "$FZF_START_KEY_SEQ" ]]; then
    # Unbind any existing cd completion
    complete -r cd 2>/dev/null || true
    # Bind the fzf-cd-widget function to the specified key sequence
    eval "bind -x '$FZF_START_KEY_SEQ':fzf-cd-widget"
fi