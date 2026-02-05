restart_shell() {
    source ~/.zshrc
}

mark() {
    local current_path=$(pwd)
    # Use user argument if provided, otherwise use current folder name
    local name=${1:-$(basename "$current_path")}
    local bookmark_file="$HOME/.zsh_bookmarks"

    # Check if this name is already saved in the file
    if grep -q "hash -d $name=" "$bookmark_file"; then
        echo "⚠️  Error: ~$name is already registered in your bookmarks."
        return 1
    fi

    # Append the hash command to the bookmarks file
    echo "hash -d $name=\"$current_path\"" >> "$bookmark_file"

    # Activate it immediately for the current session
    hash -d $name="$current_path"

    echo " ✅ Bookmark saved!"
    echo "    Source: $current_path"
    echo "    Usage:  cd ~$name"
}

edit_zshrc() {
    code -n "$HOME/.zshrc"
}

edit_post_commit() {
    code -n "$HOME/.git-hooks/post-commit"
}

edit_starship_config() {
    code -n "$HOME/.config/starship.toml"
}

edit_tmux_config() {
    code -n "$HOME/.tmux.conf"
}

edit_mark_entries() {
    code -n "$HOME/.zsh_bookmarks"
}

edit_crontab_reminders() {
    code -n "$HOME/reminder.sh" "$HOME/reminder.scpt"
}

edit_shell_scripts() {
    code "$HOME/documents/personal/shell-scripts"
}

edit_task_logger() {
    code "$HOME/documents/personal/task-logger"
}

edit_report_chat_summary() {
    code "$HOME/documents/personal/report-chat-summary"
}

edit_config_files() {
    code "$HOME/documents/personal/config-files"
}
