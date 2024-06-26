#!/usr/bin/env bash

set -euf
# LC_CTYPE=C

check_dependencies() {
    # check for other required dependencies on host machine
    local needs_jq=$([ -n "$(which jq)" -a -e "$(which jq)" ] && echo false || echo true)
    local needs_openssl=$([ -n "$(which openssl)" -a -e "$(which openssl)" ] && echo false || echo true)
    local needs_uuidgen=$([ -n "$(which uuidgen)" -a -e "$(which uuidgen)" ] && echo false || echo true)

    if [ "$needs_jq" = "true" ] ; then printf "Please make sure '%s' is properly installed (%s).\nExiting ...\n" "jq" "https://stedolan.github.io/jq/download/" >&2 ; return 1 ; fi
    if [ "$needs_openssl" = "true" -a "$needs_uuidgen" = true ] ; then printf "Please make sure either '%s' or '%s' are properly installed. Exiting ...\n" "openssl" "uuidgen" >&2; return 1 ; fi
}

check_dependencies || { printf "\033[91m[ERROR] Mising required dependency\033[0m\n" >&2; exit 1; }

if [ -f "$0" ]; then
    SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
    script=true
else
    SCRIPT_DIR="$(pwd)/bin"
    script=false
fi

# DOCKER_RUN_DETACHED="${DOCKER_RUN_DETACHED:-$script}"

echo
printf "\033[92;1m>>>\033[94;1m %s: %s\033[92;1m <<<\033[0m\n" "cloud-cli-tools" "Run Script"

cd "${SCRIPT_DIR}/../"

[ -f conf/.env ] && . conf/.env
. conf/shared/project.env
. conf/main/defaults.env
. conf/shared/docker-shared.env
. conf/base/versions-base.env
. conf/base/docker-base.env
. conf/main/versions.env
. conf/main/docker.env

