function ve() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-user}" -- "$@"
}

alias k='ve kubectl $@' #Included in .aliasas_platform
alias tf='ve terraform $@'