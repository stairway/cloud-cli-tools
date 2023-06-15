#!/usr/bin/env bash

set -eo pipefail

USERNAME="${USERNAME:-""}"
GIT_CONFIG_FULL_NAME="${GIT_CONFIG_FULL_NAME:-""}"
GIT_CONFIG_EMAIL="${GIT_CONFIG_EMAIL:-""}"
EDITOR="${EDITOR:-""}"
GIT_DEFAULT_BRANCH="${GIT_DEFAULT_BRANCH:-main}"
INPUT_SHELL=""

git_config() {
    git config --global user.name "${GIT_CONFIG_FULL_NAME}"
    GIT_CONFIG_EMAIL_DEFAULT="$(echo ${GIT_CONFIG_FULL_NAME} | awk -v domain_var="$CONSUMER_DOMAIN" '{ print tolower($1"."$2"@"domain_var) }')"
    git config --global user.email "${GIT_CONFIG_EMAIL:-$GIT_CONFIG_EMAIL_DEFAULT}"
    git config --global user.username "${USERNAME}"

    git config --global core.pager "less -S"
    git config --global core.editor "${EDITOR}"
    git config --global color.diff auto

    git config --global init.defaultBranch "$GIT_DEFAULT_BRANCH"
    git config --global pull.rebase true
}

init_ssh() {
    local file_list=0
    file_list=($([ -d $HOME/.ssh ] && ls $HOME/.ssh 2>/dev/null))
    local gen_date=$(date -u +%Y%m%dT%H%M%SZ)
    local key_count=0
    key_count=$(ls -1 $HOME/.ssh | grep --color=never -o id_ed25519.fingerprint | wc -l)
    if [ ${key_count} -lt 1 ]; then
        printf "\033[93m>\033[0m Generating ssh ed25519 keypair with empty password ...\n\033[96;1m%s\033[0m\n" "ssh-keygen -t ed25519 -C '${USERNAME}' -f '${HOME}/.ssh/id_ed25519' -N ''"
        ssh-keygen -t ed25519 -C "${USERNAME}" -f "${HOME}/.ssh/id_ed25519" -N "" > "${HOME}/.ssh/${gen_date}.id_ed25519.fingerprint" \
            && cat "${HOME}/.ssh/id_ed25519.pub"
    fi
    key_count=0
    key_count=$(ls -1 $HOME/.ssh | grep --color=never -o id_rsa.fingerprint | wc -l)
    if [ ${key_count} -lt 1 ]; then
        printf "\033[93m>\033[0m Generating ssh rsa keypair with empty password ...\n\033[96;1m%s\033[0m\n" "ssh-keygen -t rsa -b 4096 -C '${USERNAME}' -f '${HOME}/.ssh/id_rsa' -N ''"
        ssh-keygen -t rsa -b 4096 -C "${USERNAME}" -f "${HOME}/.ssh/id_rsa" -N "" > "${HOME}/.ssh/${gen_date}.id_rsa.fingerprint" \
            && cat "${HOME}/.ssh/id_rsa.pub"
    fi
}

init_gpg() {
    local file_list=0
    file_list=($([ -d $HOME/.gnupg ] && ls $HOME/.gnupg/ 2>/dev/null))
    if [ ${#file_list[@]} -lt 9 ]; then
        printf "\033[93m>\033[0m Generating gpg key with empty passphrase ...\n\033[96;1m%s\033[0m\n" "gpg --quick-gen-key ..."
        # /usr/bin/gpg --no-tty --with-colons --fingerprint -K
        gpg_command=("")
        [ "${USER}" = "root" ] && gpg_command+=(sudo)
        gpg_command+=(
            gpg
            --quick-gen-key
            --lock-never
            --yes
            --always-trust
            --batch
            --passphrase ''
            aws-vault
        )

        eval "$(echo ${gpg_command[@]})"

        ### *Fixes* gpg: WARNING: unsafe permissions on homedir '~/.gnupg'
        # chown -R $USER $HOME/.gnupg
        # chmod 700 $HOME/.gnupg
        #chmod 600 $HOME/.gnupg/*
    fi
}

init_pass() {
    # THIS IS WHERE pass IS INITIALIZED
    local file_list=0
    file_list=($([ -d $HOME/.password-store ] && ls $HOME/.password-store/ 2>/dev/null))
    if [ ${#file_list[@]} -lt 2 ]; then
        [ -f $HOME/.password-store/.gpg-id ] || pass init aws-vault
    fi
}

versions() {
    uname -a
    cat /.versions || { printf "Versions file '%s' not found. Exiting ...\n" "/.versions" >&2; return 1; }
}

init_git() {
    local last_err=0
    if [ ! -f "${HOME}/.gitconfig" ]; then
        printf "\033[92;1m>>>\033[94;1m Initializing %s \033[92;1m>>>\033[0m\n" "Git"

        git_config || last_err=$?
    fi

    [ $last_err -eq 0 -a -f "${HOME}/.gitconfig" ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "Git"
}

check_crypto() {
    local last_err=0
    if [ ! -f /.crypto ]; then
        printf "\033[92;1m>>>\033[94;1m Checking %s \033[92;1m>>>\033[0m\n" "Crypto (ssh, gpg, pass)"

        init_ssh && init_gpg && init_pass \
            && date -u +%Y%m%dT%H%M%SZ > /.crypto \
            || last_err=$?
    fi

    [ $last_err -eq 0 -a -f /.crypto ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "Crypto (ssh, gpg, pass)"
}

exit_code=0
waiting() { printf "${1:-.}"; sleep 1; }
die() {
    local color=0
    local exit_code=${1:-$?}
    local msg="${2:-""}"
    [ -n "${msg}" ] && printf "%s\n" "$2"
    [ $exit_code -eq 0 ] && color=92 || color=91
    printf "\n\033[%d;1mExiting with code %d " $color $exit_code
    for i in {1..3}; do waiting; done
    printf "\033[0m\n"
}

do_init() {
    versions
    init_git && check_crypto
    [ -d ${HOME} ] || mkdir -p ${HOME}
    ln -s /data ${HOME}/data
    if [ ${VSCODE_DEBUGPY_PORT:-0} -gt 999 ]; then
        if [ ! -d /data/.vscode ]; then
            [ -d ~/.conf/vscode ] && \
                cp -r ~/.conf/vscode /data/.vscode && \
                sed -i -r "s/(\"port\"):\s*(\"\\$\{VSCODE_DEBUGPY_PORT\}\")$/\1: ${VSCODE_DEBUGPY_PORT}/g" /data/.vscode/launch.json
        fi
    fi
}

keep_alive() {
    [ "${KEEP_ALIVE:-false}" = "true" ] && tail -f /dev/null
}

print_args() {
    for arg in $@; do
        printf "arg: ${arg}\n"
    done
}
[ "${DEBUG:-false}" = "true" ] && print_args

trap die INT

case "$1" in
    docker)
        printf "You must exec into a shell to run the command: %s\n" "$(echo $@)"
        die 1
        ;;
    describe|help)
        describe
        ;;
    sh|bash)
        do_init
        shift
        eval "bash -l -c '$@'"
        bash -l
        [ $exit_code -eq 0 ] || exit_code=$?
        keep_alive
        ;;
    *)
        # [ "${1#ba}" = "sh" ] && do_init && shift
        do_init
        eval "bash -l -c '$@'"
        bash -l
        [ $exit_code -eq 0 ] || exit_code=$?
        keep_alive
        ;;
esac

[ $exit_code -eq 0 ] || die
