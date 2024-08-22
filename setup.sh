#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo ".env file loaded!"
else
    echo ".env file not found!"
fi

# This script sources all other scripts in the same directory
current_path=$(pwd)
echo "Sourcing scripts in $current_path\n"
current_file=$(basename "$0")

sh_files=($(dirname "$0")/functions/*.sh)
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