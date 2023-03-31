#!/usr/bin/env bash

count() { echo $#; }

iam_verify() {
    local team="${1}"
    local cluster="${2:-nonprod}"

    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "${DEFAULT_VAULT_USER}"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec ${DEFAULT_VAULT_USER} -- aws sts get-caller-identity"
    local aws_user_account=$(aws-vault exec "${DEFAULT_VAULT_USER}" -- aws sts get-caller-identity)
    local aws_user_account_id=$(echo "${aws_user_account}" | jq -r .Account)
    local aws_user_account_arn=$(echo "${aws_user_account}" | jq -r .Arn)
    echo $aws_user_account | jq .

    aws configure set mfa_serial "arn:aws:iam::${aws_user_account_id}:mfa/${USERNAME}" --profile "${DEFAULT_VAULT_USER}"
    # sed -Ei "0,/(^mfa_serial.+${USERNAME})/s/(^mfa_serial.+${USERNAME})/#\1/" .aws/config
    echo "mfa_serial=${aws_user_account_arn}" >> ~/.aws/config_restore
    
    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "${team}-${cluster}"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec ${team}-${cluster} -- aws sts get-caller-identity"
    local aws_team_account=$(aws-vault exec "${team}-${cluster}" -- aws sts get-caller-identity)
    local aws_team_account_id=$(echo "${aws_team_account}" | jq -r .Account)
    local aws_team_account_arn=$(echo "${aws_team_account}" | jq -r .Arn)
    echo $aws_team_account | jq .
}

dpctl_stuff() {
    dpctl configure --team-name=${TEAM_NAME}
    dpctl workstation awsconfig ${TEAM_NAME} --user-name=${USERNAME}

    if [ -f ~/.aws/config_new ]; then
        mv ~/.aws/config_new ~/.aws/config
    fi
}

waiting() { printf "${1:-.}"; sleep 1; }

DEFAULT_VAULT_USER="${DEFAULT_VAULT_USER:-user}"

init_aws() {
    local last_err=0
    printf "\033[92;1m>>>\033[94;1m Initializing %s \033[92;1m>>>\033[0m\n" "AWS (and dpctl)"

    if [ ! -f /.initialized ]; then
        local current_vault_user="$(aws-vault list | grep user | awk '{ print $2 }')"
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

        cat > ~/.aws/config_restore <<EOF
[profile ${DEFAULT_VAULT_USER}]
region=${AWS_VAULT_USER_REGION}
EOF

        if [ ! -d "${HOME}/.dpctl" -o ! -f "${HOME}/.dpctl/config.yaml" ]; then
            dpctl_stuff
        fi

        # GNU sed -- Replace first match only
        # sed '0,/pattern/s/pattern/replacement/' filename
        # https://www.linuxtopia.org/online_books/linux_tool_guides/the_sed_faq/sedfaq4_004.html
        sed -Ei '0,/^credential_process.+user$/s/(^credential_process.+user$)/#\1/' .aws/config

        local aws_vault_version=0
        local aws_vault_major_version=0
        aws-vault --version 1>/tmp/.aws-vault-version 2>&1 && \
            aws_vault_version=$(aws-vault --version 2>&1 | sed 's/^v//g') && \
            aws_vault_major_version=$(echo "${aws_vault_version}" | awk -F'.' '{print $1}') && \
            rm -f /tmp/.aws-vault-version && \
            [ $aws_vault_major_version -ge 7 ] && \
                aws configure set credential_process "aws-vault exec --json --prompt=pass user" --profile user || \
                aws configure set credential_process "aws-vault exec --no-session --json --prompt=pass user" --profile user
        
        iam_verify "${TEAM_NAME}" "nonprod" \
            && date -u +%Y%m%dT%H%M%SZ > /.initialized \
            || last_err=$?
    fi

    [ $last_err -eq 0 -a -f /.initialized ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "AWS (and dpctl)"
}

if [ -d /tmp/addons ]; then
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
fi

[ -z "$(which dpctl)" ] || init_aws

export -f count
