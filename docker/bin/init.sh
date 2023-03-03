#!/usr/bin/env bash

count() { echo $#; }

quick_iam_test() {
    local team="${1:-di}"
    local cluster="${2:-nonprod}"

    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "user"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec user -- aws sts get-caller-identity"
    aws-vault exec user -- aws sts get-caller-identity
    
    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "${team}-${cluster}"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec ${team}-${cluster} -- aws sts get-caller-identity"
    aws-vault exec "${team}-${cluster}" -- aws sts get-caller-identity
}

dpctl_stuff() {
    dpctl configure --team-name=${TEAM_NAME}
    dpctl workstation awsconfig ${TEAM_NAME} --user-name=${RACFID}

    if [ -f ~/.aws/config_new ]; then
        mv ~/.aws/config_new ~/.aws/config
    fi    
}

waiting() { printf "${1:-.}"; sleep 1; }

init_aws() {
    local last_err=0
    printf "\033[92;1m>>>\033[94;1m Initializing %s \033[92;1m>>>\033[0m\n" "AWS (and dpctl)"

    if [ ! -f /.initialized ]; then
        DEFAULT_VAULT_USER="${DEFAULT_VAULT_USER:-user}"
        local current_vault_user="$(aws-vault list | grep user | awk '{ print $1 }')"
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
            local teamname=$(sed -e 's/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g' ~/.dpctl/config.yaml | grep teamname | sed s/\"\//g | awk -F'=' '{ print $2 }')
            [ "$teamname" = "${TEAM_NAME}" ] || dpctl_stuff

            sed -Ei 's/(^credential_process.+user$)/#\1/g' .aws/config
            aws configure set credential_process "aws-vault exec --no-session --json --prompt=pass user" --profile user
        fi

        quick_iam_test "${TEAM_NAME}" "nonprod" \
            && date -u +%Y%m%dT%H%M%SZ > /.initialized \
            || last_err=$?
    fi

    [ $last_err -eq 0 -a -f /.initialized ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "AWS (and dpctl)"
}

tarballs="$(find /tmp/addons -mindepth 1 -type f -name '*.tgz' | grep -v /archive)"
if [ $(count ${tarballs[@]}) -gt 0 ]; then
    [ -d /tmp/addons/archive ] || mkdir /tmp/addons/archive
    pushd /tmp/addons
    for f in ${tarballs[@]}; do tar -xzvf "${f}"; done
    popd
    mv ${tarballs[@]} /tmp/addons/archive/ 2>/dev/null || true
fi

zips="$(find /tmp/addons -mindepth 1 -type f -name '*.zip' | grep -v /archive)"
if [ $(count ${zips[@]}) -gt 0 ]; then
    [ -d /tmp/addons/archive ] || mkdir /tmp/addons/archive
    pushd /tmp/addons
    for f in ${zips[@]}; do unzip -o "${f}"; done
    popd
    mv ${zips[@]} /tmp/addons/archive/ 2>/dev/null || true
fi

files="$(find /tmp/addons -mindepth 1 -type f | grep -v -P '\.tgz|\.zip|/archive')"
if [ $(count ${files[@]}) -gt 0 ]; then
    for f in ${files[@]}; do
        fname="$(basename ${f})"
        target="/usr/local/bin/${fname}"
        if [ ! -f "${target}" ]; then
            printf "\033[93m>\033[0m Installing '%s' to '%s'\n" "${f}" "/usr/local/bin/${fname}"
            install "${f}" "${target}"
        fi
    done
    rm -f ${files[@]}
fi

[ -z "$(which dpctl)" ] || init_aws
