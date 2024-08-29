#!/bin/bash

# Get the directory of the current script
script_dir=$(dirname "$0")

# Load environment variables from .env file in the same directory
if [ -f "$script_dir/.env" ]; then
    export $(grep -v '^#' "$script_dir/.env" | xargs)
else
    printf "\033[1;31m[ERROR]\033[0m .env file not found. Please ensure it exists in the script directory.\n"
fi

# This script sources all other scripts in the same directory
sh_files=($script_dir/functions/*.sh)
total_files=${#sh_files[@]}
index=1

for file in "${sh_files[@]}"; do
    if [ "$(basename "$file")" != "$current_file" ]; then
        source "$file"
        ((index++))
    fi
done

cs_switchaccount "a"
printf "\033[1;32m[SUCCESS]\033[0m Shell Scripts setup complete. \033[1;90m(Location: $script_dir)\033[0m\n"
