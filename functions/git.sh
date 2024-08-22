cs_newbranch() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: nb <azure-boards-number> <branch-name>"
        return 1
    fi
    git checkout -b castilloglenn/$1/$2
}

cs_rebasemain() {
    git stash
    git checkout main
    git fetch origin --prune
    git rebase origin/main
    git stash pop
}

cs_pushtonewbranch() {
    if [ -z "$1" ]; then
        echo "Usage: pnb <branch-name>"
        return 1
    fi
    DATE=$(date +"%Y/%m/%d")
    git checkout -b castilloglenn/$DATE/$1
    git push --set-upstream origin castilloglenn/$DATE/$1
}

cs_switchaccount() {
    if [[ $1 == "a" ]]; then
        # Check if the required environment variables for Account 1 are set
        if [[ -z "${GIT_USER_1_NAME}" || -z "${GIT_USER_1_EMAIL}" || -z "${GIT_USER_1_TOKEN}" ]]; then
            echo "Error: GIT_USER_1_NAME, GIT_USER_1_EMAIL, and GIT_USER_1_TOKEN must be set for Account 1."
            return 1
        fi

        # Export the token for Account 1
        export GITHUB_TOKEN="${GIT_USER_1_TOKEN}"

        # Set global git configuration for Account 1
        git config --global user.name "${GIT_USER_1_NAME}"
        git config --global user.email "${GIT_USER_1_EMAIL}"

        # Set the token in the Git credentials cache for Account 1
        echo -e "protocol=https\nhost=github.com\nusername=${GIT_USER_1_NAME}\npassword=${GIT_USER_1_TOKEN}" | git credential-cache store
        echo -e "\e[1;32mSwitched to GitHub Account 1: \e[1;34m${GIT_USER_1_NAME}\e[0m"

    elif [[ $1 == "b" ]]; then
        # Check if the required environment variables for Account 2 are set
        if [[ -z "${GIT_USER_2_NAME}" || -z "${GIT_USER_2_EMAIL}" || -z "${GIT_USER_2_TOKEN}" ]]; then
            echo "Error: GIT_USER_2_NAME, GIT_USER_2_EMAIL, and GIT_USER_2_TOKEN must be set for Account 2."
            return 1
        fi

        # Export the token for Account 2
        export GITHUB_TOKEN="${GIT_USER_2_TOKEN}"

        # Set global git configuration for Account 2
        git config --global user.name "${GIT_USER_2_NAME}"
        git config --global user.email "${GIT_USER_2_EMAIL}"

        # Set the token in the Git credentials cache for Account 2
        echo -e "protocol=https\nhost=github.com\nusername=${GIT_USER_2_NAME}\npassword=${GIT_USER_2_TOKEN}" | git credential-cache store
        echo -e "\e[1;32mSwitched to GitHub Account 2: \e[1;34m${GIT_USER_2_NAME}\e[0m"

    else
        echo "Unknown account. Please specify 'a' or 'b'."
        return 1
    fi
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
