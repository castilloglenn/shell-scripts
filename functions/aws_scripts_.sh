
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
    local config_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

    if [ ! -f "$config_file" ]; then
        echo "❌ Claude config not found at: $config_file"
        return 1
    fi

    local profile
    profile=$(jq -r '.mcpServers["aws-api"].env.AWS_PROFILE // empty' "$config_file")

    if [ -n "$profile" ]; then
        echo "Current AWS_PROFILE in Claude config: $profile"
    else
        echo "No AWS_PROFILE found in Claude config."
    fi
}

switch_aws_profile_in_claude_code() {
    local config_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

    if [ ! -f "$config_file" ]; then
        echo "❌ Claude config not found at: $config_file"
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

    # Update only AWS_PROFILE and AWS_REGION in the Claude config
    local tmp_file
    tmp_file=$(mktemp)
    if jq --arg profile "$profile" --arg region "$region" \
        '.mcpServers["aws-api"].env.AWS_PROFILE = $profile
         | .mcpServers["aws-api"].env.AWS_REGION = $region' \
        "$config_file" > "$tmp_file"; then
        mv "$tmp_file" "$config_file"
        echo "----------------------------------------"
        echo "✅ Updated Claude config: AWS_PROFILE='$profile', AWS_REGION='$region'."
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
        rm -f "$tmp_file"
        echo "❌ Failed to update Claude config."
        return 1
    fi
}
