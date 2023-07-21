#!/usr/bin/env bash

# AWS_DEFAULT_PROFILE="${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}"

aws_vault_version=$(aws-vault --version 2>&1 | sed 's/^v//g')
aws_vault_major_version=$(echo "${aws_vault_version}" | awk -F'.' '{print $1}')

count() { echo $#; }

_configure_aws_vault_7x_mfa() {
    aws configure set mfa_serial "arn:aws:iam::${1:-""}:mfa/${USERNAME}" --profile "${DEFAULT_PROFILE}"
}

_configure_aws_vault_6x_mfa() {
    aws configure set mfa_serial "arn:aws:iam::${1:-""}:mfa/${USERNAME}" --profile "${DEFAULT_PROFILE}"
}

_configure_aws_vault_7x_credproc() {
    aws configure set credential_process "aws-vault exec --no-session --json --prompt=pass $DEFAULT_PROFILE" --profile "$DEFAULT_PROFILE"
}

_configure_aws_vault_6x_credproc() {
    aws configure set credential_process "aws-vault exec --no-session --json --prompt=pass $DEFAULT_PROFILE" --profile "$DEFAULT_PROFILE"
}

iam_verify() {
    local team="${1:-$TEAM_NAME}"
    local cluster="${2:-nonprod}"

    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "${DEFAULT_PROFILE}"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec ${DEFAULT_PROFILE} -- aws sts get-caller-identity"
    local aws_user_account=$(aws-vault exec "${DEFAULT_PROFILE}" -- aws sts get-caller-identity)
    local aws_user_account_id=$(echo "${aws_user_account}" | jq -r .Account)
    local aws_user_account_arn=$(echo "${aws_user_account}" | jq -r .Arn)
    echo $aws_user_account | jq .

    [ $aws_vault_major_version -ge 7 ] && \
        _configure_aws_vault_7x_mfa "$aws_user_account_id" || \
        _configure_aws_vault_6x_mfa "$aws_user_account_id"

    echo "mfa_serial=${aws_user_account_arn}" >> ~/.aws/config_restore

    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "${team}-${cluster}"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec ${team}-${cluster} -- aws sts get-caller-identity"
    local aws_team_account=$(aws-vault exec "${team}-${cluster}" -- aws sts get-caller-identity)
    local aws_team_account_id=$(echo "${aws_team_account}" | jq -r .Account)
    local aws_team_account_arn=$(echo "${aws_team_account}" | jq -r .Arn)
    echo $aws_team_account | jq .
}

init_dpctl() {
    dpctl configure --team-name=${TEAM_NAME}
    dpctl workstation awsconfig ${TEAM_NAME} --user-name=${USERNAME}

    if [ -f ~/.aws/config_new ]; then
        mv ~/.aws/config_new ~/.aws/config >/dev/null 2>&1
    fi
}

_waiting() { printf "${1:-.}"; sleep 1; }

init_aws() {
    local last_err=0
    printf "\033[92;1m>>>\033[94;1m Initializing %s \033[92;1m>>>\033[0m\n" "AWS (and dpctl)"

    if [ ! -f /.initialized ]; then
        local current_vault_user="$(aws-vault list | grep user | awk '{ print $2 }')"
        if [ "${current_vault_user}" != "${DEFAULT_PROFILE}" ]; then
            [ ! -f "$HOME/.password-store/.gpg-id" -o ! -f "$HOME/.gnupg/trustdb.gpg" ] && printf "Still Initializing ..." && \
                while [ ! -f "$HOME/.password-store/.gpg-id" -o ! -f "$HOME/.gnupg/trustdb.gpg" ]; do _waiting; done; echo
            if [ -n "${AWS_ACCESS_KEY_ID}" -a -n "${AWS_SECRET_ACCESS_KEY}" ]; then
                printf "\033[93m>\033[0m Found existing AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.\n"
                aws-vault add --env "${DEFAULT_PROFILE}"
            else
                aws-vault add "${DEFAULT_PROFILE}"
            fi
        fi

        cat > ~/.aws/config_restore <<EOF
[profile ${DEFAULT_PROFILE}]
region=${AWS_VAULT_USER_REGION}
EOF

        if [ ! -d "${HOME}/.dpctl" -o ! -f "${HOME}/.dpctl/config.yaml" ]; then
            init_dpctl
        fi

        # Check for 'credential_process' line in user profile, originally added by dpctl
        grep -q -E -i "(^credential_process)\s*=\s*(.* -.+json $DEFAULT_PROFILE$)" ~/.aws/config >/dev/null && \
            {
                # GNU sed Example -- Replace first match only
                # sed '0,/pattern/s/pattern/replacement/' filename
                # https://www.linuxtopia.org/online_books/linux_tool_guides/the_sed_faq/sedfaq4_004.html
                sed -E -i "0,/^credential_process.+-.+json\s+$DEFAULT_PROFILE$/s/(^credential_process.+)\s+(-.+json $DEFAULT_PROFILE$)/#\1 \2/" .aws/config && \
                [ $aws_vault_major_version -ge 7 ] && \
                    _configure_aws_vault_7x_credproc || \
                    _configure_aws_vault_6x_credproc
            }

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
        for f in ${tarballs[@]}; do tar -xzvf "${f}" 2>/dev/null; done
        popd
        mv ${tarballs[@]} /tmp/addons/archive/ 2>/dev/null || true
    fi

    zips="$(find /tmp/addons -mindepth 1 -type f -name '*.zip' | grep -v /archive)"
    if [ $(count ${zips[@]}) -gt 0 ]; then
        [ -d /tmp/addons/archive ] || mkdir /tmp/addons/archive
        pushd /tmp/addons
        for f in ${zips[@]}; do unzip -o "${f}" 2>/dev/null; done
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

# [ -f $(which kube-ps1.sh) ] && . $(which kube-ps1.sh)
