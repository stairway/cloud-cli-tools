#!/bin/bash -e

set -o pipefail

# RUN \
    touch $SCRIPTS/include-file.sh && \
    chmod +x $SCRIPTS/include-file.sh && \
    cat > $SCRIPTS/include-file.sh <<EOF
#!/bin/sh -euf
cat >> \$1 <<INCFILE

if [ -f \$2 ]; then
    . \$2
fi

INCFILE
EOF

# RUN \
    touch $SCRIPTS/child-dirs.sh && \
    chmod +x $SCRIPTS/child-dirs.sh && \
    cat > $SCRIPTS/child-dirs.sh <<EOF
#!/bin/sh -euf
for d in $(echo "\$@"); do \
[ -d \$d ] || mkdir -p \$d; \
done
EOF

# RUN \
    touch $SCRIPTS/str-lower.sh && \
    chmod +x $SCRIPTS/str-lower.sh && \
    cat > $SCRIPTS/str-lower.sh <<EOF
#!/bin/sh -euf
echo "\$@" | tr '[:upper:]' '[:lower:]'
EOF

# RUN \
    touch $SCRIPTS/get-arch.sh && \
    chmod +x $SCRIPTS/get-arch.sh && \
    cat > $SCRIPTS/get-arch.sh <<EOF
#!/bin/sh -euf
uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'
EOF

# RUN \
    touch $SCRIPTS/get-os.sh && \
    chmod +x $SCRIPTS/get-os.sh && \
    cat > $SCRIPTS/get-os.sh <<EOF
#!/bin/sh -euf
uname -s
EOF

# RUN \
    touch $SCRIPTS/get-platform.sh && \
    chmod +x $SCRIPTS/get-platform.sh && \
    cat > $SCRIPTS/get-platform.sh <<EOF
#!/bin/sh -euf
os=\$($SCRIPTS/get-os.sh)
arch=\$($SCRIPTS/get-arch.sh)
echo "\${os}_\${arch}"
EOF

# RUN \
    touch $SCRIPTS/gh-auth-status.sh && \
    chmod +x $SCRIPTS/gh-auth-status.sh && \
    cat > $SCRIPTS/gh-auth-status.sh <<EOF
#!/bin/sh -euf
gh_auth_status() {
    gh auth status >/dev/null 2>&1 || { [ -n "\${GH_CLIENT_TOKEN:-""}" ] && /usr/local/bin/gh-login >/dev/null 2>&1; }
    return \$?
}
gh_auth_status
exit \$?
EOF

# RUN \
    touch $SCRIPTS/gh-get-latest-release.sh && \
    chmod +x $SCRIPTS/gh-get-latest-release.sh && \
    cat > $SCRIPTS/gh-get-latest-release.sh <<EOF
#!/bin/sh -euf
# https://docs.github.com/en/rest/overview/resources-in-the-rest-api?apiVersion=2022-11-28#rate-limiting
gh_curl_latest_release() {
    curl --silent --show-error --location "https://api.github.com/repos/\${1}/releases/latest" | \
grep '\"tag_name\":' | \
sed -E 's/.*\"([^\"]+)\".*/\1/'
}
gh_client_latest_release() {
    $SCRIPTS/gh-auth-status.sh && gh api "repos/\${1}/releases/latest" --jq '.tag_name' 2>/dev/null
    return \$?
}
gh_client_latest_release "\$@" || \
gh_curl_latest_release "\$@"
exit \$?
EOF

# RUN \
    touch $SCRIPTS/gh-get-version.sh && \
    chmod +x $SCRIPTS/gh-get-version.sh && \
    cat > $SCRIPTS/gh-get-version.sh <<EOF
#!/bin/sh -euf
gh_get_version() {
    local return_code=$?
    local version
    [ "\${1:-\$2}" = "\$2" ] && \
version=\$($SCRIPTS/gh-get-latest-release.sh "\$3") || \
version="v\$(echo \$1 | sed s/^v//g)"
    return_code=\$?
    echo "\$version"
    return \$return_code
}
gh_get_version "\$@"
exit \$?
EOF

# RUN \
    touch $SCRIPTS/gh-download-release-asset.sh && \
    chmod +x $SCRIPTS/gh-download-release-asset.sh && \
    cat > $SCRIPTS/gh-download-release-asset.sh <<EOF
#!/bin/sh -euf
gh_download_release_asset() {
    $SCRIPTS/gh-auth-status.sh && gh release --repo "\${1}" download "\${2}" -p "\${3}" 2>/dev/null
    return \$?
}
gh_download_release_asset "\$@"
exit \$?
EOF

# RUN \
    touch $SCRIPTS/gh-download-and-verify.sh && \
    chmod +x $SCRIPTS/gh-download-and-verify.sh && \
    cat > $SCRIPTS/gh-download-and-verify.sh <<EOF
