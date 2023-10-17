#!/bin/bash -e

set -o pipefail

CURRENT_USER=$(whoami)
USER="${USER:-$CURRENT_USER}"

init_gpg() {
    local file_list=0
    file_list=($([ -d $HOME/.gnupg ] && ls $HOME/.gnupg/ 2>/dev/null))
    if [ ${#file_list[@]} -lt 9 ]; then
        printf "\033[93m>\033[0m Generating gpg key with empty passphrase ...\n\033[96;1m%s\033[0m\n" "gpg --quick-gen-key ..."
        # /usr/bin/gpg --no-tty --with-colons --fingerprint -K
        gpg --quick-gen-key --homedir "${HOME}/.gnupg" --yes --always-trust --batch --passphrase '' aws-vault

        ### *Fixes* gpg: WARNING: unsafe permissions on homedir '~/.gnupg'
        chown -R $USER $HOME/.gnupg
        chmod 700 $HOME/.gnupg
        #chmod 600 $HOME/.gnupg/*
    fi
}

init_pass() {
    # THIS IS WHERE pass IS INITIALIZED

    mkdir -p $HOME/.password-store
    chown -R $USER:$USER $HOME/.password-store
    chmod -R 700 $HOME/.password-store

    local file_list=0
    file_list=($([ -d $HOME/.password-store ] && ls $HOME/.password-store/ 2>/dev/null))
    if [ ${#file_list[@]} -lt 2 ]; then
        [ -f $HOME/.password-store/.gpg-id ] || pass init --path= aws-vault
    fi
}

check_crypto() {
    local last_err=0
    if [ ! -f $HOME/._crypto ]; then
        printf "\033[92;1m>>>\033[94;1m Checking %s \033[92;1m>>>\033[0m\n" "Crypto (gpg, pass)"

        init_gpg && init_pass \
            && date -u +%Y%m%dT%H%M%SZ > $HOME/._crypto \
            || last_err=$?
    fi

    [ $last_err -eq 0 -a -f $HOME/._crypto ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "Crypto (gpg, pass)"
}

check_crypto
