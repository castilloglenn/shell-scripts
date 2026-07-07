
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

which_aws_profile_in_claude_code() {
    local desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    local code_config="$HOME/.claude.json"

    local label config_file profile region
    for entry in "Claude desktop:$desktop_config" "Claude Code:$code_config"; do
        label="${entry%%:*}"
        config_file="${entry#*:}"

        if [ ! -f "$config_file" ]; then
            echo "❌ $label config not found at: $config_file"
            continue
        fi

        profile=$(jq -r '.mcpServers["aws-api"].env.AWS_PROFILE // empty' "$config_file")
        region=$(jq -r '.mcpServers["aws-api"].env.AWS_REGION // empty' "$config_file")

        if [ -n "$profile" ]; then
            echo "$label: AWS_PROFILE='$profile', AWS_REGION='${region:-<none>}'"
        else
            echo "$label: No AWS_PROFILE found."
        fi
    done
}

switch_aws_profile_in_claude_code() {
    local desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    local code_config="$HOME/.claude.json"

    # At least one config must exist to be worth continuing
    if [ ! -f "$desktop_config" ] && [ ! -f "$code_config" ]; then
        echo "❌ No Claude config found at:"
        echo "   $desktop_config"
        echo "   $code_config"
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

    # Update only AWS_PROFILE and AWS_REGION in each Claude config that exists
    echo "----------------------------------------"
    local label config_file tmp_file updated_any=0
    for entry in "Claude desktop:$desktop_config" "Claude Code:$code_config"; do
        label="${entry%%:*}"
        config_file="${entry#*:}"

        if [ ! -f "$config_file" ]; then
            echo "⚠️  $label config not found, skipping: $config_file"
            continue
        fi

        # Only update if this config actually defines the aws-api MCP server
        if [ "$(jq -r 'has("mcpServers") and (.mcpServers | has("aws-api"))' "$config_file")" != "true" ]; then
            echo "⚠️  $label config has no 'aws-api' MCP server, skipping."
            continue
        fi

        tmp_file=$(mktemp)
        if jq --arg profile "$profile" --arg region "$region" \
            '.mcpServers["aws-api"].env.AWS_PROFILE = $profile
             | .mcpServers["aws-api"].env.AWS_REGION = $region' \
            "$config_file" > "$tmp_file"; then
            mv "$tmp_file" "$config_file"
            echo "✅ Updated $label config: AWS_PROFILE='$profile', AWS_REGION='$region'."
            updated_any=1
        else
            rm -f "$tmp_file"
            echo "❌ Failed to update $label config: $config_file"
        fi
    done

    if [ "$updated_any" -eq 1 ]; then
        echo "----------------------------------------"
        echo "⚠️  Claude Code picks up the new profile on its next session."
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
    else
        echo "❌ No Claude config was updated."
        return 1
    fi
}
