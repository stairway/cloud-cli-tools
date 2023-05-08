# Function to let me know if I have any overriding AWS Env variables Set
__aws_ps1() {
    local aws_prompt="${AWS_DEFAULT_PROFILE:-read-only}"
    if [ -n "$AWS_REGION" ]; then
        aws_prompt+=": AWS_REGION: $AWS_REGION "
    fi
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        aws_prompt+=": AWS_ACCESS_KEY_ID is set"
    fi
    echo "$aws_prompt"
}

__aws_ps1_wrap() {
    local result="$(__aws_ps1)"
    if [ -n "$result" ]; then
        echo "[$(__aws_ps1)]"
    fi
}
