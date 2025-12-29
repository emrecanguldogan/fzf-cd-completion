# 🚀 fzf-cd-completion

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-v4.0+-green.svg)](https://www.gnu.org/software/bash/)

A robust, context-aware directory navigation widget for **Bash**, powered by [**fzf**](https://github.com/junegunn/fzf).

It replaces fragile standard completion with a **smart, fuzzy-search interface**, handling complex paths, hidden directories, and edge cases with zero latency.

![Demo](/Images/demo.gif)

---

## ✨ Key Features

* **🛡️ Bulletproof Parsing:** Uses a custom State Machine parser to correctly handle mixed quotes (`' "`), escapes, and complex file names where standard completion fails.

* **🐚 Full Shell Expansion:** Seamlessly resolves **tildes** (`~/bin`), **environment variables** (`$HOME/.config`), and absolute paths before listing directories.

* **🚀 High Performance:** Optimized stream processing (`find -print0` | `sed`) ensures instant results even in directories with thousands of folders.

* **🌍 Locale & Edge-Case Aware:** Includes extensible custom logic for accurate case-insensitive normalization (e.g., Turkish i ↔ İ) and safely handles problematic folder names (newlines, tabs, leading dashes etc.).

* **⚡ Navigation Shortcuts:** Automatically expands `..` to `../` and handles single-result auto-acceptance for rapid navigation.

* **🚩 Flag Safety:** Automatically prepends the `--` argument delimiter before paths starting with a dash (`-leading-dash`) to prevent misinterpretation as command flags.

* **🖥️ Visual Stability:** Uses `tput smcup/rmcup` to ensure a clean restoration of the terminal after `fzf` exits

* **👻 Interactive Control:** Toggle hidden directories (.dotfolders) on/off inside the fzf window without restarting the search.
* **🎹 Smart Installation:** Comes with an interactive setup wizard that detects key binding conflicts automatically.

---

## ⚙️ Installation

### Prerequisites

* **Bash** (v4.0 or higher)
* **fzf** (Must be installed and in your `$PATH`)
* **GNU sed** (Standard on Linux. macOS users need `brew install gnu-sed`)

> Note: The widget has not been tested on macOS. However, if all prerequisites (including GNU sed) are satisfied, the code is expected to function correctly.

### 📦 Automatic Install (Recommended)

The project includes an interactive **Setup Wizard** that handles configuration, detects key conflicts (e.g., if `F1` is already taken), and updates your `.bashrc` safely.

**1. Clone the repository:**

```bash
git clone --depth 1 https://github.com/emrecanguldogan/fzf-cd-completion.git ~/.fzf-cd-completion
```

**2. Run the Setup Wizard:**
⚠️ **Important:** Use `source` to enable full conflict detection (bind -x).

```bash
cd ~/.fzf-cd-completion
source setup.sh
```

**3. Follow the wizard:**
Select your preferred key binding (Default: **F1**, 2: **Alt-K** 3: Custom Key).

![Demo](/Images/config.png)

---

## 🚀 Usage

Once installed, simply type `cd` and press your configured key.

| Action | Shortcut (Inside fzf) | Description |
| :--- | :--- | :--- |
| **Filter** | Typing... | Fuzzy search the directory list. |
| **Navigate** | `Up` / `Down` | Move selection. |
| **Select** | `Enter` | Insert selected path into command line. |
| **Toggle Hidden** | `Ctrl-T` | Show/Hide dotfiles (e.g., `.git/`). |
| **Cancel** | `ESC` `Ctrl-C` | Close widget without changing anything. |

> **Pro Tip:** The widget automatically handles the `--` delimiter for directories starting with a dash `-` and preserves `~` (tilde) expansion.

---

## 🛠 Management

### Change Key Binding (Re-configure)

Changed your mind about using **F1**? You don't need to reinstall. Just run the wizard again:

```bash
source ~/.fzf-cd-completion/setup.sh
```

### Uninstallation

1. Open `~/.bashrc` and remove the block marked with `# --- fzf_cd_completion start ---`.
2. Delete the directory: `rm -rf ~/.fzf-cd-completion`

---

## 🧪 Stability & Tests

The widget's development was rigorously driven by a comprehensive suite of 68 test scenarios, designed to cover every known edge case in Bash path completion logic.

This robustness is fully verifiable: Users are encouraged to run the provided env_setup.sh script to set up the necessary test environment and then execute the dedicated, documented test suite.

| Feature | fzf_cd_completion | fzf-tab-completion | zsh-interactive-cd |
| :--- | :--- | :--- | :--- |
| **Control Chars (`\n`, `\t`)** | ✅ **PASS** | ❌ FAIL | ⚠️ PARTIAL |
| **Complex Quoting** | ✅ **PASS** | ❌ FAIL | ⚠️ PARTIAL |
| **Unicode / Locale (İ/ı)** | ✅ **PASS** | ❌ FAIL | ❌ FAIL |
| **Hidden Toggle (`Ctrl+T`)** | ✅ **PASS** | ⚠️ PARTIAL | ❌ FAIL |
| **Flag Safety (`cd -dir`)** | ✅ **PASS** | ❌ FAIL | ✅ PASS |

(* Full test logs are available in the repository for verification)

## License

MIT
