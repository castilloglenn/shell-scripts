
# Show the CURRENTLY selected AWS profile/region for Claude Desktop and this
# terminal, plus the active account/project for GCP, Firebase and Cloudflare.
# Claude Code no longer has a global aws-mcp server: its AWS access is per
# project under ~/Documents/mcp/*, so that row points there instead of a value.
# Renders a single colored, aligned table.
list_mcp_claude_accounts_and_projects() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 'jq' is required but not installed."
        return 1
    fi

    local dt_mcp="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    local mcp_root="$HOME/Documents/mcp"

    # ---- AWS profile for Claude Desktop (its aws-mcp MCP env) ---------------
    local dt_aws_profile dt_aws_region
    dt_aws_profile=$(jq -r '.mcpServers["aws-mcp"].env.AWS_PROFILE // "n/a"' "$dt_mcp" 2>/dev/null); [ -z "$dt_aws_profile" ] && dt_aws_profile="n/a"
    dt_aws_region=$(jq -r  '.mcpServers["aws-mcp"].env.AWS_REGION  // "n/a"' "$dt_mcp" 2>/dev/null); [ -z "$dt_aws_region" ] && dt_aws_region="n/a"

    # ---- Claude Code AWS: per project, not a single global value ------------
    # Count the project dirs so the row reflects what is actually configured.
    local cc_projects=0
    [ -d "$mcp_root" ] && cc_projects=$(find "$mcp_root" -maxdepth 2 -name .mcp.json 2>/dev/null | wc -l | tr -d ' ')

    # ---- Terminal AWS env (this shell's AWS_PROFILE / region) ---------------
    # Runs in the current shell, so it sees the live env vars. Unset profile
    # falls back to AWS's implicit "default"; region tries the common vars.
    local term_aws_profile term_aws_region
    term_aws_profile="${AWS_PROFILE:-default (unset)}"
    term_aws_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-not set}}"

    # ---- GCP / gcloud --------------------------------------------------------
    local gcp_acct gcp_proj
    if command -v gcloud >/dev/null 2>&1; then
        gcp_acct=$(gcloud config get-value account 2>/dev/null); [ -z "$gcp_acct" ] && gcp_acct="not logged in"
        gcp_proj=$(gcloud config get-value project 2>/dev/null); [ -z "$gcp_proj" ] && gcp_proj="n/a"
    else
        gcp_acct="not installed"; gcp_proj="n/a"
    fi

    # ---- Firebase ------------------------------------------------------------
    local fb_acct fb_proj
    if command -v firebase >/dev/null 2>&1; then
        fb_acct=$(firebase login:list 2>/dev/null | sed -n 's/^Logged in as //p' | head -1)
        [ -z "$fb_acct" ] && fb_acct="not logged in"
        # active project only exists inside a Firebase project dir (.firebaserc)
        fb_proj=$(firebase use 2>/dev/null | head -1)
        [ -z "$fb_proj" ] && fb_proj="n/a (per-directory)"
    else
        fb_acct="not installed"; fb_proj="n/a"
    fi

    # ---- Cloudflare (remote OAuth MCP) --------------------------------------
    # No local account name is stored, but the Cloudflare MCP server embeds the
    # active account in the 'execute' tool description. Ask it over JSON-RPC and
    # parse:  accountId is pre-set to "<id>" (<name>)
    local cf_acct cf_proj="n/a"
    local cf_token
    cf_token=$(jq -r '.access_token // empty' "$HOME/.mcp-auth"/*/*_tokens.json 2>/dev/null | head -1)
    if [ -z "$cf_token" ]; then
        cf_acct="not connected"
    elif ! command -v curl >/dev/null 2>&1; then
        cf_acct="OAuth session (curl missing)"
    else
        local cf_desc cf_line
        cf_desc=$(curl -s --max-time 12 -X POST "https://mcp.cloudflare.com/mcp" \
            -H "Authorization: Bearer $cf_token" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json, text/event-stream" \
            -H "MCP-Protocol-Version: 2024-11-05" \
            -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' 2>/dev/null \
            | sed 's/^data: //' | jq -r '.result.tools[]? | select(.name=="execute") | .description' 2>/dev/null)
        cf_line=$(printf '%s\n' "$cf_desc" | grep -o 'accountId is pre-set to "[^"]*" ([^—]*)' | head -1)
        if [ -n "$cf_line" ]; then
            cf_acct=$(printf '%s' "$cf_line" | sed -E 's/[^(]*\((.*)\) *$/\1/')
            cf_proj=$(printf '%s' "$cf_line" | sed -E 's/.*"([^"]*)".*/\1/')
        else
            cf_acct="OAuth session (token expired?)"
        fi
    fi

    # ---- Render --------------------------------------------------------------
    local rows=""
    rows+="Claude Code (AWS)"$'\t'"per-project ($cc_projects)"$'\t'"~/Documents/mcp/*"$'\n'
    rows+="Claude Desktop (AWS)"$'\t'"$dt_aws_profile"$'\t'"$dt_aws_region"$'\n'
    rows+="Terminal (AWS)"$'\t'"$term_aws_profile"$'\t'"$term_aws_region"$'\n'
    rows+="GCP / gcloud"$'\t'"$gcp_acct"$'\t'"$gcp_proj"$'\n'
    rows+="Firebase"$'\t'"$fb_acct"$'\t'"$fb_proj"$'\n'
    rows+="Cloudflare"$'\t'"$cf_acct"$'\t'"$cf_proj"$'\n'

    printf '%s' "$rows" | awk -F'\t' '
        # Placeholders are kept ASCII on purpose: this awk measures length() in
        # bytes, so a multibyte cell (an em dash is 3 bytes but 1 column) pads
        # its row short and breaks the alignment.
        function isbad(s) {
            return (s ~ /^(n\/a|not |uuid:)/ || s ~ /(not logged in|not connected|not installed|not configured)/);
        }
        {
            svc[NR]=$1; acc[NR]=$2; prj[NR]=$3;
            if (length($1) > ws) ws = length($1);
            if (length($2) > wa) wa = length($2);
            if (length($3) > wp) wp = length($3);
        }
        END {
            if (length("SERVICE")     > ws) ws = length("SERVICE");
            if (length("ACCOUNT")     > wa) wa = length("ACCOUNT");
            if (length("PROJECT / REGION") > wp) wp = length("PROJECT / REGION");

            total = ws + wa + wp + 6;   # 3 columns + two 3-space gaps

            # ---- title box, sized to the table width, title centered --------
            title = "MCP Servers Accounts & Projects";
            inner = total - 2;                       # width between the ║ borders
            bar = ""; for (i=0;i<inner;i++) bar = bar "═";
            tl = length(title); if (tl > inner) tl = inner;
            lp = int((inner - tl) / 2); rp = inner - tl - lp;
            lpad=""; for (i=0;i<lp;i++) lpad = lpad " ";
            rpad=""; for (i=0;i<rp;i++) rpad = rpad " ";
            printf "  \033[1;36m╔%s╗\033[0m\n", bar;
            printf "  \033[1;36m║%s%s%s║\033[0m\n", lpad, title, rpad;
            printf "  \033[1;36m╚%s╝\033[0m\n", bar;

            printf "  \033[1;37m%-*s   %-*s   %-*s\033[0m\n", ws, "SERVICE", wa, "ACCOUNT", wp, "PROJECT / REGION";
            sep=""; for (i=0;i<total;i++) sep=sep "─";
            printf "  \033[0;90m%s\033[0m\n", sep;

            for (i=1;i<=NR;i++) {
                # account color: red if it looks like "not set", else green
                if (isbad(acc[i])) ac = sprintf("\033[0;31m%-*s\033[0m", wa, acc[i]);
                else               ac = sprintf("\033[0;32m%-*s\033[0m", wa, acc[i]);
                # project color: dim if unset, else yellow
                if (isbad(prj[i])) pc = sprintf("\033[0;90m%-*s\033[0m", wp, prj[i]);
                else               pc = sprintf("\033[0;33m%-*s\033[0m", wp, prj[i]);
                printf "  \033[1;36m%-*s\033[0m   %s   %s\n", ws, svc[i], ac, pc;
            }
        }
    '

    # ---- Claude Code AWS hint ------------------------------------------------
    # Each project dir carries its own .mcp.json, and sync_bookmarks.py gives it
    # a ~mcp-<project> zsh bookmark. Note the zsh named-directory form has no
    # slash: it is ~mcp-jkn, not ~/mcp-jkn.
    printf "\n  \033[1;37mClaude Code AWS is per project\033[0m, configured under \033[0;33m%s/*/.mcp.json\033[0m\n" "$mcp_root"
    printf "  Jump to one and resume there:  \033[0;32mcd ~mcp-<project> && claude -c\033[0m\n"
    if [ "$cc_projects" -gt 0 ] && [ -d "$mcp_root" ]; then
        local names
        names=$(find "$mcp_root" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ' ')
        printf "  Available:  \033[0;90m%s\033[0m\n" "$names"
    fi
}
