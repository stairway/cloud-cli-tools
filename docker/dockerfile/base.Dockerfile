# syntax=docker/dockerfile:1
ARG VERSION=latest
FROM --platform=linux/amd64 ubuntu:$VERSION
ARG MAINTAINER="Andrew Haller <andrew.haller@grainger.com>"
LABEL maintainer="$MAINTAINER"

ARG AWS_VAULT_VERSION=latest
ARG MINIKUBE_VERSION=latest

# default values
ARG USER=root
ARG HOME=/root

# only used if HOME != root
ARG UID=1001

ENV USER=${USER}
ENV HOME=${HOME}

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils && \
    apt-get clean -y

ARG INSTALL_PKGS="\
    coreutils \
    bash-completion \
    curl \
    wget \
    # this is v1 version of aws-cli
    awscli \
    openssl \
    nano \
    jq \
    zip \
    locales \
    pass \
    gpg \
    python3-pip"

# TODO: gpg not currently working with non-root user
RUN [ "${USER:-root}" = "root" ] || { \
        INSTALL_PKGS="${INSTALL_PKGS} sudo" && \
        # useradd -rm -d ${HOME} -s /bin/bash -g root -G sudo -u ${UID} ${USER} && \
        useradd --system --create-home --home-dir ${HOME} --shell /bin/bash --gid root --groups sudo --uid ${UID:-1001} ${USER} && \
        echo "${USER}:${USER}" | chpasswd && \
        echo 'root:root' | chpasswd; }

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y $INSTALL_PKGS && \
    apt-get clean -y && \
    pip3 install --upgrade pip && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    touch /usr/share/locale/locale.alias && \
    locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /tmp/downloads

# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# *note* --install-dir /usr/local/aws-cli --update as a precaution in case awscli v1 (see above) has already been installed
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    update_in_case_v1_installed() { [ -f /bin/aws ] && \
        printf "\033[93;1m[WARNING] aws cli version 1 has been detected\033[0m\n" && \
        ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update || \
        ./aws/install; } && update_in_case_v1_installed && \
    aws --version

RUN [ "${AWS_VAULT_VERSION:-latest}" = "latest" ] && \
        AWS_VAULT_VERSION=$(curl -s https://api.github.com/repos/99designs/aws-vault/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') || \
        AWS_VAULT_VERSION="v$(echo ${AWS_VAULT_VERSION} | sed s/^v//g)" && \
    curl -LO "https://github.com/99designs/aws-vault/releases/download/${AWS_VAULT_VERSION}/aws-vault-linux-amd64" && \
    curl -L "https://github.com/99designs/aws-vault/releases/download/${AWS_VAULT_VERSION}/SHA256SUMS" -o "aws-vault-${AWS_VAULT_VERSION}.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(cat aws-vault-${AWS_VAULT_VERSION}.sha256 | grep --color=never aws-vault-linux-amd64 | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "aws-vault-linux-amd64: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install aws-vault-linux-amd64 /usr/local/bin/aws-vault && \
    aws-vault --version

RUN [ "${MINIKUBE_VERSION:-latest}" = "latest" ] && \
        MINIKUBE_VERSION=$(curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') || \
        MINIKUBE_VERSION="v$(echo ${MINIKUBE_VERSION} | sed s/^v//g)" && \
    curl -LO "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64" && \
    curl -LO "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(echo "$(cat minikube-linux-amd64.sha256)  minikube-linux-amd64" | sha256sum --check) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "kubectl: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install minikube-linux-amd64 /usr/local/bin/minikube && \
    minikube version

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER $USER
WORKDIR $HOME

ARG BUILD_IMAGE \
	BUILD_VERSION \
	BUILD_DATE \
    VENDOR_ORGANIZATION
    
LABEL \
	org.opencontainers.image.base.name="ubuntu:$VERSION" \
	org.opencontainers.image.url=$BUILD_IMAGE \
	org.opencontainers.image.created-date=$BUILD_DATE \
	org.opencontainers.image.version=$BUILD_VERSION \
	org.opencontainers.image.vendor=$VENDOR_ORGANIZATION \
	org.opencontainers.image.authors="$MAINTAINER" \
	org.opencontainers.image.description="docker run -d ${BUILD_IMAGE}:${BUILD_VERSION}" \
	com.grainger.image.name="${BUILD_IMAGE}:${BUILD_VERSION}"