#!/bin/sh -euf
asset_name="\${3}"
asset_dir_rel="\${1}/\${2}/\$(echo \${3} | awk -F'.' '{print \$1}')"
mkdir -p "${DOWNLOADS}/\${asset_dir_rel}"
cd "${DOWNLOADS}/\${asset_dir_rel}"
gh_client_download_verify() {
    local return_code=\$?
    local status=
    $SCRIPTS/gh-download-release-asset.sh "\${1}" "\${2}" "\${3}" && \
$SCRIPTS/gh-download-release-asset.sh "\${1}" "\${2}" "\${4}" && \
status=\$(cat \${4} | grep --color=never \${3} | sha256sum -c -)
    return_code=\$?
    if [ \$return_code -eq 0 -a "\$status" = "\${3}: OK" ]; then
        printf "\033[92;1m%s\033[0m\n" "\$status"
    else
        printf "\033[91;1m%s\033[0m\n" "\$status" >&2
        return \$return_code
    fi
}
gh_curl_download_verify() {
    local return_code=\$?
    local status=
    curl -sSLO "https://github.com/\${1}/releases/download/\${2}/\${3}" && \
curl -sSLO "https://github.com/\${1}/releases/download/\${2}/\${4}" && \
status=\$(cat \${4} | grep --color=never \${3} | sha256sum -c -)
    return_code=\$?
    if [ \$return_code -eq 0 -a "\$status" = "\${3}: OK" ]; then
        printf "\033[92;1m%s\033[0m\n" "\$status"
    else
        printf "\033[91;1m%s\033[0m\n" "\$status" >&2
        return \$return_code
    fi
}
gh_client_download_verify "\$@" || \
gh_curl_download_verify "\$@"
exit_code=\$?
[ \$exit_code -eq 0 ] && cp "${DOWNLOADS}/\${asset_dir_rel}/\${asset_name}" $DOWNLOADS/ >/dev/null
exit \$exit_code
EOF

# RUN \
    touch $SCRIPTS/download-and-verify-1.sh && \
    chmod +x $SCRIPTS/download-and-verify-1.sh && \
    cat > $SCRIPTS/download-and-verify-1.sh <<EOF
#!/bin/sh -euf
asset_name="\${4}"
asset_dir_rel="\${2}/\${3}/\$(echo \${4} | awk -F'.' '{print \$1}')"
mkdir -p "${DOWNLOADS}/\${asset_dir_rel}"
cd "${DOWNLOADS}/\${asset_dir_rel}"
download_verify_1() {
    local return_code=\$?
    local status=
    local asset_base="\${1}/\${3}"
    local asset_uri=
    local checksum_uri=
    if [ -n "\${6:-""}" ]; then
        asset_uri="\${asset_base}/\${6}/\${4}"
        checksum_uri="\${asset_base}/\${6}/\${5}"
    else
        asset_uri="\${asset_base}/\${4}"
        checksum_uri="\${asset_base}/\${5}"
    fi
    curl -sSLO "\${asset_uri}" && \
curl -sSLO "\${checksum_uri}" && \
status=\$(cat \${5} | grep --color=never \${4} | sha256sum -c -)
    return_code=\$?
    if [ \$return_code -eq 0 -a "\$status" = "\${4}: OK" ]; then
        printf "\033[92;1m%s\033[0m\n" "\$status"
    else
        printf "\033[91;1m%s\033[0m\n" "\$status"
        return \$return_code
    fi
}
download_verify_1 "\$@"
exit_code=\$?
[ \$exit_code -eq 0 ] && cp "${DOWNLOADS}/\${asset_dir_rel}/\${asset_name}" $DOWNLOADS/ >/dev/null
exit \$exit_code
EOF

# RUN \
    touch $SCRIPTS/download-and-verify-2.sh && \
    chmod +x $SCRIPTS/download-and-verify-2.sh && \
    cat > $SCRIPTS/download-and-verify-2.sh <<EOF
#!/bin/sh -euf
asset_name="\${4}"
asset_dir_rel="\${2}/\${3}/\$(echo \${4} | awk -F'.' '{print \$1}')"
mkdir -p "${DOWNLOADS}/\${asset_dir_rel}"
cd "${DOWNLOADS}/\${asset_dir_rel}"
download_verify_2() {
    local return_code=\$?
    local status=
    local asset_base="\${1}/\${3}"
    local asset_uri=
    local checksum_uri=
    if [ -n "\${6:-""}" ]; then
        asset_uri="\${asset_base}/\${6}/\${4}"
        checksum_uri="\${asset_base}/\${6}/\${5}"
    else
        asset_uri="\${asset_base}/\${4}"
        checksum_uri="\${asset_base}/\${5}"
    fi
    curl -sSLO "\${asset_uri}" && \
curl -sSLO "\${checksum_uri}" && \
status=\$(echo "\$(cat \${5})  \${4}" | sha256sum --check)
    return_code=\$?
    if [ \$return_code -eq 0 -a "\$status" = "\${4}: OK" ]; then
        printf "\033[92;1m%s\033[0m\n" "\$status"
    else
        printf "\033[91;1m%s\033[0m\n" "\$status"
        return \$return_code
    fi
}
download_verify_2 "\$@"
exit_code=\$?
[ \$exit_code -eq 0 ] && cp "${DOWNLOADS}/\${asset_dir_rel}/\${asset_name}" $DOWNLOADS/ >/dev/null
exit \$exit_code
EOF

