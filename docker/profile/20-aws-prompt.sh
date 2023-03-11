# Function to let me know if I have any overriding AWS Env variables Set
__aws_ps1() {
    if [ -n "$AWS_DEFAULT_PROFILE" ]; then
        AWS_PROMPT="${AWS_DEFAULT_PROFILE}"
        if [ -n "$AWS_REGION" ]; then
            AWS_PROMPT+=": AWS_REGION: $AWS_REGION "
        fi
        if [ -n "$AWS_ACCESS_KEY_ID" ]; then
            AWS_PROMPT+=": AWS_ACCESS_KEY_ID is set"
        fi
        echo "$AWS_PROMPT"
    fi
}

__aws_ps1_wrap() {
    local result="$(__aws_ps1)"
    if [ -n "$result" ]; then
        echo "[$(__aws_ps1)]"
    fi
}