count() { echo $#; }
check_lockfile() { echo "$(cat ${1:-""})"; }
get_running_container_by_id() { docker ps -q --filter id="${1:-""}"; }
get_running_container_by_name() { docker ps -q --filter name="${1:-""}"; }
get_all_container_by_name() { docker ps -a -q --filter name="${1:-""}"; }
get_mountpoint() { local mountpoint=$(docker volume inspect "${RANDOMSTR}" | jq .[].Mountpoint --raw-output 2>/dev/null); [ "${mountpoint}" != "[]" ] && echo "${mountpoint}"; }

container_exists() {
    [ -n "${1}" -a -n "$(get_running_container_by_name ${1})" ] && return 0
    [ -n "${1}" -a -n "$(get_all_container_by_name ${1})" ] && return 0
    return 1
}

touch $_CONTAINER_CACHE_FILE
touch $_MOUNT_CACHE_FILE

CONTAINER_ID=
# RANDOMSTR="$(check_lockfile ${_MOUNT_CACHE_FILE})" && CONTAINER_ID="$(check_lockfile ${_CONTAINER_CACHE_FILE})"
RANDOMSTR="$(check_lockfile $PWD/${_MOUNT_CACHE_FILE})" && source "${PWD}/.container"
CONTAINER_NAME="${CONTAINER_NAME:-$RANDOMSTR}"
TARGET_ARCH="${TARGET_ARCH:-"linux/amd/64"}"
PLATFORM="${PLATFORM:-$TARGET_ARCH}"

USERNAME="${USERNAME:-""}"
TEAM_NAME="${TEAM_NAME:-""}"
DEFAULT_PROFILE="${DEFAULT_PROFILE:-user}"
CLUSTER_PREFIX="${CLUSTER_PREFIX:-di}"
AWS_VAULT_USER_REGION="${AWS_VAULT_USER_REGION:-""}"
GIT_CONFIG_FULL_NAME="${GIT_CONFIG_FULL_NAME:-""}"
GIT_CONFIG_EMAIL="${GIT_CONFIG_EMAIL:-""}"
FILE_EDITOR="${FILE_EDITOR:-""}"
VSCODE_DEBUGPY="${VSCODE_DEBUGPY:-""}"
VSCODE_DEBUGPY_PORT="${VSCODE_DEBUGPY_PORT:-5678}"

YES_VALUE="${YES_VALUE:-yes}"
NO_VALUE="${NO_VALUE:-no}"

DOCKER_HISTFILE_NAME="${DOCKER_HISTFILE_NAME:-.bash_history}"
[ "${DOCKER_TERM:-xterm}" = "xterm" ] && DOCKER_TERM="${DOCKER_TERM}-color"

init_mountcache() {
    [ -n "$(which uuidgen)" ] && RANDOMSTR=$(uuidgen) || RANDOMSTR="$(openssl rand -hex 16)"
    CONTAINER_NAME="${RANDOMSTR}"
    echo "${RANDOMSTR}" > ${_MOUNT_CACHE_FILE}
}

[ -n "${RANDOMSTR}" ] || init_mountcache

usage() {
    cat <<EOF

usage: run.sh -u <user> -t <team_name> -n <full_name> -m <email> -e <editor>
       run.sh --user <user> --team <team_name> --name <full_name> --email <email> --editor <editor>

*Note* Parameters with spaces (i.e. full_name) MUST be wrapped in quotes.

EOF
}

exec_container() {
    local container="${1:-$(get_running_container_by_id ${CONTAINER_ID})}"
    [ -n "${container:-""}" ] || return $?
    local com=(docker exec -it)
    com+=("${container}")
    com+=(bash -l)

    printf "\033[93m>\033[0m Accessing %s ...\n\033[96;1m%s\033[0m\n" "${container}" "$(echo ${com[@]})"
    ${com[@]}
}

attach_container() {
    local container="${1:-$(get_running_container_by_id ${CONTAINER_ID})}"
    [ -n "${container:-""}" ] || return $?
    local com=(docker attach)
    com+=("${container}")

    printf "\033[93m>\033[0m Accessing %s ...\n\033[96;1m%s\033[0m\n" "${container}" "$(echo ${com[@]})"
    ${com[@]}
}

start_container() {
    local container="${1:-$(get_all_container_by_name ${CONTAINER_NAME})}"
    [ -n "${CONTAINER_NAME:-""}" ] || return $?
    local com=(docker start)
    com+=(
        -a
        -i
        "${container}"
    )
    printf "\033[93m>\033[0m Starting up %s ...\n\033[96;1m%s\033[0m\n" "${container}" "$(echo ${com[@]})"
    ${com[@]}
}

user_prompt() {
    if [ $# -eq 0 -o -n "${dash_args:-""}" ]; then
        echo

        while [ -z "${USERNAME}" ]; do
            printf "Enter your User Name (e.g. racfid): "
            read USERNAME
        done

        while [ -z "${TEAM_NAME}" ]; do
            printf "Enter your Team Name (\033[32;3mdefault: \033[32;3;1m%s\033[0m): " "${TEAM_NAME_DEFAULT}"
            read TEAM_NAME && TEAM_NAME="${TEAM_NAME:-$TEAM_NAME_DEFAULT}"
        done

        while [ -z "${GIT_CONFIG_FULL_NAME}" ]; do
            printf "Enter your Full Name: "
            read GIT_CONFIG_FULL_NAME
        done

        while [ -z "${AWS_VAULT_USER_REGION}" ]; do
            AWS_VAULT_USER_REGION_DEFAULT="${AWS_VAULT_USER_REGION:-""}"
            printf "Enter AWS Account ID (\033[32;3mdefault: \033[32;3;1m%s\033[0m): " "$([ -n "${AWS_VAULT_USER_REGION_DEFAULT}" ] && echo ${AWS_VAULT_USER_REGION_DEFAULT} || echo empty)"
            read AWS_VAULT_USER_REGION && AWS_VAULT_USER_REGION="${AWS_VAULT_USER_REGION:-$AWS_VAULT_USER_REGION_DEFAULT}"
        done

        while [ -z "${GIT_CONFIG_EMAIL}" ]; do
            GIT_CONFIG_EMAIL_EXPECTED="$(echo ${GIT_CONFIG_FULL_NAME} | awk '{ print tolower($1"."$2) }')""@${CONSUMER_DOMAIN}"
            printf "Enter your Email (\033[32;3mdefault: \033[32;3;1m%s\033[0m): " "${GIT_CONFIG_EMAIL_EXPECTED}"
            read GIT_CONFIG_EMAIL && GIT_CONFIG_EMAIL="${GIT_CONFIG_EMAIL:-$GIT_CONFIG_EMAIL_EXPECTED}"
        done

        while  [ -z "${FILE_EDITOR}" ]; do
            if [ "${FILE_EDITOR_DEFAULT:-""}" = "vim" ]; then
                FILE_EDITOR_ALT_1="nano"
            else
                FILE_EDITOR_DEFAULT="nano"
                FILE_EDITOR_ALT_1="vim"
            fi
            printf "Choose your desired editor (\033[32;3mdefault: \033[32;3;1m%s\033[0m | \033[32;3m%s\033[0m): " "${FILE_EDITOR_DEFAULT}" "${FILE_EDITOR_ALT_1}"
            read FILE_EDITOR && FILE_EDITOR="${FILE_EDITOR:-$FILE_EDITOR_DEFAULT}"
            if [ "$FILE_EDITOR" != "${FILE_EDITOR_DEFAULT}" ]; then
                if [ "$FILE_EDITOR" != "${FILE_EDITOR_ALT_1}" ]; then
                    FILE_EDITOR=
                fi
            fi
        done

        while [ "${VSCODE_DEBUGPY}" != "${YES_VALUE}" -a "${VSCODE_DEBUGPY}" != "${NO_VALUE}" ]; do
            if [ "${VSCODE_DEBUGPY_DEFAULT:-""}" = "${YES_VALUE}" ]; then
                VSCODE_DEBUGPY_ALT="${NO_VALUE}"
            else
                VSCODE_DEBUGPY_DEFAULT="${NO_VALUE}"
                VSCODE_DEBUGPY_ALT="${YES_VALUE}"
            fi
            printf "Attach Visual Studio Code for python debugging (debugpy) (\033[32;3mdefault: \033[32;3;1m%s\033[0m | \033[32;3m%s\033[0m): " "$VSCODE_DEBUGPY_DEFAULT" "$VSCODE_DEBUGPY_ALT"
            read VSCODE_DEBUGPY && VSCODE_DEBUGPY="${VSCODE_DEBUGPY:-$VSCODE_DEBUGPY_DEFAULT}"
        done

        while [ "${TAILSCALED}" != "${YES_VALUE}" -a "${TAILSCALED}" != "${NO_VALUE}" ]; do
            if [ "${TAILSCALED_DEFAULT:-""}" = "${YES_VALUE}" ]; then
                TAILSCALED_ALT="${NO_VALUE}"
            else
                TAILSCALED_DEFAULT="${NO_VALUE}"
                TAILSCALED_ALT="${YES_VALUE}"
            fi
            printf "Configure Tailscaled (tailscaled) (\033[32;3mdefault: \033[32;3;1m%s\033[0m | \033[32;3m%s\033[0m): " "$TAILSCALED_DEFAULT" "$TAILSCALED_ALT"
            read TAILSCALED && TAILSCALED="${TAILSCALED:-$TAILSCALED_DEFAULT}"
        done

        echo

        command_msg=()
        [ -f "$0" ] && command_msg+=($0) || command_msg+=(bin/run.sh)

        command_msg+=(
            -d "${FILE_EDITOR}"
            -m "'${GIT_CONFIG_EMAIL}'"
            -n "'${GIT_CONFIG_FULL_NAME}'"
            -p "${PLATFORM}"
            -r "${AWS_VAULT_USER_REGION}"
            -t "${TEAM_NAME}"
            -u "${USERNAME}"
        )
        [ "${VSCODE_DEBUGPY}" = "${YES_VALUE}" ] && command_msg+=(--vscode-debugpy "${VSCODE_DEBUGPY_PORT}")

        printf "\033[96m>\033[0m Advanced Command: \033[1m%s\033[0m\n" "$(echo ${command_msg[@]})"
    else
        while [ $# -gt 0 ]; do
            option="$1"
            shift
            case "${option}" in
                -d|--editor)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    FILE_EDITOR="$1"
                    shift
                    ;;
                -m|--email)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    GIT_CONFIG_EMAIL="$1"
                    shift
                    ;;
                -n|--name|--full-name)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    GIT_CONFIG_FULL_NAME="$1"
                    shift
                    ;;
                -p|--platform)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    PLATFORM="$1"
                    shift
                    ;;
                -r|--aws-vault-user-region)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    AWS_VAULT_USER_REGION="$1"
                    shift
                    ;;
                -t|--team)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    TEAM_NAME="$1"
                    shift
                    ;;
                -u|--user)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    USERNAME="$1"
                    shift
                    ;;
                --vscode-debugpy)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    VSCODE_DEBUGPY_PORT="$1"
                    shift
                    ;;
                *)
                    usage >&2
                    break
                    exit 1
            esac
        done
    fi
}