# RUN \
    mkdir -m 0755 -p /etc/apt/keyrings && \
    git --version >> /.versions && \
    { $SCRIPTS/include-file.sh /root/.bashrc $BASHRC_EXTRA; }

# RUN \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages \
        stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get --assume-yes --quiet update && \
    DEBIAN_FRONTEND=noninteractive apt --assume-yes --quiet install gh && \
    rm --recursive --force /var/lib/apt/lists/* && \
    gh --version >> /.versions

# RUN \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get --assume-yes --quiet update && \
    DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install $DOCKER_PKGS && \
    rm --recursive --force /var/lib/apt/lists/* && \
    docker --version >> /.versions

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${DOCKER_COMPOSE_VERSION}" "latest" "docker/compose") && \
    status=$($SCRIPTS/gh-download-and-verify.sh "docker/compose" "${version}" \
        "docker-compose-linux-x86_64" "docker-compose-linux-x86_64.sha256") && \
    echo $status && \
    install docker-compose-linux-x86_64 /usr/local/bin/docker-compose && \
    docker-compose --version >> /.versions

# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# *note* --install-dir /usr/local/aws-cli --update as a precaution in case awscli v1 (see above) has already been installed
# RUN \
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -o awscliv2.zip && \
    update_in_case_v1_installed() { [ -f /bin/aws ] && \
        printf "\033[93;1m[WARNING] aws cli version 1 has been detected\033[0m\n" && \
        ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update || \
        ./aws/install; } && update_in_case_v1_installed && \
    aws --version >> /.versions

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${EKSCTL_VERSION}" "latest" "weaveworks/eksctl") && \
    platform=$($SCRIPTS/get-platform.sh) && \
    status=$($SCRIPTS/gh-download-and-verify.sh "weaveworks/eksctl" "${version}" \
        "eksctl_${platform}.tar.gz" "eksctl_checksums.txt") && \
    echo $status && \
    tar -xzf eksctl_${platform}.tar.gz -C ./ && rm eksctl_${platform}.tar.gz && \
    install eksctl /usr/local/bin/eksctl && \
    printf "eksctl: %s\n" "$(eksctl version 2>&1)" >> /.versions

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${AWS_VAULT_VERSION}" "latest" "99designs/aws-vault") && \
    status=$($SCRIPTS/gh-download-and-verify.sh "99designs/aws-vault" "${version}" \
        "aws-vault-linux-amd64" "SHA256SUMS") && \
    echo $status && \
    install aws-vault-linux-amd64 /usr/local/bin/aws-vault && \
    printf "aws-vault: %s\n" "$(aws-vault --version 2>&1)" >> /.versions

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${HASHICORP_VAULT_VERSION}" "latest" "hashicorp/vault" | sed s/^v//g) && \
    status=$($SCRIPTS/download-and-verify-1.sh "https://releases.hashicorp.com/vault" \
        "hashicorp/vault" "${version}" \
        "vault_${version}_linux_amd64.zip" "vault_${version}_SHA256SUMS") && \
    echo $status && \
    unzip -o "vault_${version}_linux_amd64.zip" && \
    install vault /usr/local/bin/vault && \
    printf "Hashicorp %s\n" "$(vault --version | awk '{print $1" "$2}')" >> /.versions

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${MINIKUBE_VERSION}" "latest" "kubernetes/minikube") && \
    status=$($SCRIPTS/download-and-verify-2.sh "https://storage.googleapis.com/minikube/releases" \
        "kubernetes/minikube" "${version}" \
        "minikube-linux-amd64" "minikube-linux-amd64.sha256") && \
    echo $status && \
    install minikube-linux-amd64 /usr/local/bin/minikube && \
    printf "minikube: %s\n" "$(minikube version --short)" >> /.versions

# RUN \
    echo $(cat /etc/bash.bashrc) | grep --color=never -q -E '#\s*(if ! shopt -oq posix.*\s*)#(.*\s*)#(.*\s*)#(.*\s*)#(.*\s*)#(.*\s*)#\s*(fi)' && \
    sed -z -i -E 's/#\s*(if ! shopt -oq posix.*\s*)#(.*\s*)#(.*\s*)#(.*\s*)#(.*\s*)#(.*\s*)#\s*(fi)/\1\2\3\4\5\6\7/' /etc/bash.bashrc || \
    echo "if [ -f /etc/bash_completion ] && ! shopt -oq posix; then . /etc/bash_completion; fi" >> "/root/.bashrc"

# RUN \
    echo $(cat "/root/.bashrc") | grep --color=never -q -E '(case.*in.*\s*)xterm-color(.*\s*esac)' && \
    sed -z -i -E 's/(case.*in.*\s*)xterm-color(.*\s*esac)/\1xterm-*color\2/g' "/root/.bashrc"

# RUN \
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq
