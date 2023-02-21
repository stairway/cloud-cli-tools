# syntax=docker/dockerfile:1
ARG VERSION=latest
FROM --platform=linux/amd64 ubuntu:$VERSION
LABEL org.opencontainers.image.authors="Andrew Haller <andrew.haller@grainger.com>"

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
    # this is v1 version of aws-cli ... v2 downloaded with curl, below
    # awscli \
    openssl \
    nano \
    vim \
    jq \
    zip \
    locales \
    pass \
    gpg \
    lsb-release \
    python3-pip \
    python3-venv \
    npm"

# TODO: gpg not currently working with non-root user
RUN [ "${USER:-root}" = "root" ] || { \
        INSTALL_PKGS="${INSTALL_PKGS} sudo" && \
        # useradd -rm -d ${HOME} -s /bin/bash -g root -G sudo -u ${UID} ${USER} && \
        useradd --system --create-home --home-dir ${HOME} --shell /bin/bash --gid root --groups sudo --uid ${UID:-1001} ${USER} && \
        echo "${USER}:${USER}" | chpasswd && \
        echo 'root:root' | chpasswd; }

# Install all packages (except docker)
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y $INSTALL_PKGS && \
    apt-get clean -y && \
    pip3 install --upgrade pip && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    touch /usr/share/locale/locale.alias && \
    locale-gen && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    . /etc/os-release && echo "${NAME} ${VERSION}" >> /.versions

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install Docker
# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
ARG DOCKER_PKGS="\
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin"

WORKDIR /tmp/downloads

RUN touch gh-get-latest-release.sh && \
    chmod +x gh-get-latest-release.sh && \
    echo  "#!/bin/sh -x\n\
gh_latest_release() {\n\
  curl --silent \"https://api.github.com/repos/\$1/releases/latest\" | # Get latest release from GitHub api\n\
    grep '\"tag_name\":' |                                            # Get tag line\n\
    sed -E 's/.*\"([^\"]+)\".*/\\\1/'                                    # Pluck JSON value\n\
}\n\
gh_latest_release \"\$@\"\n\
"> gh-get-latest-release.sh

RUN mkdir -m 0755 -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y $DOCKER_PKGS && \
    apt-get clean -y && \
    docker --version >> /.versions

RUN [ "${DOCKER_COMPOSE_VERSION:-latest}" = "latest" ] && \
        DOCKER_COMPOSE_VERSION=$(./gh-get-latest-release.sh "docker/compose") || \
        DOCKER_COMPOSE_VERSION="v$(echo ${DOCKER_COMPOSE_VERSION} | sed s/^v//g)" && \
    curl -LO "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" && \
    curl -LO "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(cat docker-compose-linux-x86_64.sha256 | grep --color=never docker-compose-linux-x86_64 | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "docker-compose-linux-x86_64: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install docker-compose-linux-x86_64 /usr/local/bin/docker-compose && \
    docker-compose --version >> /.versions

# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# *note* --install-dir /usr/local/aws-cli --update as a precaution in case awscli v1 (see above) has already been installed
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    update_in_case_v1_installed() { [ -f /bin/aws ] && \
        printf "\033[93;1m[WARNING] aws cli version 1 has been detected\033[0m\n" && \
        ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update || \
        ./aws/install; } && update_in_case_v1_installed && \
    aws --version >> /.versions

RUN [ "${AWS_VAULT_VERSION:-latest}" = "latest" ] && \
        AWS_VAULT_VERSION=$(./gh-get-latest-release.sh "99designs/aws-vault") || \
        AWS_VAULT_VERSION="v$(echo ${AWS_VAULT_VERSION} | sed s/^v//g)" && \
    curl -LO "https://github.com/99designs/aws-vault/releases/download/${AWS_VAULT_VERSION}/aws-vault-linux-amd64" && \
    curl -L "https://github.com/99designs/aws-vault/releases/download/${AWS_VAULT_VERSION}/SHA256SUMS" -o "aws-vault-${AWS_VAULT_VERSION}.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(cat aws-vault-${AWS_VAULT_VERSION}.sha256 | grep --color=never aws-vault-linux-amd64 | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "aws-vault-linux-amd64: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install aws-vault-linux-amd64 /usr/local/bin/aws-vault && \
    printf "aws-vault: %s\n" "$(aws-vault --version 2>&1)" >> /.versions

RUN wget -O- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    echo \
        "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \
        $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null && \
    apt update -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y vault && \
    apt-get clean -y && \
    printf "Hashicorp %s\n" "$(vault --version | awk '{print $1" "$2}')" >> /.versions

RUN [ "${MINIKUBE_VERSION:-latest}" = "latest" ] && \
        MINIKUBE_VERSION=$(./gh-get-latest-release.sh "kubernetes/minikube") || \
        MINIKUBE_VERSION="v$(echo ${MINIKUBE_VERSION} | sed s/^v//g)" && \
    curl -LO "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64" && \
    curl -LO "https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(echo "$(cat minikube-linux-amd64.sha256)  minikube-linux-amd64" | sha256sum --check) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "minikube-linux-amd64: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install minikube-linux-amd64 /usr/local/bin/minikube && \
    printf "minikube: %s\n" "$(minikube version --short)" >> /.versions

RUN echo "if [ -f /etc/bash_completion ] && ! shopt -oq posix; then . /etc/bash_completion; fi"  >> "${HOME}/.bashrc"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER $USER
WORKDIR $HOME

# Additional Metadata

ARG VERSION=latest
LABEL org.opencontainers.image.base.name="ubuntu:$VERSION"
