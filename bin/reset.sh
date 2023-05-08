#!/usr/bin/env bash

set -e

echo
printf "\033[92;1m>>>\033[94;1m %s: %s\033[92;1m <<<\033[0m\n" "cloud-cli-tools" "Reset Script"

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
NOTHING_MSG="Nothing to remove."

cd "${SCRIPT_DIR}/../"

source conf/project.env
source conf/defaults.env
source conf/versions.env
source conf/docker.env

[ -f "${PWD}/.container" ] && source ${PWD}/.container
WORKING_DIRECTORY=

count() { echo $#; }
check_lockfile() { echo "$(cat ${1})"; }
get_container_by_id() { docker ps -aq --filter id="$1"; }
get_container_by_name() { docker ps -aq --filter name="$1"; }

cleanup_dotfiles() {
    [ -d "${WORKING_DIRECTORY}" ] || { printf "\033[91m[ERROR] Not a valid directory. Received '%s'. Exiting ...\033[0m\n" "${WORKING_DIRECTORY}" >&2; exit 1; }
    
    printf "\033[93m>\033[0m Checking sub-directories: %s\n" "${WORKING_DIRECTORY}"

    local targeted=()
    local remove_command=(rm -rf)

    local aws_config_restore=false
    if [ -f "${WORKING_DIRECTORY}/.aws/config" -a -f "${WORKING_DIRECTORY}/.aws/config_restore" ]; then
        printf "\033[93m>\033[0m Restoring '%s' ...\n" "${WORKING_DIRECTORY}/.aws/config"
        cp "${WORKING_DIRECTORY}/.aws/config_restore" "${WORKING_DIRECTORY}/.aws/config"
        if [ -d "${WORKING_DIRECTORY}/.aws" ]; then
            targeted+=($(find "${WORKING_DIRECTORY}/.aws" -type d -mindepth 1 -print))
        fi
        aws_config_restore=true
    fi

    if [ $# -gt 0 ]; then
        for item in $@; do
            item_basename="$(basename ${item})"
            [ "${item_basename}" = ".aws" -a "${aws_config_restore}" != "true" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".awsvault" -a "${aws_config_restore}" != "true" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".gnupg" -a "${aws_config_restore}" != "true" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".password-store" -a "${aws_config_restore}" != "true" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".dpctl" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".kube" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".profile.d" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
        done
    fi

    if [ ${#targeted[@]} -gt 0 ]; then
        printf "\033[93m>\033[0m Removing %d sub-directories ...\n" ${#targeted[@]}
        remove_command+=(${targeted[@]})
        printf "%s\n" "${targeted[@]}"
        ${remove_command[@]}
    fi
}

clean_lockfile() {
    if [ -f "${PWD}/${1}" ]; then
        printf "\033[93m>\033[0m Removing '%s' ...\n" "$1"
        rm -f "${PWD}/${1}"
    fi
}

quick_clean() {
    if [ -n "$1" ]; then
        local targeted="$(get_container_by_name ${1})"
        if [ -n "$targeted" ]; then
            printf "\033[93m>\033[0m Removing container %s (%s) ...\n" "${1}" "${targeted}"
            echo $targeted | xargs docker rm -f
        fi
    fi

    clean_lockfile "${_CONTAINER_CACHE_FILE}"
}

remove_volume() {
    if [ -f "${_MOUNT_CACHE_FILE}" ]; then
        RANDOMSTR="$(check_lockfile ${_MOUNT_CACHE_FILE})"
        printf "\033[93m>\033[0m Removing docker volume '%s' ...\n" "${RANDOMSTR}"
        docker volume rm "${RANDOMSTR}"
        clean_lockfile "${_MOUNT_CACHE_FILE}"
    fi
}

full_clean() {
    WORKING_DIRECTORY="$1"
    cleanup_dotfiles $(ls -d ${WORKING_DIRECTORY}/.*)
}

deep_clean() {
    WORKING_DIRECTORY="$1"
    printf "\033[93m>\033[0m Checking: %s\n" "${WORKING_DIRECTORY}/.aws"
    if [ -d "${WORKING_DIRECTORY}/.aws" ]; then
        rm -rf "${WORKING_DIRECTORY}/.aws"
    else
        printf "\033[91m>\033[0m Not Found. %s\n" "${NOTHING_MSG}"
    fi
    remove_volume
}

mode=quick
deep=false

while [ $# -gt 0 ]; do
    option="$1"
    shift
    case "${option}" in
        -D|--deep)
            deep=true
            mode="full"
            ;;
        -F|--full)
            mode="full"
            ;;
        *)
            printf "Invalid option. Exiting ...\n" >&2
            exit 1
    esac
done

printf "\033[92mCleanup Mode: \033[92;1m%s (deep: %s)\033[0m\n" "${mode}" "${deep}"

quick_clean "${CONTAINER_NAME}"

if [ "$mode" = "full" ]; then
    [ -d "${PWD}/mount/home/${DOCKER_USER}" ] && full_clean "${PWD}/mount/home/${DOCKER_USER}"
    if [ -d "${PWD}/mount/addons" ]; then
        printf "\033[93m>\033[0m Removing '%s' ...\n" "${PWD}/mount/addons"
        rm -rf "${PWD}/mount/addons"
    fi
else
    deep=false
fi

if [ "$deep" = "true" ]; then
    deep_clean "${PWD}/mount/home/${DOCKER_USER}"
fi