#!/bin/bash -e

set -o pipefail

# RUN \
    for f in $(ls -1 /tmp/addons); do install "/tmp/addons/${f}" "/usr/local/bin/${f}"; done && \
    rm -rf /tmp/addons && \
    chmod +x $DESCRIBE $DOTLOCAL/bin/* && \
    mkdir -p $HOMELOCAL/bin $PLUGINS $SHARED

# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
# RUN \
    [ "${KUBE_VERSION:-latest}" = "latest" ] && \
        version=$(curl -sSL https://dl.k8s.io/release/stable.txt) || \
        version="v$(echo ${KUBE_VERSION} | sed s/^v//g)" && \
    status=$($SCRIPTS/download-and-verify-2.sh "https://dl.k8s.io/release" \
        "kubernetes/kubectl" "${version}" \
        "kubectl" "kubectl.sha256" "bin/linux/amd64") && \
    echo $status && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    printf "Kubernetes %s\n" "$(kubectl version --short --client)" >> /.versions

# https://helm.sh/docs/intro/install/
# RUN \
    [ "${HELM_VERSION:-latest}" = "latest" ] && \
        HELM_VERSION=$($SCRIPTS/gh-get-latest-release.sh "helm/helm") || \
        HELM_VERSION="v$(echo ${HELM_VERSION} | sed s/^v//g)" && \
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh --version ${HELM_VERSION} && \
    printf "Helm %s\n" "$(helm version --short)" >> /.versions

##################################################
### SLIM - comment out the following section
##################################################
# RUN \
    [ "${KUBECTL_CONVERT_VERSION:-latest}" = "latest" ] && \
        version=$(curl -sSL https://dl.k8s.io/release/stable.txt) || \
        version="v$(echo ${KUBECTL_CONVERT_VERSION} | sed s/^v//g)" && \
    status=$($SCRIPTS/download-and-verify-2.sh "https://dl.k8s.io/release" \
        "kubernetes/kubectl-convert" "${version}" \
        "kubectl-convert" "kubectl-convert.sha256" "bin/linux/amd64") && \
    echo $status && \
    install -o root -g root -m 0755 kubectl-convert /usr/local/bin/kubectl-convert

# https://kind.sigs.k8s.io/
# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${KIND_VERSION}" "latest" "kubernetes-sigs/kind") && \
    status=$($SCRIPTS/download-and-verify-1.sh "https://kind.sigs.k8s.io/dl" \
        "kubernetes-sigs/kind" "${version}" \
        "kind-linux-amd64" "kind-linux-amd64.sha256sum") && \
    echo $status && \
    install kind-linux-amd64 /usr/local/bin/kind && \
    kind --version >> /.versions

# https://github.com/doitintl/kube-no-trouble
# The extra space (`... | sh - `) is required
# RUN \
    curl -sSL https://git.io/install-kubent | sh -

# RUN \
    $DOTLOCAL/bin/install-user.sh

# # https://python-poetry.org/docs/
# # POETRY_HOME default : ~/.local/share/pypoetry
# # To override: `curl -sSL https://install.python-poetry.org | POETRY_HOME=/etc/poetry python3 -`
# # RUN \
#     curl -sSL https://install.python-poetry.org | POETRY_HOME=$SHARED/poetry python3 -

# # RUN \
#     poetry_bin_path=$(command -v poetry >/dev/null && command -v poetry | xargs dirname | xargs dirname || { [ -d "${SHARED}/poetry/bin" ] && echo "${SHARED}/poetry/bin"; }) && \
#     [ -n "$poetry_bin_path" ] && ln -s $poetry_bin_path/* $HOMELOCAL/bin && \
#     "${poetry_bin_path}/poetry" completions bash >> $DOTLOCAL/.bash_completion

# # Install kubectx and kubens
# # https://github.com/ahmetb/kubectx/blob/master/README.md#manual-installation-macos-and-linux
# # RUN \
#     version=$($SCRIPTS/gh-get-version.sh "${KUBECTX_VERSION}" "latest" "ahmetb/kubectx") && \
#     status=$($SCRIPTS/gh-download-and-verify.sh "ahmetb/kubectx" "${version}" \
#         "kubectx_${version}_linux_x86_64.tar.gz" "checksums.txt") && \
#     echo $status && \
#     tar -xvzf kubectx_${version}_linux_x86_64.tar.gz && \
#     install kubectx /usr/local/bin/kubectx && \
#     printf "kubectx: %s\n" "$(kubectx --version)" >> /.versions

# # RUN \
#     version=$($SCRIPTS/gh-get-version.sh "${KUBECTX_VERSION}" "latest" "ahmetb/kubectx") && \
#     status=$($SCRIPTS/gh-download-and-verify.sh "ahmetb/kubectx" "${version}" \
#         "kubens_${version}_linux_x86_64.tar.gz" "checksums.txt") && \
#     echo $status && \
#     tar -xvzf kubens_${version}_linux_x86_64.tar.gz && \
#     install kubens /usr/local/bin/kubens && \
#     printf "kubens: %s\n" "$(kubens --version)" >> /.versions
##################################################

# # TODO: why doesn't standard istio install work?
# RUN version=$($SCRIPTS/gh-get-version.sh "${ISTIO_VERSION}" "latest" "istio/istio" | sed s/^v//g) && \
#     { curl -L https://istio.io/downloadIstio ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=x86_64 | sh -; } && \
#     install istio-${version}/bin/istioctl /usr/local/bin/istioctl && \
#     cp istio-${version}/tools/istioctl.bash $HOME/.istioctl.bash && \
#     printf "istio: %s\n" "$(istioctl version --remote=false --short)" >> /.versions

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${ISTIO_VERSION}" "latest" "istio/istio" | sed s/^v//g) && \
    status=$($SCRIPTS/gh-download-and-verify.sh "istio/istio" "${version}" \
        "istio-${version}-linux-amd64.tar.gz" "istio-${version}-linux-amd64.tar.gz.sha256") && \
    echo $status && \
    tar -xvzf istio-${version}-linux-amd64.tar.gz && \
    install istio-${version}/bin/istioctl /usr/local/bin/istioctl && \
    cp istio-${version}/tools/istioctl.bash $DOTLOCAL/.istioctl.bash && \
    printf "istio: %s\n" "$(istioctl version --remote=false --short)" >> /.versions

# RUN [ "${TERRAFORM_VERSION:-latest}" = "latest" ] && \
#         version=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') || \
#         version="$(echo ${TERRAFORM_VERSION} | sed s/^v//g)" && \
#     status=$($SCRIPTS/download-and-verify-1.sh "https://releases.hashicorp.com/terraform" \
#         "hashicorp/terraform" "${version}" \
#         "terraform_${version}_linux_amd64.zip" "terraform_${version}_SHA256SUMS") && \
#     echo $status && \
#     unzip -o "terraform_${version}_linux_amd64.zip" && \
#     install terraform /usr/bin/terraform && \
#     printf "Hashicorp %s\n" "$(echo $(terraform version) | awk '{print $1" "$2}')" >> /.versions && \
#     terraform -install-autocomplete

# https://github.com/tfutils/tfenv
# Example: `git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv && ln -s ~/.tfenv/bin/* /usr/local/bin`
# RUN \
    [ "${TERRAFORM_VERSION:-latest}" = "latest" ] && \
        version=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') || \
        version="$(echo ${TERRAFORM_VERSION} | sed s/^v//g)" && \
        latest_version=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') && \
    mkdir $SHARED/tfenv && \
    git clone --depth=1 https://github.com/tfutils/tfenv.git $SHARED/tfenv && \
    tfenv_bin_path=$(command -v tfenv >/dev/null && command -v tfenv | xargs dirname | xargs dirname || { [ -d "${SHARED}/tfenv/bin" ] && echo "${SHARED}/tfenv/bin"; }) && \
    [ -n "$tfenv_bin_path" ] && ln -s $tfenv_bin_path/* $HOMELOCAL/bin && \
    "${tfenv_bin_path}/tfenv" install $version && \
    "${tfenv_bin_path}/tfenv" use $version && \
    [ "$version" != "$latest_version" ] && "${tfenv_bin_path}/tfenv" install $latest_version

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${TERRAGRUNT_VERSION}" "latest" "gruntwork-io/terragrunt") && \
    status=$($SCRIPTS/gh-download-and-verify.sh "gruntwork-io/terragrunt" "${version}" \
        "terragrunt_linux_amd64" "SHA256SUMS") && \
    echo $status && \
    install terragrunt_linux_amd64 /usr/local/bin/terragrunt && \
    terragrunt --version >> /.versions

# RUN \
    version=$($SCRIPTS/gh-get-version.sh "${K9S_VERSION}" "latest" "derailed/k9s") && \
    status=$($SCRIPTS/gh-download-and-verify.sh "derailed/k9s" "${version}" \
        "k9s_Linux_amd64.tar.gz" "checksums.txt") && \
    echo $status && \
    tar -xvzf k9s_Linux_amd64.tar.gz k9s -C . && \
    install k9s /usr/local/bin/k9s && \
    k9s version

# RUN \
    curl -fsSL https://tailscale.com/install.sh | sh

# TODO
# Use gh client, and verify commit
# (https://docs.github.com/en/rest/git/tags?apiVersion=2022-11-28#get-a-tag)
# RUN \
    KUBE_PS1_VERSION="v$(echo ${KUBE_PS1_VERSION} | sed s/^v//g)" && \
    status_code=$(curl -sSLI -o /dev/null -w "%{http_code}" "https://github.com/jonmosco/kube-ps1/archive/refs/tags/${KUBE_PS1_VERSION}.zip") && \
    [ $status_code -eq 200 ] && \
    curl -sSLO "https://github.com/jonmosco/kube-ps1/archive/refs/tags/${KUBE_PS1_VERSION}.zip" && \
    unzip_result="$(unzip -o ${KUBE_PS1_VERSION}.zip)" && \
    echo $unzip_result | grep -q -i creating && \
    unzip_dir="$(echo $unzip_result | awk '{print $5}' | tr -d '/')" && \
    grep -q -E -i "^(\[\[?.+DEBUG.*\])(.+)(set -x)$" "${unzip_dir}/kube-ps1.sh" && \
    sed -E -i "0,/^\[\[?.+DEBUG.*\].+set -x$/s/^(\[\[?.+DEBUG.*\])(.+)(set -x)$/#\1\2\3/" "${unzip_dir}/kube-ps1.sh" && \
    printf "Installing '%s' to '%s' ...\n" "${unzip_dir}/kube-ps1.sh" "$PLUGINS/kube-ps1.sh" && \
    mv ${unzip_dir}/kube-ps1.sh $PLUGINS/

# RUN \
    echo '' >>  /etc/bash.bashrc && \
    echo '' >> "${HOME}/.bashrc" && \
    echo 'printf "\033[1m%s\033[0m\n" "Welcome to the machine ..."' >> /etc/bash.bashrc && \
    ln -s /usr/share/bash-completion/completions/git $DOTLOCAL/.git-completion.bash && \
    ln -s $DOTLOCAL/bin/* $HOMELOCAL/bin && \
    echo "[ \$# -eq 0 ] && $DOTLOCAL/bin/init.sh" > $DOTLOCAL/profile.d/init.sh && \
    unset path_extra && \
    for d in $(find $SHARED -mindepth 1 -maxdepth 2 -not \( -path "$DOTLOCAL" -prune \) -type d -name bin -print); do \
        [ -n "$path_extra" ] && path_extra="$path_extra:$d" || path_extra="$d"; \
    done && \
    cat > $BASHRC_EXTRA <<EOF
[ "\$(pwd)" = "\$HOME" ] || cd ~

export EDITOR="\${EDITOR:-$EDITOR}"
export VISUAL="\${VISUAL:-$EDITOR}"
export GIT_EDITOR="\${GIT_EDITOR:-$EDITOR}"
export KUBE_EDITOR="\${KUBE_EDITOR:-$EDITOR}"
export CLUSTER_PREFIX="\${CLUSTER_PREFIX:-di}"
export ENVFILE="\${ENVFILE:-$ENVFILE}"
export AWS_VAULT_BACKEND="${AWS_VAULT_BACKEND}"
HISTFILE="\${HOME}/.bash_history"
PROMPT_COMMAND='history -a;history -c;history -r;set -a;[ -e "${ENVFILE:-~/.local/.env}" ] && . "${ENVFILE:-~/.local/.env}"; set +a >/dev/null'

### See /etc/profile.d/10-set-path.sh
# [[ ":\$PATH:" == *":$path_extra:"* ]] || PATH="\$PATH:$path_extra"
#
# if [ -d "${SHARED}/bin" ]; then
#     [[ ":\$PATH:" == *":$SHARED/bin:"* ]] || PATH="${SHARED}/bin:\${PATH}"
# fi
#
# if [ -d "${DOTLOCAL}/bin" ]; then
#     [[ ":\$PATH:" == *":$DOTLOCAL/bin:"* ]] || PATH="${DOTLOCAL}/bin:\${PATH}"
# fi
###

if [ -f "$ENVFILE" ]; then
    set -o allexport
    . "$ENVFILE"
    set +o allexport
fi

if [ -d "\${PLUGINS:-$PLUGINS}" ]; then
    for f in \$(find "\${PLUGINS:-$PLUGINS}" -mindepth 1 -type f -name '*.sh' -print | sort -u); do
        . \$f
    done
fi

if [ -d "\${DOTLOCAL:-$DOTLOCAL}/profile.d" ]; then
    for f in \$(find "\${DOTLOCAL:-$DOTLOCAL}/profile.d" -mindepth 1 -type f -regextype posix-egrep -regex "\${DOTLOCAL:-$DOTLOCAL}/profile\.d\/[0-9]+.+\.sh" -print | sort -u); do
        . \$f
    done
fi

if [ -f "\${DOTLOCAL:-$DOTLOCAL}/bin/crypto.sh" ]; then
    . "\${DOTLOCAL:-$DOTLOCAL}/bin/crypto.sh"
fi

if [ -f "\${DOTLOCAL:-$DOTLOCAL}/bin/init.sh" ]; then
    . "\${DOTLOCAL:-$DOTLOCAL}/bin/init.sh"
fi

complete -C /usr/local/bin/aws_completer aws
. <(kubectl completion bash)
[ -e ~/.git-completion.bash ] && . /usr/share/bash-completion/completions/git
[ -e ~/.istioctl.bash ] && . ~/.istioctl.bash

EOF

# RUN \
    # (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> $BASHRC_EXTRA;

# RUN \
    [ "$USER" != "root" ] || \
        match=$(grep -E -i "^(mesg\s+n.+true)$" $HOME/.profile) && \
        sed -i "s@$match@@" $HOME/.profile && \
        cat >> $HOME/.profile <<EOF
# set PATH so it includes user's private bin if it exists
if [ -d "\$HOME/bin" ] ; then
    PATH="\$HOME/bin:\$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "\$HOME/.local/bin" ] ; then
    PATH="\$HOME/.local/bin:\$PATH"
fi

$match
EOF

# RUN \
    cat > /etc/profile.d/05-common-functions.sh <<EOF
explode() {
    delim="\${1:-""}"
    str="\${2:-""}"
    if [ "\${delim}x" != "x" -a "\${str}x" != "x" ]; then
        for part in \$(echo \$str | awk -F"\$delim" '{ for (i = 1; i <= NF; i++) print \$i }'); do
            echo "\$part"
        done
    else
      echo "\$str"
    fi
}
strsrch() {
    haystack="\${1:-""}"
    needle="\${2:-""}"
    delim="\${3:-""}"
    echo "\$haystack" | grep -q -E '\'"\${needle}\${delim}" || echo "\$haystack" | grep -q -E '\'"\${delim}\${needle}"
}
EOF

# RUN \
    cat > /etc/profile.d/10-set-path.sh <<EOF
_PATH="\${_PATH:-"$_PATH"}"
_tmp_path="\${_PATH:-\$PATH}"
for _path_extra in \$(find "\${SHARED:-$SHARED}" -mindepth 1 -maxdepth 2 -not \( -path "\${DOTLOCAL:-$DOTLOCAL}" -prune \) -type d -name bin -print | grep -v "\${SHARED:-$SHARED}/bin"); do
    if [ -d "\$_path_extra" ]; then
      strsrch "\$_tmp_path" "\$_path_extra"  || _tmp_path="\$_tmp_path:\$_path_extra"
    fi
done
for _path_extra in \$(explode ":" "\${SHARED:-$SHARED}/bin:\${DOTLOCAL:-$DOTLOCAL}/bin"); do
    if [ -d "\$_path_extra" ]; then
      strsrch "\$_tmp_path" "\${_path_extra}" || _tmp_path="\${_path_extra}:\$_tmp_path"
    fi
done
PATH="\$_tmp_path"
unset _path_extra _tmp_path
EOF

cat >> /etc/skel/.profile <<EOF

if [ "\$(pwd)" != "\$HOME" ]; then
    cd ~
fi

if [ "\$(whoami)" = "$USER" -a "\$UNAME" != "$USER" ]; then
    exec su -l \$UNAME
fi

EOF

# RUN \
    grep --color=never -E -q '(^#?\s*account\s*requisite\s*pam_time\.so$)(\s*)' /etc/pam.d/su && \
    sed -z -E -i "s@(#?\s*account\s*requisite\s*pam_time\.so)(\s*)@\1\2###\\
# Enable MOTD - Added by docker via $DOTLOCAL/bin/install.sh\\
###\\
# Prints the message of the day upon successful login.\\
# (Replaces the \`MOTD_FILE' option in login.defs)\\
# This includes a dynamically generated part from /run/motd.dynamic\\
# and a static (admin-editable) part from /etc/motd.\\
session    optional   pam_motd.so motd=/run/motd.dynamic\\
session    optional   pam_motd.so noupdate\2@" /etc/pam.d/su

# RUN \
    grep --color=never -E -q '#?\s*(auth\s*sufficient\s*pam_wheel\.so\s*[a-z]*)\s(\s*)' /etc/pam.d/su && \
    sed -E -z -i "s@#?\s*(auth\s*sufficient\s*pam_wheel\.so\s*[a-z]*)\s(\s*)@\1 group=root\2\2@g" /etc/pam.d/su

# RUN \
    chmod -R g+w $DOTLOCAL && \
    { $SCRIPTS/child-dirs.sh $HOME/.ssh $HOME/.gnupg $HOME/.password-store $HOME/.awsvault; } && \
    { [ "${DEBUG:-false}" = "true" ] || rm -rf $DOWNLOADS; }
