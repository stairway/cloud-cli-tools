#!/usr/bin/env bash

set -e

check_dependencies() {
    # check for other required dependencies on host machine
    local needs_jq=$([ -n "$(which jq})" -a -f "$(which jq})" ] && echo true || echo false)
    local needs_openssl=$([ -n "$(which openssl})" -a -f "$(which openssl})" ] && echo true || echo false)
    local needs_uuidgen=$([ -n "$(which uuidgen})" -a -f "$(which uuidgen})" ] && echo true || echo false)
    
    if $needs_jq ; then printf "Missing '%s'. Please make sure '%s' is properly installed (%s).\nExiting ...\n" "jq" "https://stedolan.github.io/jq/download/" >&2 ; exit 1 ; fi
    if $needs_openssl && $needs_uuidgen ; then { printf "Please make sure either '%s' or '%s' are properly installed. Exiting ...\n" "openssl" "uuidgen" >&2; exit 1; } ; fi
}

check_dependencies

if [ -f "$0" ]; then
    SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
    script=true
else
    SCRIPT_DIR="$(pwd)/bin"
    script=false
fi

printf "\033[92;1m>>>\033[94;1m %s: %s\033[92;1m <<<\033[0m\n" "cloud-cli-tools" "Run Script"

pushd "${SCRIPT_DIR}/../"

source conf/docker.env
source conf/defaults.env
source conf/project.env
source conf/versions.env

count() { echo $#; }
check_lockfile() { echo "$(cat ${1})"; }
get_running_container_by_id() { docker ps -q --filter id="$1"; }
get_running_container_by_name() { docker ps -q --filter name="$1"; }
get_mountpoint() { local mountpoint=$(docker volume inspect "${RANDOMSTR}" | jq .[].Mountpoint --raw-output 2>/dev/null); [ "${mountpoint}" != "[]" ] && echo "${mountpoint}"; }

touch $_CONTAINER_CACHE_FILE
touch $_MOUNT_CACHE_FILE

CONTAINER_ID=
# RANDOMSTR="$(check_lockfile ${_MOUNT_CACHE_FILE})" && CONTAINER_ID="$(check_lockfile ${_CONTAINER_CACHE_FILE})"
RANDOMSTR="$(check_lockfile $PWD/${_MOUNT_CACHE_FILE})" && source "${PWD}/.container"
CONTAINER_NAME="${CONTAINER_NAME:-$RANDOMSTR}"
CONTAINER_DESCRIPTION="${DOCKER_CONTAINER_NAME_PREFIX:-grainger-cloud-cli-tools}-${DOCKER_IMAGE_VERSION}"

init_mountcache() {
    [ -n "$(which uuidgen)" ] && RANDOMSTR=$(uuidgen) || RANDOMSTR="$(openssl rand -hex 16)"
    CONTAINER_NAME="${RANDOMSTR}"
    echo "${RANDOMSTR}" > ${_MOUNT_CACHE_FILE}
}

[ -n "${RANDOMSTR}" ] || init_mountcache

usage() {
    cat <<EOF

usage: run.sh <racfid> <team_name> <full_name> <email>

*Note* Parameters with spaces (i.e. full_name) MUST be wrapped in quotes.

EOF
}

exec_container() {
    local short_id=$(get_running_container_by_id ${1})
    local EXEC_COMMAND=(docker exec)
    EXEC_COMMAND+=(
        -it
        "${short_id}"
        bash -l
    )

    printf "\033[93m>\033[0m Accessing %s ...\n" "${short_id}"
    ${EXEC_COMMAND[@]}
}

user_prompt() {
    if [ $# -eq 0 ]; then
        echo
        while [ -z "$RACFID" ]; do
            printf "Enter your RACFID: "
            read RACFID
        done
        
        TEAM_NAME_DEFAULT=${TEAM_NAME:-di}
        printf "Enter your Team Name (\033[32;3mdefault: \033[32;3;1m%s\033[0m): " "${TEAM_NAME_DEFAULT}"
        read TEAM_NAME && TEAM_NAME="${TEAM_NAME:-$TEAM_NAME_DEFAULT}"
        #read -e -i $TEAM_NAME_DEFAULT TEAM_NAME < /dev/tty
        while [ -z "$GIT_CONFIG_FULL_NAME" ]; do
            printf "Enter your Full Name: "
            read GIT_CONFIG_FULL_NAME
        done
        GIT_CONFIG_EMAIL_EXPECTED="$(echo ${GIT_CONFIG_FULL_NAME} | awk '{ print tolower($1"."$2"@grainger.com") }')"
        printf "Enter your Email (\033[32;3mdefault: \033[32;3;1m%s\033[0m): " "${GIT_CONFIG_EMAIL_EXPECTED}"
        read GIT_CONFIG_EMAIL && GIT_CONFIG_EMAIL="${GIT_CONFIG_EMAIL:-$GIT_CONFIG_EMAIL_EXPECTED}"
        #read -e -i $GIT_CONFIG_EMAIL_EXPECTED GIT_CONFIG_EMAIL < /dev/tty
        if [ "$FILE_EDITOR_DEFAULT" = "nano" ]; then 
            FILE_EDITOR_ALT="vim";
        else
            FILE_EDITOR_ALT="nano"; 
            FILE_EDITOR_DEFAULT="vim"; 
        fi
        while  [ "$FILE_EDITOR" != "${FILE_EDITOR_DEFAULT}" -a "$FILE_EDITOR" != "${FILE_EDITOR_ALT}" ]; do
            printf "Choose your desired editor (\033[32;3mdefault: \033[32;3;1m%s\033[0m | \033[32;3m%s\033[0m): " "${FILE_EDITOR_DEFAULT}" "${FILE_EDITOR_ALT}"
            read FILE_EDITOR && FILE_EDITOR="${FILE_EDITOR:-$FILE_EDITOR_DEFAULT}"
        done
        echo

        command_msg=()
        [ -f "$0" ] && command_msg+=($0) || command_msg+=(bin/run.sh)

        command_msg+=(
            -u "${RACFID}"
            -t "${TEAM_NAME}"
            -n "'${GIT_CONFIG_FULL_NAME}'"
            -m "'${GIT_CONFIG_EMAIL}'"
            -e "${FILE_EDITOR}"
        )
        printf "\033[96m>\033[0m Advanced Command: \033[1m%s\033[0m\n" "$(echo ${command_msg[@]})"
    else
        while [ $# -gt 0 ]; do
            option="$1"
            shift
            case "${option}" in
                -u|--user|--racfid)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    RACFID="$1"
                    shift
                    ;;
                -t|--team|--team-name)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    TEAM_NAME="$1"
                    shift
                    ;;
                -n|--name|--full-name)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    GIT_CONFIG_FULL_NAME="$1"
                    shift
                    ;;
                -m|--email)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    GIT_CONFIG_EMAIL="$1"
                    shift
                    ;;
                -e|--editor)
                    [ -n "$1" ] || { usage >&2; exit 1; }
                    FILE_EDITOR="$1"
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

