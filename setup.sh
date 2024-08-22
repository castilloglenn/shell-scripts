#!/bin/bash

# Get the directory of the current script
script_dir=$(dirname "$0")
echo "Script directory: $script_dir"

# Load environment variables from .env file in the same directory
if [ -f "$script_dir/.env" ]; then
    export $(grep -v '^#' "$script_dir/.env" | xargs)
    echo ".env file loaded!"
else
    echo ".env file not found!"
fi

# This script sources all other scripts in the same directory
sh_files=($script_dir/functions/*.sh)
total_files=${#sh_files[@]}
index=1

for file in "${sh_files[@]}"; do
    if [ "$(basename "$file")" != "$current_file" ]; then
        echo "=== File $index of $total_files ==="
        echo "Sourcing $(basename "$file")"

        # Fetch function names from the file
        function_names=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\s*\)\s*\{' "$file" | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

        # Print function names as a comma-separated list
        if [ -n "$function_names" ]; then
            echo "Functions: $(echo $function_names | paste -sd ', ' -)\n"
        else
            echo "No functions in $(basename "$file").\n"
        fi

        source "$file"
        ((index++))
    fi
done

# Prompt user to switch to a specific GitHub account
echo "Switch to GitHub Account 1 or 2? (a/b)"
read -r account

# Validate the input
if [[ "$account" != "a" && "$account" != "b" ]]; then
    echo "Invalid input. Please enter 'a' for Account 1 or 'b' for Account 2."
    exit 1
fi

# Call the function to switch to the specified GitHub account
cs_switchaccount "$account"
