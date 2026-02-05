
pint_diffs_erp_system() {
    cd "$ERP_SYSTEM_PATH" || return
    ./PHP/Laravel/vendor/bin/pint $(git diff --name-only --diff-filter=ACM | grep '\.php$')
    cd - >/dev/null
}
