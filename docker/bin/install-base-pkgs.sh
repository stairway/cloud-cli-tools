#!/bin/bash -e

set -o pipefail

set -x

# RUN \
    apt-get --assume-yes --quiet update && \
    export TZ_COUNTRY=$(echo "$TZ" | awk -F'/' '{print $1}') && \
    export TZ_CITY=$(echo "$TZ" | awk -F'/' '{print $2}') && \
    echo "tzdata tzdata/Areas select $TZ_COUNTRY" | debconf-set-selections && \
    echo "tzdata tzdata/Zones/$TZ_COUNTRY select $TZ_CITY" | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install $INSTALL_PKGS && \
    rm --recursive --force /var/lib/apt/lists/* && \
    pip3 install --upgrade pip --no-cache-dir && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    touch /usr/share/locale/locale.alias && \
    locale-gen && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    . /etc/os-release && echo "${NAME} ${VERSION}" >> /.versions

# RUN \
    cat >> /etc/skel/.bashrc <<EOF

if [ -f "\${BASHRC_EXTRA:-$BASHRC_EXTRA}" ]; then
    . "\${BASHRC_EXTRA:-$BASHRC_EXTRA}"
fi

EOF

# Install additional python versions
# PIP_CACHE_DIR=$DOTLOCAL python${python_version} -m pip install $PIP_PKGS
# RUN \
    export PYTHON_DEFAULT_VERSION=$(python3 --version | awk '{print $2}' | awk -F'.' '{print $1"."$2}') && \
    apt-get --assume-yes --quiet update && \
    DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install software-properties-common && \
    add-apt-repository -y 'ppa:deadsnakes/ppa' && \
    { [ "${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" != "${PYTHON_DEFAULT_VERSION}" ] && \
        DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install "python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" "python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}-distutils" && \
        update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${PYTHON_DEFAULT_VERSION}" 99 && \
        update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" 98 && \
        update-alternatives --set python3 $(update-alternatives --list python3 | grep "python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}") && \
        python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION} -m pip install $PIP_PKGS --no-cache-dir; } && \
    python${PYTHON_DEFAULT_VERSION} -m pip install $PIP_PKGS --no-cache-dir && \
    priority=0 && \
    { for python_version in $(echo $ADDITIONAL_PYTHON_VERSIONS); do \
        [ "${python_version}" != "${PYTHON_DEFAULT_VERSION}" -a "${python_version}" != "${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" ] && \
            priority=$((priority+1)) && \
            DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install "python${python_version}" "python${python_version}-distutils" && \
            update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${python_version}" $priority && \
            python${python_version} -m pip install $PIP_PKGS --no-cache-dir; \
    done; } && \
    DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install python-is-python3 && \
    rm --recursive --force /var/lib/apt/lists/* && \
    pip cache purge
