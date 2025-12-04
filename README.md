# 🚀 fzf_cd_completion for bash

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A robust, context-aware directory navigation widget for **Bash (v4.0+)**, powered by **fzf** (a command-line fuzzy finder).

## 🌟 Why Choose This Widget?

Standard directory completion is notoriously fragile when handling non-standard characters, complex quoting, or non-English locales, often resulting in simple text output or broken input.

However, **fzf_cd_completion** provides a **modern, interactive, fuzzy-search interface** via FZF, change standard directory completion experience into a powerful, **visual command-line explorer**.

The widget is designed to be assigned to a custom key (like `F1` or `Alt-K`) to be used alongside the native completion mechanism. (Default is `F1`)

Note: It is not bounded to `TAB` by default to preserve standard Bash completions (e.g., `ls <TAB>`). If you bind the `TAB` key to the widget, you will lose the other bindings. See the [installation](#️-installation) and [custom key binding](#-custom-key-binding-selection-guide) section for detailed instructions.

This combination of superior user experience (UX) and the **low-level State Machine parsing** ensures that while you enjoy the beautiful interface, the underlying logic is resilient enough to guaranteeing correct path completion.

This widget was [tested](#-tests-details) against 68 distinct case scenarios and proven more resilient than leading alternatives like `fzf-tab-completion` and `zsh-interactive-cd`.

## ✨ Key Features

* **🚀 Uncompromising Performance:** Directory listing and filtering are heavily optimized by leveraging high-speed, stream-based utilities (find -print0, awk, sed -z). This architecture minimizes Bash process overhead and ensures lightning-fast execution, even when navigating inside thousands of directories

* **🛡️ State Machine Path Parser:** Implements a zero-dependency path parser that correctly interprets complex input states (Single Quote, Double Quote, ANSI-C) and handles mixed escaping like `cd Mixed\ "Quotes`.

* **💎 Stream Encoder (Edge-Case Safety):** Safely handles directories containing problematic control characters (Newlines `\n`, Carriage Returns `\r`, Tabs `\t`) by using Null-terminated streams (`find -print0` piped through `sed -z`). This prevents visual corruption in fzf and ensures accurate completion.

* **🌍 Extensible Locale-Aware Filtering:** Includes custom logic to accurately perform case-insensitive matching and normalization for locale-specific characters (e.g., i ↔ İ, ı ↔ I, ç ↔ Ç in Turkish). This feature is currently tuned for Turkish support but is built on an extensible foundation, allowing it to be easily expanded to support other languages where standard completion utilities typically fail.

* **👻 Interactive Hidden Directories:** Toggle hidden **directories** (`.dotfolders`) on/off **inside** the fzf window using `Ctrl+T`.

* **⚡ Navigation Shortcuts:** Automatically expands `..` to `../` and handles single-result auto-acceptance for rapid navigation.

* **🚩 Flag Safety:** Automatically prepends the `--` argument delimiter before paths starting with a dash (`-leading-dash`) to prevent misinterpretation as command flags.

* **🖥️ Visual Stability:** Uses `tput smcup/rmcup` to ensure a clean restoration of the terminal after `fzf` exits.

---

## 🚀 Usage

The `fzf-cd-widget` replaces the standard directory completion for the `cd` command.

### Triggering the Widget

| Action | Command | Result |
| :--- | :--- | :--- |
| **Activate** | Type `cd` followed by the assigned key. | Opens the interactive `fzf` directory selection window. |
| **Example** | `cd` + **`F1`** (or your custom key, e.g., `Alt-K`) | |

### Widget Functionality

Once the `fzf` window is open, the following keys control navigation and filtering:

* **Filtering:** Simply **type to fuzzy-filter** the directory list (case-insensitive).
* **Navigation:** Use **Up/Down** arrows to select entries.
* **Accept Selection:** Press **`Enter`** or custom key (Default is `F1`) to insert the selected path into the command line buffer and exit `fzf`.
* **Toggle Hidden Directories:** Press **`Ctrl-T`** to show or hide entries starting with a dot (`.`).
* **Cancel:** Press **`ESC`** to exit `fzf` without modifying the command line.

> 💡 **Tip:** The widget automatically handles complex paths (e.g., spaces, quotes) and preserves the tilde (`~`) symbol when applicable.

---

## ⚙️ Installation

### Prerequisites

* **Bash:** v4.0 or higher.
* **fzf:** The Fuzzy Finder must be installed. [For installation](https://github.com/junegunn/fzf#installation)
* **GNU sed:** Required for `-z` (null data) stream support. This utility is standard in Linux distributions. On macOS, where BSD sed is default, installation via `brew install gnu-sed` is necessary.

> Note: The widget has not been tested on macOS. However, if all prerequisites (including GNU sed) are satisfied, the code is expected to function correctly.

### Setup

1. Download the script (`fzf_cd_completion.sh`).
2. Source it in your `~/.bashrc` or similar configuration file:

```bash
# ~/.bashrc

# We recommend assigning to F1 or Ctrl+O to avoid conflicts with native TAB completion. 
# But you can bind any available key.

# Option 1: Bind to F1 (Recommended Default)
#export FZF_START_KEY_SEQ='"\eOP"'
#export FZF_ACCEPT_KEY_NAME="f1"

source /path/to/fzf_cd_completion.sh

# Option 2: Bind to Alt-k
export FZF_START_KEY_SEQ='"\ek"'
export FZF_ACCEPT_KEY_NAME="alt-k"

source /path/to/fzf_cd_completion.sh

# Option 3: Bind to Ctrl-O

# While this key is bound to 'operate-and-get-next' by default, 
# its utility is highly specialized and easily replaced by 
# sequential key presses (`Up/Down Arrows`).
# So this key combo also good to use for binding.

export FZF_START_KEY_SEQ='"\C-o"'
export FZF_ACCEPT_KEY_NAME="ctrl-o"

source /path/to/fzf_cd_completion.sh

```

---

## 🔑 Custom Key Binding Selection Guide

If you want to set a different key assignment than the recommended ones, this guide will help you determine the correct "Key Sequence" for your terminal and avoid conflicts with existing shortcuts.

### Step 1: Discover & Translate the Key Sequence

Terminals display raw codes (like `^[[A`) that must be translated into Bash Readline format (like `\e[A`) for the configuration.

**1. Find the Raw Code:**

* Open your terminal.
* Press **`Ctrl+V`**.
* Immediately press the key you want to use (e.g., F1, Alt+K).

### 2. Translate to Readline Format

Use the table below to convert the raw output into the correct format for `FZF_START_KEY_SEQ`.

| Key Type | Terminal Output (Raw) | **Conversion Rule** | **Final Config Value** |
| :--- | :--- | :--- | :--- |
| **Control Keys** | `^O` | Change `^` to `\C-` | **`\C-o`** |
| **Alt / Meta** | `^[k` | Change `^[` to `\e` | **`\ek`** |
| **Function (F1)**| `^[OP` | Change `^[` to `\e` | **`\eOP`** |
| **Function (F2)**| `^[[12~` | Change `^[` to `\e` | **`\e[12~`** |

**Rule of Thumb:**

* If you see **`^`** followed by a letter (e.g., `^O`), replace it with **`\C-`** (lower case)

* If you see **`^[`** (Escape), replace it with **`\e`**.

### Step 2: Verify Availability (`bind`)

Before using the key, ensure it is not already assigned to a critical function.

**A. Check System Defaults:**
Replace `[SEQ]` with your translated value (e.g., `\eOP`).

```bash
bind -p | grep '[SEQ]'
# If the output shows a special function name it is generally unsafe, 
# otherwise it is safe.
```

**B. Check Custom Widgets: Check if another plugin is using this key.**

```bash
bind -X | grep '[SEQ]'
# If the output shows a special function name it is generally unsafe, 
# otherwise it is safe.
```

### Step 3: Configure .bashrc

Add the verified sequence to your config. Always use single quotes (') to prevent shell expansion errors.

```bash
# Option 1: F1 Key (Raw: ^[OP -> Config: \eOP)
export FZF_START_KEY_SEQ='\eOP'
export FZF_ACCEPT_KEY_NAME="f1"

# Option 2: Alt-K (Raw: ^[k -> Config: \ek)
# export FZF_START_KEY_SEQ='\ek'
# export FZF_ACCEPT_KEY_NAME="alt-k"

# Option 3: Ctrl-O (Raw: ^O -> Config: \C-o)
# export FZF_START_KEY_SEQ='\C-o'
# export FZF_ACCEPT_KEY_NAME="ctrl-o"
```

---

## 🧪 Tests Details

The widget's development was rigorously driven by a comprehensive suite of **68 test scenarios**, designed to cover every known edge case in Bash path completion logic.

This robustness is **fully verifiable**: Users are encouraged to run the provided **`env_setup.sh`** script to set up the necessary test environment and then execute the dedicated, documented test suite.

---

### Competitive Analysis (Summary of Test Failures in Alternatives)

| Feature | fzf_cd_completion | fzf-tab-completion | zsh-interactive-cd |
| :--- | :--- | :--- | :--- |
| **Control Character Handling** | ✅ PASS | ❌ FAIL | ⚠️ PARTIAL|
| **Path Integrity (Quoting)** | ✅ PASS | ❌ FAIL  | ⚠️ PARTIAL |
| **Locale Support (Unicode)** | ✅ PASS | ❌ N/A | ❌ N/A |
| **Flag Safety (`cd -dir`)** | ✅ PASS | ❌ FAIL | ✅ PASS |
| **Hidden Dir Toggle (`Ctrl-T`)** | ✅ PASS | ❌ N/A | ❌ N/A |
| **Tilde (`~`) Preservation** | ✅ PASS | ⚠️ PARTIAL | ⚠️ PARTIAL |
| **Visual Stability** | ✅ PASS | ⚠️ PARTIAL | ✅ PASS |
| **Performance (Massive Dirs)** | ✅ PASS | ⚠️ PARTIAL | ✅ PASS |

* **Control Character Handling:** This refers to the ability to correctly process and display directory names that contain unprintable characters like **newline (`\n`)** or **carriage return (`\r`)** without causing visual corruption in the `fzf` window or breaking the path completion logic.

* **Path Integrity (Quoting):** This ensures the widget correctly escapes and quotes special characters (spaces, quotes, backslashes) in directory names when inserting them back into the shell buffer. The alternatives frequently fail to maintain the integrity of complex paths.

* **Flag Safety:** This guarantees that paths beginning with a dash (e.g., `-temp`) are safely handled by the `cd` command, usually by inserting the necessary `--` argument delimiter to prevent the path from being interpreted as a command flag.

* **Tilde Preservation:** This checks if the user's home directory symbol (`~`) is correctly preserved in the output (e.g., `~/Projects`) rather than being fully expanded to the absolute path (`/home/user/Projects`).
