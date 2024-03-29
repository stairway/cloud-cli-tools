#!/usr/bin/env bash

echo
printf "\033[92;1m>>>\033[94;1m %s: %s\033[92;1m <<<\033[0m\n" "cloud-cli-tools" "Package Script"

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
PACKAGE_DIR="$(dirname $SCRIPT_DIR)"
PACKAGE_NAME="$(basename $PACKAGE_DIR)"
PACKAGE_PARENT_DIR="$(dirname ${PACKAGE_DIR})"
ARCHIVE_NAME="${PACKAGE_NAME}/dist/${PACKAGE_NAME}"

cd "${PACKAGE_PARENT_DIR}"

[ -d "${SCRIPT_DIR}/../dist" ] || mkdir "${SCRIPT_DIR}/../dist"

create_tar() {
    printf "\033[93m>\033[0m Creating '%s' ...\n" "${ARCHIVE_NAME}.tgz"

    local exclude=("")
    for e in ${EXCLUDES[@]}; do
        exclude+=("--exclude=$e")
    done

    tar_command=(
        tar
        ${exclude[@]}
        -czvf
        "${ARCHIVE_NAME}.tgz"
        "${INCLUDES[@]}"
    )

    printf "\033[96;1m%s\033[0m\n" "$(echo ${tar_command[@]})"
    eval "$(echo ${tar_command[@]})"
}

create_zip() {
    printf "\033[93m>\033[0m Creating '%s' ...\n" "${ARCHIVE_NAME}.zip"

    local exclude=("")
    for e in ${EXCLUDES[@]}; do
        exclude+=("-x ${e}")
    done

    zip_command=(
        zip
        -r
        -
        "${INCLUDES[@]}"
        "${exclude[@]}"
        \>"${ARCHIVE_NAME}.zip"
    )

    printf "\033[96;1m%s\033[0m\n" "$(echo ${zip_command[@]})"
    eval "$(echo ${zip_command[@]})"
}

package() {
    unset INCLUDES
    INCLUDES=("")
    unset EXCLUDES
    EXCLUDES=("")

    INCLUDES+=(
        "${PACKAGE_NAME}/bin/*"
        "${PACKAGE_NAME}/conf/*"
        "${PACKAGE_NAME}/docker/*"
        "${PACKAGE_NAME}/cct"
        "${PACKAGE_NAME}/docker-login"
        "${PACKAGE_NAME}/install-cct"
        "${PACKAGE_NAME}/README.md"
    )

    EXCLUDES+=(
        ".DS_Store"
        "'${PACKAGE_NAME}/docker/addons/_*'"
    )

    case "${1}" in
        tar)
            create_tar
            ;;
        zip)
            create_zip
            ;;
        * )
            exit 1
            ;;
    esac
}

package "tar"
package "zip"
