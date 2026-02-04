
snake_to_pascal() {
    local s
    if [ $# -eq 0 ]; then
        IFS= read -r s || return 0
    else
        s="$1"
    fi

    # normalize separators, trim edge underscores
    s="${s//-/_}"
    s="${s##_}"
    s="${s%%_}"
    [ -z "$s" ] && printf '' && return 0

    # replace underscores with spaces, capitalize words, join
    printf '%s' "$s" | tr '_' ' ' | awk '{
        for (i=1;i<=NF;i++) {
            printf "%s", toupper(substr($i,1,1)) tolower(substr($i,2))
        }
    }'
    printf '\n'
}