run_new() {
    user_prompt "$@"

    local docker_image="${DOCKER_IMAGE}:${1:-$DOCKER_IMAGE_VERSION}"

    docker volume create "${RANDOMSTR}"
    local mountpoint=$(get_mountpoint)
    local docker_user_home=/root
    [ "${DOCKER_USER:-root}" = "root" ] || docker_user_home="/home/${DOCKER_USER}"
    local mount_volumes=(
        -v "${mountpoint}/.awsvault:${docker_user_home}/.awsvault"
        -v "${mountpoint}/.gnupg:${docker_user_home}/.gnupg"
        -v "${mountpoint}/.password-store:${docker_user_home}/.password-store"
        -v "${PWD}/mount/dotfiles/${DOCKER_USER}/.aws:${docker_user_home}/.aws"
        -v "${PWD}/mount/dotfiles/${DOCKER_USER}/.kube:${docker_user_home}/.kube"
        -v "${PWD}/mount/dotfiles/${DOCKER_USER}/.dpctl:${docker_user_home}/.dpctl"
        -v "${PWD}/mount/dotfiles/${DOCKER_USER}/.ssh:${docker_user_home}/.ssh"
        -v "${PWD}/mount/data:/data"
    )

    local run_mode=()
    if [ "${script}" = "true" ]; then
        run_mode+=(
            -d
            "${docker_image}"
        )
        KEEP_ALIVE=true
    else
        run_mode+=(
            --rm
            -it
            "${docker_image}"
            "/bin/bash -c 'init.sh && tail -f /dev/null'"
        )
        KEEP_ALIVE=false
    fi

    local environment_vars=(
        -e "KEEP_ALIVE=${KEEP_ALIVE}"
        -e "RACFID=${RACFID}"
        -e "TEAM_NAME=${TEAM_NAME}"
        -e "GIT_CONFIG_EMAIL=\"${GIT_CONFIG_EMAIL}\""
        -e "GIT_CONFIG_FULL_NAME=\"${GIT_CONFIG_FULL_NAME}\""
        -e "EDITOR=${FILE_EDITOR}"
        -e "TRUE=\"${TRUE}\""
    )
    [ -n "${AWS_ACCESS_KEY_ID}" -a -n "${AWS_SECRET_ACCESS_KEY}" ] && \
        environment_vars+=(
            -e "AWS_ACCESS_KEY_ID=\"${AWS_ACCESS_KEY_ID}\""
            -e "AWS_SECRET_ACCESS_KEY=\"${AWS_SECRET_ACCESS_KEY}\""
        )
    
    local run_command=(docker run)
    run_command+=(
        --name="${CONTAINER_NAME}"
        --label description="'${CONTAINER_DESCRIPTION}'"
        --platform linux/amd64
        --network=host
        ${environment_vars[@]}
        ${mount_volumes[@]}
        ${run_mode[@]}
    )

    printf "\033[93m>\033[0m Running docker image '%s' ...\n\033[96;1m%s\033[0m\n" "${docker_image}" "$(echo ${run_command[@]})"

    printf "\033[93m>\033[0m Locking container name: %s\n" "${CONTAINER_NAME}"
    echo "CONTAINER_NAME=${CONTAINER_NAME}" > "${_CONTAINER_CACHE_FILE}"
    
    eval ${run_command[@]} && CONTAINER_ID="$(docker ps -q --no-trunc --filter name=${CONTAINER_NAME})"

    [ -n "${CONTAINER_ID}" ] && echo "CONTAINER_ID=${CONTAINER_ID}" >> "${_CONTAINER_CACHE_FILE}"
}

[ -n "${CONTAINER_NAME}" -a -n "$(get_running_container_by_name ${CONTAINER_NAME})" ] || run_new "$@"
[ "${script}" = "true" ] && exec_container "${CONTAINER_ID}"

popd