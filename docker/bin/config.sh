#!/usr/bin/env bash

DEFAULT_VAULT_USER="${DEFAULT_VAULT_USER:-user}"

aws_vault_version=$(aws-vault --version 2>&1 | sed 's/^v//g')
aws_vault_major_version=$(echo "${aws_vault_version}" | awk -F'.' '{print $1}')

count() { echo $#; }

_configure_aws_vault_7x_mfa() {
    aws configure set mfa_serial "arn:aws:iam::${1:-""}:mfa/${USERNAME}" --profile "${DEFAULT_VAULT_USER}"
    aws configure set mfa_process "pass otp my_aws_mfa"
}

_configure_aws_vault_6x_mfa() {
    aws configure set mfa_serial "arn:aws:iam::${1:-""}:mfa/${USERNAME}" --profile "${DEFAULT_VAULT_USER}"
}

# TODO: doesn't work with k9s
_adjust_for_reduced_mfa_prompt() {
    printf ""
    # sed -E -i "s/(^credential_process)\s*=\s*(.* -.+json $DEFAULT_VAULT_USER$)/#\1=\2/g" ~/.aws/config && \
    # sed -E -i "s/(^mfa_serial)\s*=\s*(.*\/$USERNAME$)/#\1=\2/" ~/.aws/config && \
    # sed -E -i "s/(^source_profile)\s*=\s*($DEFAULT_VAULT_USER$)/include_profile=\2/g" ~/.aws/config
    # aws configure set source_profile "$DEFAULT_VAULT_USER" --profile "$DEFAULT_VAULT_USER"
}

iam_verify() {
    local team="${1:-$TEAM_NAME}"
    local cluster="${2:-nonprod}"

    sleep 1
    printf "\033[93m>\033[0m Testing IAM with '%s' ...\n" "${DEFAULT_VAULT_USER}"
    printf "\033[96;1m%s\033[0m\n" "aws-vault exec ${DEFAULT_VAULT_USER} -- aws sts get-caller-identity"
    local aws_user_account=$(aws-vault exec "${DEFAULT_VAULT_USER}" -- aws sts get-caller-identity)
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

# TODO: Using >&2 on echo commands meant to log for human consumption keeps stderr available for programmatic consumption
_waiting() { printf "${1:-.}"; sleep 1; }

init_aws() {
    local last_err=0
    printf "\033[92;1m>>>\033[94;1m Initializing %s \033[92;1m>>>\033[0m\n" "AWS (and dpctl)"

    # TODO: running in background (command &) could cause stuck process if ctrl^c
    [ ! -f $HOME/._crypto ] && crypto.sh &>/dev/null &

    if [ ! -f $HOME/.initialized ]; then
        local current_vault_user="$(aws-vault list | grep user | awk '{ print $2 }')"
        if [ "${current_vault_user}" != "${DEFAULT_VAULT_USER}" ]; then
            [ ! -f "$HOME/.password-store/.gpg-id" -o ! -f "$HOME/.gnupg/trustdb.gpg" ] && printf "Still Initializing ..." && \
                while [ ! -f "$HOME/.password-store/.gpg-id" -o ! -f "$HOME/.gnupg/trustdb.gpg" ]; do _waiting; done; echo
            if [ -n "${AWS_ACCESS_KEY_ID}" -a -n "${AWS_SECRET_ACCESS_KEY}" ]; then
                printf "\033[93m>\033[0m Found existing AWS_ACCESS_KEY_ID (%s) and AWS_SECRET_ACCESS_KEY.\n" "${AWS_ACCESS_KEY_ID}"
                printf "Adding vault user (%s) with detected env...\n" "${AWS_ACCESS_KEY_ID}"
                aws-vault add --env "${DEFAULT_VAULT_USER}"
            else
                printf "Adding vault user (%s) ...\n" "${DEFAULT_VAULT_USER}"
                aws-vault add "${DEFAULT_VAULT_USER}"
            fi
        fi

        cat > ~/.aws/config_restore <<EOF
[profile ${DEFAULT_VAULT_USER}]
region=${AWS_VAULT_USER_REGION}
EOF

        if [ ! -d "${HOME}/.dpctl" -o ! -f "${HOME}/.dpctl/config.yaml" ]; then
            init_dpctl
        fi

        # Check for 'credential_process' line in user profile, originally added by dpctl
        grep -q -E -i "(^credential_process)\s*=\s*(.* -.+json $DEFAULT_VAULT_USER$)" ~/.aws/config >/dev/null && \
            {
                # GNU sed Example -- Replace first match only
                # sed '0,/pattern/s/pattern/replacement/' filename
                # https://www.linuxtopia.org/online_books/linux_tool_guides/the_sed_faq/sedfaq4_004.html
                sed -E -i "0,/^credential_process.+-.+json\s+$DEFAULT_VAULT_USER$/s/(^credential_process.+)\s+(-.+json $DEFAULT_VAULT_USER$)/#\1 \2/" ~/.aws/config && \
                _adjust_for_reduced_mfa_prompt && \
                [ $aws_vault_major_version -ge 7 ] && \
                    aws configure set credential_process "aws-vault exec --format=json $DEFAULT_VAULT_USER" --profile "$DEFAULT_VAULT_USER" || \
                    aws configure set credential_process "aws-vault exec --no-session --json --prompt=pass $DEFAULT_VAULT_USER" --profile "$DEFAULT_VAULT_USER"
            }

        iam_verify "${TEAM_NAME}" "nonprod" \
            && date -u +%Y%m%dT%H%M%SZ > $HOME/.initialized \
            || last_err=$?
    fi

    [ $last_err -eq 0 -a -f $HOME/.initialized ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "AWS (and dpctl)"
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
    addon_install=(sudo install)
    if [ $(count ${files[@]}) -gt 0 ]; then
        for f in ${files[@]}; do
            fname="$(basename ${f})"
            target="/opt/bin/${fname}"
            if [ ! -f "${target}" ]; then
                printf "\033[93m>\033[0m Installing '%s' to '%s'\n" "${f}" "/usr/local/bin/${fname}"
                addon_install_file=(${addon_install[@]})
                addon_install_file+=(
                    "${f}"
                    "${target}"
                )

                eval "$(echo ${addon_install_file[@]})"
            fi
        done
        rm -f ${files[@]}
    fi
fi

[ -z "$(which dpctl)" ] || init_aws

# [ -f $(which kube-ps1.sh) ] && . $(which kube-ps1.sh)
