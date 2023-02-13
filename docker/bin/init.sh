#!/usr/bin/env bash

quick_iam_test() {
    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "user"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec user -- aws sts get-caller-identity"
    aws-vault exec user -- aws sts get-caller-identity
    
    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "${TEAM_NAME}-sandbox.tf"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec ${TEAM_NAME}-sandbox.tf -- aws sts get-caller-identity"
    aws-vault exec "${TEAM_NAME}-sandbox.tf" -- aws sts get-caller-identity
}

dpctl_stuff() {
    dpctl configure --team-name=${TEAM_NAME}
    dpctl workstation awsconfig ${TEAM_NAME} --user-name=${RACFID}

    if [ -f ~/.aws/config_new ]; then
        mv ~/.aws/config_new ~/.aws/config
    fi    
}

waiting() { printf "."; sleep 1; }

if [ ! -f /.initialized ]; then
    DEFAULT_VAULT_USER="${DEFAULT_VAULT_USER:-user}"
    current_vault_user="$(aws-vault list | grep user | awk '{ print $1 }')"
    if [ "${current_vault_user}" != "${DEFAULT_VAULT_USER}" ]; then
        [ ! -f "$HOME/.password-store/.gpg-id" -o ! -f "$HOME/.gnupg/trustdb.gpg" ] && printf "Still Initializing ..." && \
            while [ ! -f "$HOME/.password-store/.gpg-id" -o ! -f "$HOME/.gnupg/trustdb.gpg" ]; do waiting; done; echo
        if [ -n "${AWS_ACCESS_KEY_ID}" -a -n "${AWS_SECRET_ACCESS_KEY}" ]; then
            printf "\033[93m>\033[0m Found existing AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.\n"
            aws-vault add --env "${DEFAULT_VAULT_USER}"
        else
            aws-vault add "${DEFAULT_VAULT_USER}"
        fi
    fi

    if [ ! -d "${HOME}/.dpctl" -o ! -f "${HOME}/.dpctl/config.yaml" ]; then
        dpctl_stuff
        teamname=$(sed -e 's/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g' ~/.dpctl/config.yaml | grep teamname | sed s/\"\//g | awk -F'=' '{ print $2 }')
        [ "$teamname" = "${TEAM_NAME}" ] || dpctl_stuff

        sed -Ei 's/(^credential_process.+user$)/#\1/g' .aws/config
        aws configure set credential_process "aws-vault exec --no-session --json --prompt=pass user" --profile user
    fi

    quick_iam_test

    date -u +%Y%m%dT%H%M%SZ > /.initialized
fi
