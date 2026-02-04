switch_git_account() {
    if [[ -z "$1" ]]; then
        echo "Usage: switch_git_account <personal|lrtechs|goat|hipe>"
        return 1
    fi

    local account="$1"
    local idx
    case "$account" in
        personal) idx=1 ;;
        lrtechs)  idx=2 ;;
        goat)     idx=3 ;;
        hipe)     idx=4 ;;
        *)
            echo "Unknown account. Please specify 'personal', 'lrtechs', 'goat', or 'hipe'."
            return 1
            ;;
    esac

    local name_var="GIT_USER_${idx}_NAME"
    local email_var="GIT_USER_${idx}_EMAIL"
    local token_var="GIT_USER_${idx}_TOKEN"

    # Resolve values without using bash-specific indirect expansion
    local name
    local email
    local token
    name=$(eval "printf '%s' \"\${$name_var}\"")
    email=$(eval "printf '%s' \"\${$email_var}\"")
    token=$(eval "printf '%s' \"\${$token_var}\"")

    if [[ -z "$name" || -z "$email" || -z "$token" ]]; then
        echo "Error: $name_var, $email_var, and $token_var must be set for account '$account'."
        return 1
    fi

    export GITHUB_TOKEN="$token"
    git config --global user.name "$name"
    git config --global user.email "$email"

    # Update ~/.netrc for github.com with selected account (uses $name and $token)
    NETRC="$HOME/.netrc"
    tmp="$(mktemp 2>/dev/null || mktemp /tmp/netrc.XXXXXX)"

    # Overwrite existing file: remove any existing github.com machine entry and write rest to temp
    if [ -f "$NETRC" ]; then
        # Remove any existing github.com machine entry (skip its block) and write rest to temp
        awk '
            BEGIN { skip=0 }
            /^machine[[:space:]]+github\.com([[:space:]]|$)/ { skip=1; next }
            /^machine[[:space:]]+/ { if (skip) skip=0 }
            { if (!skip) print }
        ' "$NETRC" > "$tmp"
    else
        : > "$tmp"
    fi

    # Append the new github.com entry
    printf "machine github.com\nlogin %s\npassword %s\n" "$name" "$token" >> "$tmp"

    # Move into place and secure permissions
    mv "$tmp" "$NETRC"
    chmod 600 "$NETRC"

    printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" "$name" "$token" | git credential-cache store
    echo -e " Switched to: \e[1;33m $name\e[0m"
}

which_account() {
    git config --global user.name
    git config --global user.email
}

clone_with_explicit_token() {
    if [[ $1 != https://github.com/* ]]; then
        echo "Error: Invalid URL. Please provide a valid GitHub URL starting with 'https://github.com/'."
        return 1
    fi
    url_with_token=$(echo "$1" | sed "s/https:\/\//https:\/\/${GITHUB_TOKEN}@/g")
    git clone "$url_with_token"
}

fetch_and_pull_rebase() {
    git add .
    git stash
    git fetch origin --prune
    git pull --rebase
    git stash pop
    echo "\nRebased successfully."
}
