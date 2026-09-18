
new_aws_profile() {
    local profile_name="$1"
    if [ -z "$profile_name" ]; then
        echo "Usage: new_aws_profile <profile_name>"
        return 1
    fi

    # Check if the profile already exists
    if aws configure get "profile.$profile_name.aws_access_key_id" > /dev/null 2>&1; then
        echo "⚠️  Error: AWS profile '$profile_name' already exists."
        return 1
    fi

    aws configure --profile "$profile_name"
    if [ $? -eq 0 ]; then
        echo "✅ AWS profile '$profile_name' created successfully!"
    else
        echo "❌ Failed to create AWS profile '$profile_name'."
    fi
}

list_aws_profiles() {
    echo "Available AWS profiles:"
    aws configure list-profiles
}

test_aws_profile() {
    local profiles
    profiles=($(aws configure list-profiles))

    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No AWS profiles found."
        return 1
    fi

    echo "Available AWS profiles:"
    local i=1
    for profile in "${profiles[@]}"; do
        echo "  $i) $profile"
        i=$((i + 1))
    done

    local choice
    printf "Select a profile to test (1-%d): " "${#profiles[@]}"
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#profiles[@]}" ]; then
        echo "❌ Invalid selection."
        return 1
    fi

    local profile="${profiles[$choice]}"

    echo "----------------------------------------"
    echo "Testing AWS profile: $profile"
    if aws s3 ls --profile "$profile" > /dev/null 2>&1; then
        echo "✅ AWS profile '$profile' is valid and has access."
    else
        echo "❌ AWS profile '$profile' is invalid or does not have access."
    fi
}

# Claude Code (CLI and the VS Code extension) no longer carries an aws-mcp
# server in ~/.claude.json. Its AWS access is configured per project under
# ~/Documents/mcp/*/.mcp.json, so only the Claude desktop app is read and
# written here.
which_aws_profile_in_claude_desktop() {
    local desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

    if [ ! -f "$desktop_config" ]; then
        echo "❌ Claude desktop config not found at: $desktop_config"
        return 1
    fi

    local profile region
    profile=$(jq -r '.mcpServers["aws-mcp"].env.AWS_PROFILE // empty' "$desktop_config")
    region=$(jq -r '.mcpServers["aws-mcp"].env.AWS_REGION // empty' "$desktop_config")

    if [ -n "$profile" ]; then
        echo "Claude desktop: AWS_PROFILE='$profile', AWS_REGION='${region:-<none>}'"
    else
        echo "Claude desktop: No AWS_PROFILE found."
    fi

    echo "Claude Code:    per-project, see ~/Documents/mcp/*/.mcp.json"
}

switch_aws_profile_in_claude_desktop() {
    local desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

    if [ ! -f "$desktop_config" ]; then
        echo "❌ Claude desktop config not found at: $desktop_config"
        return 1
    fi

    if [ "$(jq -r 'has("mcpServers") and (.mcpServers | has("aws-mcp"))' "$desktop_config")" != "true" ]; then
        echo "⚠️  Claude desktop config has no 'aws-mcp' MCP server, nothing to switch."
        return 1
    fi

    local profiles
    profiles=($(aws configure list-profiles))

    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No AWS profiles found."
        return 1
    fi

    echo "Available AWS profiles:"
    local i=1
    for profile in "${profiles[@]}"; do
        echo "  $i) $profile"
        i=$((i + 1))
    done

    local choice
    printf "Select a profile to switch to (1-%d): " "${#profiles[@]}"
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#profiles[@]}" ]; then
        echo "❌ Invalid selection."
        return 1
    fi

    local profile="${profiles[$choice]}"

    # Resolve the region for the selected profile from ~/.aws
    local region
    region=$(aws configure get region --profile "$profile")
    if [ -z "$region" ]; then
        echo "❌ No region configured for profile '$profile' in ~/.aws."
        return 1
    fi

    # Test the profile before committing the change
    echo "----------------------------------------"
    echo "Testing AWS profile: $profile (region: $region)"
    if ! aws s3 ls --profile "$profile" > /dev/null 2>&1; then
        echo "❌ AWS profile '$profile' is invalid or does not have access. Aborting."
        return 1
    fi
    echo "✅ AWS profile '$profile' is valid and has access."

    # Update only AWS_PROFILE and AWS_REGION, leaving the rest of the config alone
    echo "----------------------------------------"
    local tmp_file
    tmp_file=$(mktemp)
    if ! jq --arg profile "$profile" --arg region "$region" \
        '.mcpServers["aws-mcp"].env.AWS_PROFILE = $profile
         | .mcpServers["aws-mcp"].env.AWS_REGION = $region' \
        "$desktop_config" > "$tmp_file"; then
        rm -f "$tmp_file"
        echo "❌ Failed to update Claude desktop config: $desktop_config"
        return 1
    fi
    mv "$tmp_file" "$desktop_config"
    echo "✅ Updated Claude desktop config: AWS_PROFILE='$profile', AWS_REGION='$region'."

    echo "----------------------------------------"
    echo "⚠️  The Claude desktop app must be fully restarted for this to take effect."
    echo "⚠️  Restarting will quit the app — any running agent or in-progress task will be stopped."

    local restart
    printf "Restart the Claude app now to apply? (y/N): "
    read -r restart
    if [[ "$restart" =~ ^[Yy]$ ]]; then
        echo "Restarting Claude…"
        osascript -e 'quit app "Claude"' >/dev/null 2>&1
        # wait for it to fully exit before relaunching
        local n=0
        while pgrep -x "Claude" >/dev/null 2>&1 && [ "$n" -lt 20 ]; do
            sleep 0.5
            n=$((n + 1))
        done
        open -a "Claude" && echo "✅ Claude restarted."
    else
        echo "⚠️  Restart Claude manually for this to take effect."
    fi
}
