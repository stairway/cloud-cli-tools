#!/usr/bin/env bash

set -euf
LC_CTYPE=C

if [ -f "$0" ]; then
    SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
    script=true
else
    SCRIPT_DIR="$(pwd)/bin"
    script=false
fi

echo
printf "\033[92;1m>>>\033[94;1m %s: %s\033[92;1m <<<\033[0m\n" "cloud-cli-tools" "Build Script"

cd "${SCRIPT_DIR}/../"

convert_zip() {
    base_dir="${1:-docker/addons}"
    for d in $(find ${base_dir} -mindepth 1 -type d | grep --color=never -v /_); do
        for f in $(ls -1 ${d}/ | grep --color=never -v '^_'); do 
            _fname="$(basename ${f} .zip)"
            _ext=$(echo $f | awk -F"$_fname" '{print $2}')
            _command="bin/zip2tgz.sh ${d}/${f} ${d}/${_fname}"
            [ "$_ext" = ".zip" ] && printf "\033[96;1m%s\033[0m\n" "${_command}" && sh -c "${_command}" || continue
        done
    done
}

source conf/project.env
source conf/defaults.env
source conf/versions.env
source conf/docker.env

export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-0}"
export COMPOSE_DOCKER_CLI_BUILD="${COMPOSE_DOCKER_CLI_BUILD:-0}"
DOCKER_BUILD_NO_CACHE="${DOCKER_BUILD_NO_CACHE:-false}"

build_base() {
    local build_opts=()
    if [ "${DOCKER_BUILD_NO_CACHE}" = "true" ] ; then build_opts+=(--no-cache); fi
    
    local created_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local build_args=(
        --build-arg BUILD_DATE="${created_date}"
        --build-arg GIT_COMMIT="$(git rev-parse --short HEAD)"
        --build-arg IMAGE_NAME="${DOCKER_IMAGE_PARENT}"
        --build-arg IMAGE_VERSION="${DOCKER_IMAGE_PARENT_VERSION}"
    )
    [ "${UBUNTU_VERSION:-latest}" = "latest" ] || build_args+=(--build-arg VERSION="${UBUNTU_VERSION}")
    [ "${DOCKER_USER:-root}" = "root" ] || build_args+=(--build-arg USER="${DOCKER_USER}")
    [ "${DOCKER_USER:-root}" = "root" ] || build_args+=(--build-arg HOME="/home/${DOCKER_USER}")
    [ "${UBUNTU_VERSION:-latest}" = "latest" ] || build_args+=(--build-arg VERSION="${UBUNTU_VERSION}")
    [ "${AWS_VAULT_VERSION:-latest}" = "latest" ] || build_args+=(--build-arg AWS_VAULT_VERSION="${AWS_VAULT_VERSION}")
    [ "${MINIKUBE_VERSION:-latest}" = "latest" ] || build_args+=(--build-arg MINIKUBE_VERSION="${MINIKUBE_VERSION}")

     local build_labels=(
        --label "org.opencontainers.image.vendor=\"${VENDOR_ORGANIZATION}\""
        --label "com.${CONSUMER_ORG_LOWER}.image.name=${DOCKER_IMAGE_PARENT}:${DOCKER_IMAGE_PARENT_VERSION}"
    )

    local build_command=(docker build)
    build_command+=(
        ${build_opts[@]}
        -f docker/dockerfiles/Dockerfile.base
        ${build_args[@]}
        ${build_labels[@]}
        "$@"
        -t "${DOCKER_IMAGE_PARENT}:${DOCKER_IMAGE_PARENT_VERSION}"
        "./docker"
    )

    # docker pull --platform linux/amd64 "ubuntu:${UBUNTU_VERSION}"

    printf "\033[96;1m%s\n\033[0m" "$(echo ${build_command[@]})"
    
    eval ${build_command[@]}
}

build_new() {
    local build_opts=(
        --push
        --platform=linux/amd64,linux/arm64,linux/arm/v7
    )
    if [ "${DOCKER_BUILD_NO_CACHE:-false}" = "true" ] ; then build_opts+=(--no-cache); fi

    local created_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local build_args=(
        --build-arg IMAGE_BASE_NAME="${DOCKER_IMAGE_PARENT}"
        --build-arg VERSION="${DOCKER_IMAGE_PARENT_VERSION}"
        --build-arg BUILD_DATE="${created_date}"
        --build-arg GIT_COMMIT="$(git rev-parse --short HEAD)"
        --build-arg IMAGE_NAME="${DOCKER_IMAGE}"
        --build-arg IMAGE_VERSION="${DOCKER_IMAGE_VERSION}"
    )
    [ "${KUBE_VERSION:-latest}" != "latest" ] && build_args+=(--build-arg KUBE_VERSION="${KUBE_VERSION}")
    [ "${ISTIO_VERSION:-latest}" != "latest" ] && build_args+=(--build-arg ISTIO_VERSION="${ISTIO_VERSION}")
    [ "${TERRAFORM_VERSION:-latest}" != "latest" ] && build_args+=(--build-arg TERRAFORM_VERSION="${TERRAFORM_VERSION}")
    [ "${TERRAGRUNT_VERSION:-latest}" != "latest" ] && build_args+=(--build-arg TERRAGRUNT_VERSION="${TERRAGRUNT_VERSION}")
    [ "${HELM_VERSION:-latest}" != "latest" ] && build_args+=(--build-arg HELM_VERSION="${HELM_VERSION}")

    local build_labels=(
        --label "org.opencontainers.image.vendor=\"${VENDOR_ORGANIZATION}\""
        --label "com.${CONSUMER_ORG_LOWER}.image.name=${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}"
    )

    local build_command=(docker buildx build)
    build_command+=(
        ${build_opts[@]}
        -f docker/dockerfiles/Dockerfile.main
        ${build_args[@]}
        ${build_labels[@]}
        "$@"
        -t "${DOCKER_IMAGE}:${DOCKER_IMAGE_VERSION}"
        "./docker"
    )

    # If parent image remotely
    # docker pull "${DOCKER_IMAGE_PARENT}:${DOCKER_IMAGE_PARENT_VERSION}"

    printf "\033[96;1m%s\n\033[0m" "$(echo ${build_command[@]})"

    eval ${build_command[@]}
}

convert_zip

BUILD_MODE="${BUILD_MODE:-quick}"

while [ $# -gt 0 ]; do
    option="$1"
    shift
    case "${option}" in
        -F|--full)
            BUILD_MODE="full"
            ;;
        -N|--no-cache)
            DOCKER_BUILD_NO_CACHE=true
            ;;
        *)
            printf "Invalid option. Exiting ...\n" >&2
            exit 1
    esac
done

ADDITIONAL_BUILD_OPTS=()
argc=$#

if [ $argc -gt 1 ]; then
    i=1
    for arg in $@; do
        [ $i -lt $argc ] && ADDITIONAL_BUILD_OPTS+=($arg) && shift
        i=$(($i+1))
    done
fi

printf "\033[92mBuild Mode: \033[92;1m%s\033[0m\n" "${BUILD_MODE}"

sh -c "$(cat ./docker-login)"

if [ "$BUILD_MODE" = "full" ]; then
    build_base ${ADDITIONAL_BUILD_OPTS[@]+"${ADDITIONAL_BUILD_OPTS[@]}"}
    docker push "${DOCKER_IMAGE_PARENT}:${DOCKER_IMAGE_PARENT_VERSION}"
    build_new
else
    build_new ${ADDITIONAL_BUILD_OPTS[@]+"${ADDITIONAL_BUILD_OPTS[@]}"}
fi