copy_addons() {
    local source_dir="${1:-docker/addons}"
    local target_dir="${2:-mount/addons}"
    local files="$(find ${source_dir} -mindepth 1 -type f -name *.zip)"
    if [ $(count "${files[@]}") -gt 0 ]; then
        [ -d "${target_dir}" ] || mkdir "${target_dir}"
        for f in ${files[@]}; do
            printf "\033[93m>\033[0m Copying '%s' to '%s'\n" "${f}" "${target_dir}/$(basename ${f} .zip).zip"
        done
        cp ${files[@]} "${target_dir}/" 2>/dev/null || true
    fi
}

copy_profile() {
    local source_dir="${1:-docker/profile}"
    local target_dir="${2:-mount/profile}"
    local files="$(find ${source_dir} -mindepth 1 -type f -name *.sh)"
    if [ $(count "${files[@]}") -gt 0 ]; then
        [ -d "${target_dir}" ] || mkdir "${target_dir}"
        for f in ${files[@]}; do
            printf "\033[93m>\033[0m Copying '%s' to '%s'\n" "${f}" "${target_dir}/$(basename ${f} .sh).sh"
        done
        cp ${files[@]} "${target_dir}/" 2>/dev/null || true
    fi
}

arr_to_str() {
    arr="$@"
    str=""
    if [ $# -gt 0 ]; then
        argc=$#
        while [ $# -gt 0 ]; do
            if [ $# -eq $argc ]; then
                part="$1" && shift && str="${part}" || continue
            else
                part="$1" && shift && str="${str} ${part}" || continue
            fi
        done
    fi
    echo "${str}"
}

run_new() {
    local docker_user_home=
    [ "${DOCKER_USER:-root}" = "root" ] && \
        docker_user_home="/${DOCKER_USER}" || \
        docker_user_home="/home/${DOCKER_USER}"

    [ -d "mount/home/${DOCKER_USER}" ] || mkdir -p "mount/home/${DOCKER_USER}"

    local docker_histfile="${DOCKER_HISTFILE:-${docker_user_home}/${DOCKER_HISTFILE_NAME}}"
    touch "${PWD}/mount/home/${DOCKER_USER}/${DOCKER_HISTFILE_NAME}"
    touch "${PWD}/mount/home/${DOCKER_USER}/.env"

    copy_addons
    # copy_profile "docker/profile" "mount/home/${DOCKER_USER}/.profile.d"

    user_prompt "$@"

    local docker_image="${DOCKER_IMAGE}:${1:-$DOCKER_IMAGE_VERSION}"

    docker volume create "${RANDOMSTR}"

    local pull_command=(docker pull "${docker_image}")
    printf "\033[93m>\033[0m Attempting to pull '%s' from remote ...\n\033[96;1m%s\033[0m\n" "${docker_image}" "$(echo ${pull_command[@]})"
    { eval "${pull_command[@]}"; } || true

    local mountpoint=$(get_mountpoint)
    local mount_volumes=(
        -v "${mountpoint}/.awsvault:${docker_user_home}/.awsvault"
        -v "${mountpoint}/.gnupg:${docker_user_home}/.gnupg"
        -v "${mountpoint}/.password-store:${docker_user_home}/.password-store"
        -v "${PWD}/mount/home/${DOCKER_USER}/${DOCKER_HISTFILE_NAME}:${docker_histfile}"
        -v "${PWD}/mount/home/${DOCKER_USER}/.env:${docker_user_home}/.local/.env"
        -v "${PWD}/mount/home/${DOCKER_USER}/.aws:${docker_user_home}/.aws"
        -v "${PWD}/mount/home/${DOCKER_USER}/.kube:${docker_user_home}/.kube"
        -v "${PWD}/mount/home/${DOCKER_USER}/.ssh:${docker_user_home}/.ssh"
        -v "${PWD}/mount/home/${DOCKER_USER}/.ssh:${docker_user_home}/.ssh"
        -v "${PWD}/mount/data:/data"
        -v /var/run/docker.sock:/var/run/docker.sock
        # --mount "type=volume,src='${RANDOMSTR}',dst=${docker_user_home}/.local"
    )

    [ -d "${PWD}/mount/addons" -a $(count $(ls -1 ${PWD}/mount/addons)) -gt 0 ] && mount_volumes+=(-v "${PWD}/mount/addons:/tmp/addons")
    [ "${DEBUG:-false}" = "true" ] && mount_volumes+=(-v "${PWD}/docker/bin/docker-entrypoint.sh:/opt/local/bin/docker-entrypoint.sh")
    [ "${DEBUG:-false}" = "true" ] && mount_volumes+=(-v "${PWD}/docker/bin/crypto.sh:/opt/local/bin/crypto.sh")
    [ "${DEBUG:-false}" = "true" ] && mount_volumes+=(-v "${PWD}/docker/bin/init.sh:/opt/local/bin/init.sh")
    [ "${DEBUG:-false}" = "true" ] && mount_volumes+=(-v "${PWD}/docker/profile:/opt/local/profile.d")
    [ "${DEBUG:-false}" = "true" ] && mount_volumes+=(-v "${PWD}:/data/$(basename $(pwd))")

    local run_mode=("-p 8000:8000")
    [ "${VSCODE_DEBUGPY}" = "${YES_VALUE}" ] && run_mode+=("-p ${VSCODE_DEBUGPY_PORT}:${VSCODE_DEBUGPY_PORT}")

    if [ "${TAILSCALED}" = "${YES_VALUE}" ]; then
        mount_volumes+=(
            -v "/dev/net/tun:/dev/net/tun"
            -v "/lib/modules:/lib/modules"
        )
        caps=(
            --cap-add NET_ADMIN
            --cap-add SYS_MODULE
        )
    fi

    if [ "${DOCKER_RUN_DETACHED:-false}" = "true" ]; then
        run_mode+=(
            -d
            "${docker_image}"
            # \'printf \"Current Time: %s\\n\" "\$(date -u +%Y%m%dT%H%M%SZ)"\'
        )
        KEEP_ALIVE=true
    else
        run_mode+=(
            -it
            "${docker_image}"
            # bash -l
            # \'printf \"Current Time: %s\\n\" "\$(date -u +%Y%m%dT%H%M%SZ)"\'
        )
        KEEP_ALIVE=false
    fi

    local environment_vars=(
        -e "KEEP_ALIVE=${KEEP_ALIVE}"
        -e "USERNAME=${USERNAME}"
        -e "TEAM_NAME=${TEAM_NAME}"
        -e "CLUSTER_PREFIX=${CLUSTER_PREFIX}"
        -e "EDITOR=${FILE_EDITOR}"
        # -e "VISUAL=${FILE_EDITOR}"
        # -e "GIT_EDITOR=${FILE_EDITOR}"
        # -e "KUBE_EDITOR=${FILE_EDITOR}"
        -e "DEFAULT_PROFILE=${DEFAULT_PROFILE}"
        -e "AWS_VAULT_USER_REGION=${AWS_VAULT_USER_REGION}"
        -e "'GIT_CONFIG_EMAIL=${GIT_CONFIG_EMAIL}'"
        -e "'GIT_CONFIG_FULL_NAME=${GIT_CONFIG_FULL_NAME}'"
        -e "'HISTFILE=${docker_histfile}'"
        -e "TERM=${DOCKER_TERM}"
        -e "UNAME=${DOCKER_USER}"
    )
    [ "${VSCODE_DEBUGPY}" = "${YES_VALUE}" ] && \
        environment_vars+=(-e "VSCODE_DEBUGPY_PORT=${VSCODE_DEBUGPY_PORT}")
    [ -n "${AWS_ACCESS_KEY_ID:-""}" -a -n "${AWS_SECRET_ACCESS_KEY:-""}" ] && \
        environment_vars+=(
            -e "'AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}'"
            -e "'AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}'"
        )
    [ $(which tput) ] && \
        environment_vars+=(
            -e COLUMNS="`tput cols`"
            -e LINES="`tput lines`"
        )
    [ "${DEBUG:-false}" = "true" ] && \
        environment_vars+=(-e "DEBUG=true")

    local run_command=(docker run)
    [ -n "$PLATFORM" ] && run_command+=(--platform "linux/${PLATFORM}")
    run_command+=(
        --name "$CONTAINER_NAME"
        # --network=host
        ${environment_vars[@]}
        ${mount_volumes[@]}
        ${caps[@]}
        ${run_mode[@]}
    )

    printf "\033[93m>\033[0m Running docker image '%s' ...\n\033[96;1m%s\033[0m\n" "${docker_image}" "$(echo ${run_command[@]})"

    printf "\033[93m>\033[0m Locking container name: %s\n" "${CONTAINER_NAME}"
    echo "CONTAINER_NAME=${CONTAINER_NAME}" > "${_CONTAINER_CACHE_FILE}"

    eval "$(echo ${run_command[@]})" && CONTAINER_ID="$(docker ps -q --no-trunc --filter name=${CONTAINER_NAME})"

    [ -n "${CONTAINER_ID}" ] && echo "CONTAINER_ID=${CONTAINER_ID}" >> "${_CONTAINER_CACHE_FILE}"
}

active=false
if [ -n "${CONTAINER_NAME}" -a -n "$(get_running_container_by_name ${CONTAINER_NAME})" ]; then
    printf "Found existing running: %s\n" "${CONTAINER_NAME}"
    active=true
elif [ -n "${CONTAINER_NAME}" -a -n "$(get_all_container_by_name ${CONTAINER_NAME})" ]; then
    printf "Found existing: %s\n" "${CONTAINER_NAME}"
    start_container "${CONTAINER_NAME:-""}"
else
    run_new "$@"
fi

if [ "${active}" = "true" -o "${DOCKER_RUN_DETACHED:-false}" = "true" ] ; then
    exec_container "${CONTAINER_NAME:-""}"
    # attach_container "${CONTAINER_ID:-""}"
fi

# [ -n "${CONTAINER_NAME}" -a -n "$(get_running_container_by_name ${CONTAINER_NAME})" ] && printf "Found existing\n" || run_new "$@"
# [ "${script}" = "true" ] && exec_container "${CONTAINER_NAME:-""}"
# [ "${script}" = "true" ] && start_container "${CONTAINER_NAME}"

unset active script
