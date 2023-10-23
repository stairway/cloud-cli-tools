#!/bin/bash

# RUN \
    [ -d "$HOMELOCAL" ] || mkdir -p $HOMELOCAL

# https://python-poetry.org/docs/
# POETRY_HOME default : ~/.local/share/pypoetry
# To override: `curl -sSL https://install.python-poetry.org | POETRY_HOME=/etc/poetry python3 -`
# RUN \
    curl -sSL https://install.python-poetry.org | POETRY_HOME=$HOMELOCAL/poetry python3 -

# RUN \
    poetry_bin_path=$HOME/.local/poetry/bin && \
    ln -s $poetry_bin_path/* $HOMELOCAL/bin

# https://github.com/tfutils/tfenv
# Example: `git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv && ln -s ~/.tfenv/bin/* /usr/local/bin`
# RUN \
    [ "${TERRAFORM_VERSION:-latest}" = "latest" ] && \
        version=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') || \
        version="$(echo ${TERRAFORM_VERSION} | sed s/^v//g)" && \
        latest_version=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') && \
    git clone --depth=1 https://github.com/tfutils/tfenv.git $HOMELOCAL/tfenv && \
    tfenv_bin_path=$HOMELOCAL/tfenv/bin && \
    ln -s $tfenv_bin_path/* $HOMELOCAL/bin && \
    "${tfenv_bin_path}/tfenv" install $version && \
    "${tfenv_bin_path}/tfenv" use $version && \
    [ "$version" != "$latest_version" ] && "${tfenv_bin_path}/tfenv" install $latest_version

# RUN \
    chown -R "ubuntu:ubuntu" $HOMELOCAL
