_fn_exists() {
    return_code=$?
    command -v "$1" >/dev/null 2>&1 || return_code=$?
    return $return_code
}

_cloud_ps1_color_fg() {
    _CLOUD_PS1_OPEN_ESC=$'\001'
    _CLOUD_PS1_CLOSE_ESC=$'\002'
    _CLOUD_PS1_FG_CODE="${1:-$C_NC}"

    echo ${_CLOUD_PS1_OPEN_ESC}${_CLOUD_PS1_FG_CODE}${_CLOUD_PS1_CLOSE_ESC}
}

# Function to let me know if I have any overriding AWS Env variables Set
_aws_ps1() {
    local AWS_PROMPT
    AWS_PROMPT+="${AWS_DEFAULT_PROFILE:-read-only}"
    if [ -n "$AWS_REGION" ]; then
        AWS_PROMPT+=": AWS_REGION: $AWS_REGION "
    fi
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        AWS_PROMPT+=": AWS_ACCESS_KEY_ID is set"
    fi
    AWS_PROMPT="$(_cloud_ps1_color_fg $C_BOLD)aws$(_cloud_ps1_color_fg)|$(_cloud_ps1_color_fg $C_YELLOW)${AWS_PROMPT}$(_cloud_ps1_color_fg)"
    echo "${AWS_PROMPT}"
}

_kube_ps1() {
    if [ $(command -v kube_ps1) ]; then
        kube_ps1
    elif [ -f "${HOME}/.kube/config" ]; then
        # Get current context
        local KUBE_PROMPT
        KUBE_PROMPT+="$(cat '${HOME}/.kube/config}' | grep 'current-context:' | sed 's/current-context: //')"
        export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
        echo "${KUBE_PROMPT}"
    fi
}

_awsconfig_exists() {
    local return_code=$?
    [ -n "${AWSCONFIG}" -o -f "${HOME}/.aws/config" ] || return_code=$?
    return $return_code
}

_kubeconfig_exists() {
    local return_code=$?
    [ -n "${KUBECONFIG}" -o -f "${HOME}/.kube/config" ] || return_code=$?
    return $return_code
}

parse_git_branch() {
    local result=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/')
    [ -n "$result" ] && echo "${result}"
}

cloud_prompt() {
    local return_code=$?
    local kubeconfig="${KUBECONFIG:-${HOME}/.kube/config}"
    local awsconfig="${AWSCONFIG:-${HOME}/.aws/config}"
    local CLOUD_PROMPT_RESET_COLOR="$(_cloud_ps1_color_fg)"
    local CLOUD_PROMPT

    if _awsconfig_exists && _kubeconfig_exists ; then
        _fn_exists _aws_ps1 && _fn_exists _kube_ps1 && CLOUD_PROMPT+="($(_aws_ps1)):$(_kube_ps1)"
        echo -e "[${CLOUD_PROMPT}]:"
        return $?
    fi
    if _awsconfig_exists ; then
        _fn_exists _aws_ps1 && CLOUD_PROMPT+="($(_aws_ps1))"
        echo -e "[${CLOUD_PROMPT}]:"
        return $?
    fi
    if _kubeconfig_exists ; then
        _fn_exists _kube_ps1 && CLOUD_PROMPT+="$(_kube_ps1)"
        echo -e "[${CLOUD_PROMPT}]:"
        return $?
    fi
}

_PS1_DEFAULT=
[ -z "$_PS1_DEFAULT" ] && _PS1_DEFAULT=$PS1
PS1="$(echo $_PS1_DEFAULT | sed 's/\\$$//')"${C_GREEN}'$(parse_git_branch)'${C_NC}'\$ '
PS1='$(cloud_prompt)'$PS1
