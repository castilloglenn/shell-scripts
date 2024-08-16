#!/bin/bash

# This script ensures that setup.sh is sourced in ~/.zshrc

current_path=$(pwd)
setup_script_path="$(dirname "$0")/setup.sh"
full_setup_script_path="$current_path/$setup_script_path"

# Check if the source line already exists in ~/.zshrc
if ! grep -Fxq "source \"$full_setup_script_path\"" ~/.zshrc; then
    echo "Adding source line to ~/.zshrc"
    echo "source \"$full_setup_script_path\"" >> ~/.zshrc
else
    echo "Source line already exists in ~/.zshrc"
fi

source ~/.zshrc
echo "Setup complete."