usevenv() {
    if [ -z "$1" ] || [ "$1" = "." ]; then
        if [ ! -d "venv" ]; then
            echo "No 'venv' directory found. Creating virtual environment in 'venv'..."
            python -m venv venv || { echo "Failed to create virtual environment."; return 1; }
        fi
        VENV_PATH="venv"
    else
        VENV_PATH="$1"
        if [ ! -d "$VENV_PATH" ]; then
            echo "Error: Directory '$VENV_PATH' does not exist."
            return 1
        fi
    fi

    if [ ! -f "$VENV_PATH/bin/activate" ]; then
        echo "Error: No virtual environment found in '$VENV_PATH'."
        return 1
    fi

    # shellcheck disable=SC1090
    source "$VENV_PATH/bin/activate"
    echo "Activated virtual environment at '$VENV_PATH'"
}
