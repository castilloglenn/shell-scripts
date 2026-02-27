
pint_diffs_erp_system() {
    pushd "$ERP_SYSTEM_PATH" >/dev/null || return

    local color_yellow="\033[33m"
    local color_green="\033[32m"
    local color_reset="\033[0m"

    php_diff_files=("${(@f)$(git diff --name-only --diff-filter=ACM -- '*.php')}")
    php_diff_files=("${(@)php_diff_files:#}")

    if (( ${#php_diff_files[@]} == 0 )); then
        echo -e "${color_yellow} No PHP diffs${color_reset}"
        popd >/dev/null
        return
    fi

    echo "${color_yellow} PHP diffs found:${color_reset}"
    printf '%s\n' "${php_diff_files[@]}"

    ./PHP/Laravel/vendor/bin/pint "${php_diff_files[@]}"

    popd >/dev/null
}

pint_diffs_bill_mg() {
    pushd "$BILL_MG_PATH" >/dev/null || return

    local color_yellow="\033[33m"
    local color_green="\033[32m"
    local color_reset="\033[0m"

    php_diff_files=("${(@f)$(git diff --name-only --diff-filter=ACM -- '*.php')}")
    php_diff_files=("${(@)php_diff_files:#}")

    if (( ${#php_diff_files[@]} == 0 )); then
        echo -e "${color_yellow} No PHP diffs${color_reset}"
        popd >/dev/null
        return
    fi

    echo "${color_yellow} PHP diffs found:${color_reset}"
    printf '%s\n' "${php_diff_files[@]}"

    ./PHP/Laravel/vendor/bin/pint "${php_diff_files[@]}"

    popd >/dev/null
}
