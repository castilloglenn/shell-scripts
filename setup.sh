#!/bin/bash

# Get the directory of the current script
script_dir=$(dirname "$0")
printf "\n\033[1;34m[INFO]\033[0m Script directory: \033[1m%s\033[0m\n" "$script_dir"

# Load environment variables from .env file in the same directory
if [ -f "$script_dir/.env" ]; then
    export $(grep -v '^#' "$script_dir/.env" | xargs)
    printf "\033[1;32m[SUCCESS]\033[0m .env file loaded successfully!\n"
else
    printf "\033[1;31m[ERROR]\033[0m .env file not found. Please ensure it exists in the script directory.\n"
fi

# This script sources all other scripts in the same directory
sh_files=($script_dir/functions/*.sh)
total_files=${#sh_files[@]}
index=1

# Inform the user about sourcing functions
printf "\n\033[1;34m[INFO]\033[0m Sourcing %d script(s) from the 'functions' directory:\n\n" "$total_files"

for file in "${sh_files[@]}"; do
    if [ "$(basename "$file")" != "$current_file" ]; then
        printf "\033[1;34m[INFO]\033[0m Sourcing file %d of %d: \033[1m%s\033[0m\n" "$index" "$total_files" "$(basename "$file")"

        # Fetch function names from the file
        function_names=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\s*\)\s*\{' "$file" | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

        # Print function names as a comma-separated list
        if [ -n "$function_names" ]; then
            printf "\033[1;32m[INFO]\033[0m Functions in %s: \033[1m%s\033[0m\n\n" "$(basename "$file")" "$(echo "$function_names" | paste -sd ', ' -)"
        else
            printf "\033[1;33m[WARNING]\033[0m No functions found in %s.\n\n" "$(basename "$file")"
        fi

        source "$file"
        ((index++))
    fi
done

# Prompt user to switch to a specific GitHub account
printf "\033[1;34m[INFO]\033[0m Please select a GitHub account to switch to:\n"
printf "  \033[1;33m[a]\033[0m $GIT_USER_1_EMAIL\n"
printf "  \033[1;33m[b]\033[0m $GIT_USER_2_EMAIL\n\n"
printf "Enter your choice: "
read -r account

# Validate the input
if [[ "$account" != "a" && "$account" != "b" ]]; then
    printf "\033[1;31m[ERROR]\033[0m Invalid input. Please enter 'a' for Account 1 or 'b' for Account 2.\n"
    exit 1
fi

# Call the function to switch to the specified GitHub account
printf "\n\033[1;34m[INFO]\033[0m Switching to GitHub Account %s...\n" "$account"
cs_switchaccount "$account"
