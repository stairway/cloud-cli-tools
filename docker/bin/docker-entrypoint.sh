#!/bin/bash -e

set -o pipefail

USERNAME="${USERNAME:-""}"
GIT_CONFIG_FULL_NAME="${GIT_CONFIG_FULL_NAME:-""}"
GIT_CONFIG_EMAIL="${GIT_CONFIG_EMAIL:-""}"
EDITOR="${EDITOR:-""}"
GIT_DEFAULT_BRANCH="${GIT_DEFAULT_BRANCH:-main}"

[ -f /etc/profile.d/98-entrypoint.sh ] || cat > /etc/profile.d/98-entrypoint-vars.sh <<EOF
KEEP_ALIVE=${KEEP_ALIVE}
USERNAME=${USERNAME}
TEAM_NAME=${TEAM_NAME}
CLUSTER_PREFIX=${CLUSTER_PREFIX}
EDITOR=${EDITOR}
DEFAULT_PROFILE=${DEFAULT_PROFILE}
AWS_VAULT_USER_REGION=${AWS_VAULT_USER_REGION}
GIT_CONFIG_EMAIL='${GIT_CONFIG_EMAIL}'
GIT_CONFIG_FULL_NAME='${GIT_CONFIG_FULL_NAME}'
UNAME=${UNAME}
GIT_DEFAULT_BRANCH=${GIT_DEFAULT_BRANCH}
EOF

cat > /etc/profile.d/99-docker-user.sh <<EOF
if [ "\$(whoami)" = "root" -a "\$UNAME" != "root" ]; then
    USER="\$UNAME"
    HOME="/home/\$UNAME"
elif [ "\$(whoami)" != "root" -a "\$UNAME" = "root" ]; then
    USER="\$(whoami)"
    HOME="/home/\$(whoami)"
fi
EOF

for f in $(find /etc/profile.d -mindepth 1 -not \( -path '/etc/profile.d/9*-vars.sh' -prune \) -type f -name '*.sh' -print | sort -u); do
    . $f
done

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

ssh_config() {
    local file_list=0
    [ -d ~/.ssh ] || mkdir ~/.ssh
    file_list=($([ -d ~/.ssh ] && ls ~/.ssh 2>/dev/null))
    local gen_date=$(date -u +%Y%m%dT%H%M%SZ)
    local key_count=0
    key_count=$(ls -1 ~/.ssh | grep --color=never -o id_ed25519.fingerprint | wc -l)
    if [ ${key_count} -lt 1 ]; then
        printf "\033[93m>\033[0m Generating ssh ed25519 keypair with empty password ...\n\033[96;1m%s\033[0m\n" "ssh-keygen -t ed25519 -C '${USERNAME}' -f '${HOME}/.ssh/id_ed25519' -N ''"
        ssh-keygen -t ed25519 -C "${USERNAME}" -f ~/.ssh/id_ed25519 -N "" > ~/.ssh/${gen_date}.id_ed25519.fingerprint \
            && cat ~/.ssh/id_ed25519.pub
    fi
    key_count=0
    key_count=$(ls -1 ~/.ssh | grep --color=never -o id_rsa.fingerprint | wc -l)
    if [ ${key_count} -lt 1 ]; then
        printf "\033[93m>\033[0m Generating ssh rsa keypair with empty password ...\n\033[96;1m%s\033[0m\n" "ssh-keygen -t rsa -b 4096 -C '${USERNAME}' -f '${HOME}/.ssh/id_rsa' -N ''"
        ssh-keygen -t rsa -b 4096 -C "${USERNAME}" -f ~/.ssh/id_rsa -N "" > ~/.ssh/${gen_date}.id_rsa.fingerprint \
            && cat ~/.ssh/id_rsa.pub
    fi
}

versions() {
    uname -a
    cat /.versions || { printf "Versions file '%s' not found. Exiting ...\n" "/.versions" >&2; return 1; }
}

init_git() {
    local last_err=0
    # if [ ! -f ~/.gitconfig ]; then
        printf "\033[92;1m>>>\033[94;1m Initializing %s \033[92;1m>>>\033[0m\n" "Git"

        git_config || last_err=$?
    # fi

    [ $last_err -eq 0 -a -f ~/.gitconfig ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "Git"
}

init_ssh() {
    local last_err=0
    if [ ! -f ~/.ssh/.fingerprint -o ! -f ~/.ssh/.pub} ]; then
        printf "\033[92;1m>>>\033[94;1m Checking %s \033[92;1m>>>\033[0m\n" "SSH Config"

        ssh_config || last_err=$?

        [ $last_err -eq 0 ] && printf "\033[92;1m<<< Successfully Initialized %s <<<\033[0m\n" "SSH" || die $last_err
    fi
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
    crypto.sh
    init_git && init_ssh
    [ -e ~/data ] || ln -s /data ~/data
    if [ ${VSCODE_DEBUGPY_PORT:-0} -gt 999 ]; then
        if [ ! -d /data/.vscode ]; then
            [ -d $DOTLOCAL/conf/vscode ] && \
                cp -r $DOTLOCAL/conf/vscode /data/.vscode && \
                sed -i -r "s/(\"port\"):\s*(\"\\$\{VSCODE_DEBUGPY_PORT\}\")$/\1: ${VSCODE_DEBUGPY_PORT}/g" /data/.vscode/launch.json
        fi
    fi
}

keep_alive() {
    if [ "${KEEP_ALIVE:-false}" = "true" ]; then
        tail -f /dev/null
    fi
}

print_args() {
    for arg in $@; do
        printf "arg: ${arg}\n"
    done
}
[ "${DEBUG:-false}" != "true" ] || print_args
[ "${DEBUG:-false}" != "true" ] || printf "PATH=%s\n" $PATH
[ "${DEBUG:-false}" != "true" ] || printf "UNAME=%s\n" $UNAME
[ "${DEBUG:-false}" != "true" ] || printf "whoami=%s\n" "$(whoami)"
[ "${DEBUG:-false}" != "true" ] || printf "USER=%s\n" $USER
[ "${DEBUG:-false}" != "true" ] || printf "HOME=%s\n" $HOME

_is_tty() { tty >/dev/null 2>&1 && return $? || return $?; }

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
        exec "$@"
        [ $exit_code -eq 0 ] || exit_code=$?
        keep_alive
        ;;
    *)
        do_init
        if [ $# -gt 0 ]; then
            _is_tty && { bash -l -c "$@" && exec su -; } || bash -l -c "$@"
        else
            _is_tty && exec su - || true
        fi
        [ $exit_code -eq 0 ] || exit_code=$?
        keep_alive
        ;;
esac

[ $exit_code -eq 0 ] || die
