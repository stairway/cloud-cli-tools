#!/bin/bash -e

set -o pipefail

# RUN \
    [ -d "$HOMELOCAL" ] || mkdir -p $HOMELOCAL/bin

# https://python-poetry.org/docs/
# POETRY_HOME default : ~/.local/share/pypoetry
# To override: `curl -sSL https://install.python-poetry.org | POETRY_HOME=/etc/poetry python3 -`
# RUN \
    curl -sSL https://install.python-poetry.org | POETRY_HOME=$HOMELOCAL/poetry python3 -

# Alternative: find $poetry_bin_path -mindepth 1 -maxdepth 1 -exec sh -c "val=$(echo {}); echo \"\$val\" \"\$HOMELOCAL/bin/\$(basename \$val)\"" {} \;
# RUN \
    poetry_bin_path="$HOMELOCAL/poetry/bin" && \
    ln -s $poetry_bin_path/* $HOMELOCAL/bin

# https://github.com/tfutils/tfenv
# Example: `git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv && ln -s ~/.tfenv/bin/* /usr/local/bin`
# RUN \
    [ "${TERRAFORM_VERSION:-latest}" = "latest" ] && \
        version=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') || \
        version="$(echo ${TERRAFORM_VERSION} | sed s/^v//g)" && \
        latest_version=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') && \
    git clone --depth=1 https://github.com/tfutils/tfenv.git $HOMELOCAL/tfenv && \
    tfenv_bin_path="$HOMELOCAL/tfenv/bin" && \
    ln -s $tfenv_bin_path/* $HOMELOCAL/bin && \
    "${tfenv_bin_path}/tfenv" install $version && \
    "${tfenv_bin_path}/tfenv" use $version && \
    [ "$version" != "$latest_version" ] && "${tfenv_bin_path}/tfenv" install $latest_version

# RUN \
    chown -R "$USER:$USER" $HOMELOCAL && \
    cat >> $HOME/.profile <<EOF
# Uncomment this if generic version (above) doesn't exist
# if [ "\$(whoami)" = "$UNAME" -a "$USER" != "$UNAME" ]; then
#     exec su -l $USER
# fi
EOF

# https://docs.brew.sh/Installation#unattended-installation
# The rest is in the dockerfile
RUN \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> ~/.bashrc && \
    brew install gcc yq
