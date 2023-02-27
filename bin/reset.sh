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

check_lockfile() { echo "$(cat ${1})"; }
get_container_by_id() { docker ps -aq --filter id="$1"; }
get_container_by_name() { docker ps -aq --filter name="$1"; }

cleanup_dotfiles() {
    [ -d "${WORKING_DIRECTORY}" ] || { printf "\033[91m[ERROR] Not a valid directory. Received '%s'. Exiting ...\033[0m\n" "${WORKING_DIRECTORY}" >&2; exit 1; }
    
    if [ $# -gt 0 ]; then
        local remove_command=(rm -rf)
        local targeted=()
        for item in $@; do
            item_basename="$(basename ${item})"
            [ "${item_basename}" = ".aws" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".awsvault" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".dpctl" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".gnupg" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".kube" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
            [ "${item_basename}" = ".password-store" ] && targeted+=(${WORKING_DIRECTORY}/${item_basename})
        done
    fi

    printf "\033[93m>\033[0m Checking sub-directories: %s\n" "${WORKING_DIRECTORY}"
    if [ ${#targeted[@]} -gt 0 ]; then
        printf "\033[93m>\033[0m Removing %d sub-directories ...\n" ${#targeted[@]}
        remove_command+=(${targeted[@]})
        printf "%s\n" "${targeted[@]}"
        ${remove_command[@]}
    else
        printf "\033[91m>\033[0m Not Found. %s\n" "${NOTHING_MSG}"
    fi
}

clean_lockfile() {
    printf "\033[93m>\033[0m Checking for lockfile: %s\n" "$1"
    if [ -f "${PWD}/${1}" ]; then
        printf "\033[93m>\033[0m Removing ...\n"
        rm -f "${PWD}/${1}"
    else
        printf "\033[91m>\033[0m Not Found. %s\n" "${NOTHING_MSG}"
    fi
}

quick_clean() {
    if [ -n "$1" ]; then
        local targeted="$(get_container_by_name ${1})"
        printf "\033[93m>\033[0m Checking for container by name: %s (%s)\n" "${1}" "${targeted}"
        if [ -n "$targeted" ]; then
            printf "\033[93m>\033[0m Removing ...\n"
            echo $targeted | xargs docker rm -f
        else
            printf "\033[91m>\033[0m Not Found. %s\n" "${NOTHING_MSG}"
        fi
    fi

    clean_lockfile "${_CONTAINER_CACHE_FILE}"
}

full_clean() {
    WORKING_DIRECTORY="$1"
    cleanup_dotfiles $(ls -d ${WORKING_DIRECTORY}/.*)
    if [ -f "${_MOUNT_CACHE_FILE}" ]; then
        RANDOMSTR="$(check_lockfile ${_MOUNT_CACHE_FILE})"
        printf "\033[93m>\033[0m Removing docker volume: %s\n" "${RANDOMSTR}"
        docker volume rm "${RANDOMSTR}"
        clean_lockfile "${_MOUNT_CACHE_FILE}"
    fi
}

mode=quick

while [ $# -gt 0 ]; do
    option="$1"
    shift
    case "${option}" in
        -F|--full)
            mode="full"
            ;;
        *)
            printf "Invalid option. Exiting ...\n" >&2
            exit 1
    esac
done

printf "\033[92mCleanup Mode: \033[92;1m%s\033[0m\n" "${mode}"

quick_clean "${CONTAINER_NAME}"

if [ "$mode" = "full" ]; then
    [ -d "${PWD}/mount/dotfiles/${DOCKER_USER}" ] && full_clean "${PWD}/mount/dotfiles/${DOCKER_USER}"
    printf "\033[93m>\033[0m Removing '%s' ...\n" "${PWD}/mount/addons"
    rm -rf "${PWD}/mount/addons"
fi
