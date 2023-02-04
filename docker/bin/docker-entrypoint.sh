#!/usr/bin/env bash

set -eo pipefail

echo "VISUAL=${EDITOR}" >> "${HOME}/.profile"
echo "GIT_EDITOR=${EDITOR}" >> "${HOME}/.profile"
echo "KUBE_EDITOR=${EDITOR}" >> "${HOME}/.profile"

git_config() {
git config --global user.name "${GIT_CONFIG_FULL_NAME}"
GIT_CONFIG_EMAIL_DEFAULT="$(echo ${GIT_CONFIG_FULL_NAME} | awk '{ print tolower($1"."$2"@grainger.com") }')"
git config --global user.email "${GIT_CONFIG_EMAIL:-$GIT_CONFIG_EMAIL_DEFAULT}"
git config --global user.username "${RACFID}"

git config --global core.pager "less -S"
git config --global core.editor "${EDITOR}"
git config --global color.diff auto
}

versions() {
aws --version
printf "k8s: " && kubectl version --short --client
printf "istioctl " && istioctl version --remote=false --short
terraform --version
terragrunt --version
}

init_ssh() {
file_list=0
file_list=($([ -d $HOME/.ssh ] && ls $HOME/.ssh 2>/dev/null))
if [ ${#file_list[@]} -eq 0 ]; then
    printf "\033[93m>\033[0m Generating ssh keypair with empty password ...\n\033[96;1m%s\033[0m\n" "ssh-keygen -t ed25519 -C '${RACFID}' -f '${HOME}/.ssh/id_ed25519'"
    ssh-keygen -t ed25519 -C "${RACFID}" -f "${HOME}/.ssh/id_ed25519" > "${HOME}/.ssh/$(date -u +%Y%m%dT%H%M%SZ)"
fi
}

init_gpg() {
file_list=0
file_list=($([ -d $HOME/.gnupg ] && ls $HOME/.gnupg/ 2>/dev/null))
if [ ${#file_list[@]} -lt 9 ]; then
    printf "\033[93m>\033[0m Generating gpg key with empty passphrase ...\n\033[96;1m%s\033[0m\n" "gpg --quick-gen-key ..."
    # /usr/bin/gpg --no-tty --with-colons --fingerprint -K
    gpg --quick-gen-key --yes --always-trust --batch --passphrase '' aws-vault

    ### *Fixes* gpg: WARNING: unsafe permissions on homedir '~/.gnupg'
    chown -R $USER $HOME/.gnupg
    chmod 700 $HOME/.gnupg
    #chmod 600 $HOME/.gnupg/*
fi
}

init_pass() {
# THIS IS WHERE pass IS INITIALIZED
file_list=0
file_list=($([ -d $HOME/.password-store ] && ls $HOME/.password-store/ 2>/dev/null))
if [ ${#file_list[@]} -lt 2 ]; then
    [ -f $HOME/.password-store/.gpg-id ] || pass init aws-vault
fi
}

ln -s /data ${HOME}/data

versions

printf "\033[92;1m>>>\033[94;1m Initializing Connections \033[92;1m<<<\033[0m\n"

git_config

init_ssh && init_gpg && init_pass

[ $# -gt 0 -a "${1}x" != "x" ] && /bin/bash -c "$@"

[ "${KEEP_ALIVE:-true}" = "true" ] && tail -f /dev/null
