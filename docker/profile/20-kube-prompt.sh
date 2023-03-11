__kube_ps1() {
    if [ -f ~/.kube/config ]; then
        # Get current context
        local context=$(cat ~/.kube/config | grep "current-context:" | sed "s/current-context: //")

        if [ -n "$context" ]; then
            echo "$context"
        fi
    fi
}

__kube_ps1_wrap() {
    local result="$(__kube_ps1)"
    if [ -n "$result" ]; then
        echo "($(__kube_ps1))"
    fi
}
