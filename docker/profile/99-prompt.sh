parse_git_branch() {
    local result=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/')
    if [ -n "$result" ]; then
        echo "${result}"
    fi
}

cloud_prompt() {
    local aws_result="$(__aws_ps1)"
    local kube_result="$(__kube_ps1)"
    if [ -n "$aws_result" -a -n "$kube_result" ]; then
        echo "${kube_result} | ${aws_result}"
    fi
}

PS1="${PS1}${C_LIGHTYELLOW_BOLD}[\$(cloud_prompt)]${C_GREEN}\$(parse_git_branch)${C_NC} \$ "
