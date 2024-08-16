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