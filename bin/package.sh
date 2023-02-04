#!/usr/bin/env bash

printf "\033[92;1m>>>\033[94;1m %s: %s\033[92;1m <<<\033[0m\n" "cloud-cli-tools" "Package Script"

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PACKAGE_DIR="$(dirname $SCRIPT_DIR)"
PACKAGE_NAME="$(basename $PACKAGE_DIR)"
PACKAGE_PARENT_DIR="$(dirname ${PACKAGE_DIR})"
ARCHIVE_NAME="${PACKAGE_NAME}/dist/${PACKAGE_NAME}.tgz"
ARCHIVE_SOURCE="${PACKAGE_NAME}"

pushd "${PACKAGE_PARENT_DIR}"

[ -d "${SCRIPT_DIR}/../dist" ] || mkdir "${SCRIPT_DIR}/../dist"

packager() {
    local includes=(
        "${PACKAGE_NAME}/bin/*"
        "${PACKAGE_NAME}/conf/*"
        "${PACKAGE_NAME}/docker/*"
        "${PACKAGE_NAME}/cct"
        "${PACKAGE_NAME}/docker-login"
        "${PACKAGE_NAME}/install-cct"
        "${PACKAGE_NAME}/README.md"
    )

    local tar_command=(tar)
    tar_command+=(
        --exclude=".DS_Store"
        -czvf 
        "${ARCHIVE_NAME}" 
        "${includes[@]}"
    )

    ${tar_command[@]}
}

printf "\033[93m>\033[0m Creating '%s' ...\n" "${ARCHIVE_NAME}"
packager

popd