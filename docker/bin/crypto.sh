#!/bin/bash -e

set -o pipefail

CURRENT_USER=$(whoami)
USER="${USER:-$CURRENT_USER}"

init_gpg() {
    local file_list=0
    file_list=($([ -d ~/.gnupg ] && ls ~/.gnupg/ 2>/dev/null))
    if [ ${#file_list[@]} -lt 9 ]; then
        printf "\033[93m>\033[0m Generating gpg key with empty passphrase ...\n\033[96;1m%s\033[0m\n" "gpg --quick-gen-key ..."
        # /usr/bin/gpg --no-tty --with-colons --fingerprint -K
        gpg --quick-gen-key --homedir ~/.gnupg --yes --always-trust --batch --passphrase '' aws-vault

        ### *Fixes* gpg: WARNING: unsafe permissions on homedir '~/.gnupg'
        chown -R $USER ~/.gnupg
        chmod 700 ~/.gnupg
        #chmod 600 ~/.gnupg/*
    fi
}

init_pass() {
    # THIS IS WHERE pass IS INITIALIZED

    mkdir -p ~/.password-store
    chown -R $USER:$USER ~/.password-store
    chmod -R 700 ~/.password-store

    local file_list=0
    file_list=($([ -d $HOME/.password-store ] && ls ~/.password-store/ 2>/dev/null))
    if [ ${#file_list[@]} -lt 2 ]; then
        [ -f ~/.password-store/.gpg-id ] || pass init --path= aws-vault
    fi
}

check_crypto() {
    local last_err=0
    if [ ! -f ~/._crypto ]; then
        printf "\033[92;1m>>>\033[94;1m Checking %s \033[92;1m>>>\033[0m\n" "Crypto (gpg, pass)"

        init_gpg && init_pass \
            && date -u +%Y%m%dT%H%M%SZ > ~/._crypto \
            || last_err=$?
    fi

    [ $last_err -eq 0 -a -f ~/._crypto ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "Crypto (gpg, pass)"
}

check_crypto
