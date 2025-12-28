#!/bin/bash

# --- Test Environment Setup ---
# 1. Create the main test directory and navigate into it
# Run this inside the home/user (~) directory
# Use these commands to run,
# chmod +x env_setup.sh
# ./env_setup.sh
TEST_DIR=~/fzf-cd-test
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "Creating test directories in: $TEST_DIR (Total 68 scenarios covered)"

# Helper function to create main directories and a mandatory '_sub/' inside each
# Added '--' to mkdir to handle directory names starting with a dash (-).
create_dirs() {
    local dirs=("$@")
    for dir in "${dirs[@]}"; do
        # '--' ensures that directory names like '--double-dash-dir' are treated as paths, not flags.
        mkdir -p -- "$dir"
        mkdir -p -- "$dir/_sub"
    done
}

# --- A. Basic Navigation & "Fast Path" Optimization ---
# 02, 03, 08 (and 04)
create_dirs single_dir plain plain2 TestDir

# --- B. State Machine Parser: Quoting & Escaping ---
# 09, 10, 11, 12, 13, 16
create_dirs 'Has Space' "Double_Dir" 'Mixed "Quotes' 'My"Folder' 'Back\Slash'

# 14, 15 (ANSI-C Quoting)
mkdir -p $'Dir\nName'
mkdir -p $'Dir\nName'/_sub
mkdir -p $'Tab\tChar'
mkdir -p $'Tab\tChar'/_sub

# --- C. Locale-Aware Filtering (Turkish Support) ---
# 17, 18, 19
create_dirs İSTANBUL ışık ÇIĞLIK

# --- D. File Name Edge Cases (Stream Encoder) ---
# 22, 23, 29-33
create_dirs 'Multiple  Spaces' ' Leading Space' 'Backslash\Here' 'Trailing Backslash\' 'Double\\Backslash' 'Mixed\ Escaping' long_name_for_testing_the_limits_of_the_display_and_scrolling

# 24-27 (Control Characters)
mkdir -p $'01_NL_Newline\n' && mkdir -p $'01_NL_Newline\n'/_sub
mkdir -p $'02_CR_CarriageReturn\r' && mkdir -p $'02_CR_CarriageReturn\r'/_sub
mkdir -p $'03_CRNL_Windows\r\n' && mkdir -p $'03_CRNL_Windows\r\n'/_sub
mkdir -p $'04_NLCR_Unix\n\r' && mkdir -p $'04_NLCR_Unix\n\r'/_sub

# 28 (Tab char in name)
mkdir -p $'Tab\tChar'

# --- E. Absolute & Relative Path Handling ---
# 36, 39
create_dirs TEST
mkdir -p TEST/SubDir
mkdir -p TEST/SubDir/_sub
# 38 (Symlink Navigation)
ln -s TEST Symlink

# --- F. Hidden Files & Toggling ---
# 40, 42
create_dirs .hidden1 .hidden2 .folder_hidden

# --- G. Special Escaped Characters (In Directory Name) ---
# 44-50
create_dirs '$MoneyDir' '#CommentDir' "'Apostrophe'Dir" 'Dir&Ampersand' 'Dir!Bang' 'Dir?Question' 'Dir*Star'

# --- H. Tilde (~) Expansion & Preservation ---
# 51, 52
create_dirs TildeDocuments 'Tilde Spaced Dir'

# --- I. Flag Safety & Dash Prefixes ---
# 55, 57 (Requires -leading-dash)
mkdir -p -- -leading-dash
mkdir -p -- -leading-dash/_sub
# 58 (Requires --double-dash-dir) - BU ARTIK DÜZGÜN ÇALIŞACAK
create_dirs '--double-dash-dir'
# 56 (Requires TireTest/-partial-dir)
create_dirs TireTest
create_dirs TireTest/-partial-dir

# --- J. Permissions & Stability ---
# 59 (No Read Permission)
mkdir -p NoReadDir
mkdir -p NoReadDir/_sub
chmod 300 NoReadDir

# 60 (No Write Permission)
mkdir -p NoWriteDir
mkdir -p NoWriteDir/_sub
chmod 555 NoWriteDir

# --- K. Advanced & Stress Tests ---
# 63 (Path Editing/Reversion)
create_dirs sing/sub_folder sing/sub_other
# 64 (Massive Directory)
mkdir -p large_dir_performance
for i in {1..1000}; do mkdir -p large_dir_performance/dir_$i; done
# 65 (Deeply Nested)
mkdir -p a/b/c/d/e/deep_sub
create_dirs a/b/c/d/e
# 67, 68 (Unicode/Emoji)
create_dirs 📁_Folder 中文目录

echo "---"
echo "✅ All 68 test scenarios' directories and special structures have been successfully created under: $TEST_DIR"
echo "To begin testing, navigate to the directory and source your script:"
echo "cd ~/fzf-cd-test"
echo "source your_widget_script"