cs_newbranch() {
    if [ -z "$1" ]; then
        echo "Usage: cs_newbranch <branch-name>"
        return 1
    fi
    git checkout -b castilloglenn/$1
}

cs_rebasemain() {
    git stash
    git checkout main
    git fetch origin --prune
    git rebase origin/main
    git stash pop
}

cs_change_git_account() {
    if [[ -z "$1" ]]; then
        echo "Usage: cs_change_git_account <personal|lrtechs|goat|hipe>"
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

    printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" "$name" "$token" | git credential-cache store
    echo -e "\e[1;32mSwitched to GitHub account: \e[1;34m${name}\e[0m"
}

cs_whichaccount() {
    git config --global user.name
    git config --global user.email
}

cs_clonewithexplicittoken() {
    if [[ $1 != https://github.com/* ]]; then
        echo "Error: Invalid URL. Please provide a valid GitHub URL starting with 'https://github.com/'."
        return 1
    fi
    url_with_token=$(echo "$1" | sed "s/https:\/\//https:\/\/${GITHUB_TOKEN}@/g")
    git clone "$url_with_token"
}

cs_pulldevelop() {
    git stash
    git checkout develop
    git fetch origin --prune
    git pull --rebase
    git stash pop
}

commit() {
    if [ $# -eq 0 ]; then
        echo "Usage: commit <commit-message>"
        return 1
    fi
    cd /Users/hipe/documents/personal/commit-history
    git add .
    git commit -m "$*"
    git reset HEAD~1
    cd -
}
