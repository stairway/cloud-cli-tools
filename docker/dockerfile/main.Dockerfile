# syntax=docker/dockerfile:1
ARG VERSION=base-latest
ARG IMAGE_NAME=
FROM ${IMAGE_NAME}:${VERSION}
LABEL org.opencontainers.image.authors="Andrew Haller <andrew.haller@grainger.com>"

ARG KUBE_VERSION=v1.21.0
ARG ISTIO_VERSION=1.11.8
ARG TERRAFORM_VERSION=1.3.6
ARG TERRAGRUNT_VERSION=0.31.1
ARG HELM_VERSION=v3.9.4

ENV TZ=America/Chicago
ENV TERM=xterm-color
ENV EDITOR=nano

ENV AWS_VAULT_BACKEND=pass
ENV KEEP_ALIVE=true

# https://yaml.org/type/bool.html
ENV TRUE='y|Y|yes|Yes|YES|n|N|no|No|NO|true|True|TRUE|false|False|FALSE|on|On|ON|off|Off|OFF|1'

ENV USER="${USER:-root}"
ENV HOME="${HOME:-/root}"
ENV PATH="/opt/bin:${PATH}"

USER root
WORKDIR /tmp/downloads

COPY docs/* /docs/
COPY opt/* /opt/bin/
COPY bin/* /usr/local/bin/
COPY profile/* /etc/profile.d/

ADD dpctl/ /tmp/dpctl/

RUN mkdir -p /tmp/dpctl && \
    for f in $(ls -1 /tmp/dpctl); do install "/tmp/dpctl/${f}" "/usr/local/bin/${f}"; done && \
    rm -rf /tmp/dpctl && \
    chmod +x /opt/bin/describe

# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
RUN [ "${KUBE_VERSION:-latest}" = "latest" ] && \
        KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt) || \
        KUBE_VERSION="v$(echo ${KUBE_VERSION} | sed s/^v//g)" && \
    curl -LO "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl" && \
    curl -LO "https://dl.k8s.io/${KUBE_VERSION}/bin/linux/amd64/kubectl.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "kubectl: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    printf "Kubernetes %s\n" "$(kubectl version --short --client)" >> /.versions

# https://helm.sh/docs/intro/install/
RUN [ "${HELM_VERSION:-latest}" = "latest" ] && \
        HELM_VERSION=$(./gh-get-latest-release.sh "helm/helm") || \
        HELM_VERSION="v$(echo ${HELM_VERSION} | sed s/^v//g)" && \
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh --version ${HELM_VERSION} && \
    printf "Helm %s\n" "$(helm version --short)" >> /.versions

# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-convert-plugin
RUN [ "${KUBECTL_CONVERT_VERSION:-latest}" = "latest" ] && \
        KUBECTL_CONVERT_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt) || \
        KUBECTL_CONVERT_VERSION="v$(echo ${KUBECTL_CONVERT_VERSION} | sed s/^v//g)" && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_CONVERT_VERSION}/bin/linux/amd64/kubectl-convert" && \
    curl -L "https://dl.k8s.io/${KUBECTL_CONVERT_VERSION}/bin/linux/amd64/kubectl-convert.sha256" -o "kubectl-convert-${KUBECTL_CONVERT_VERSION}.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(echo "$(cat kubectl-convert-${KUBECTL_CONVERT_VERSION}.sha256)  kubectl-convert" | sha256sum --check) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "kubectl-convert: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install -o root -g root -m 0755 kubectl-convert /usr/local/bin/kubectl-convert

# https://kind.sigs.k8s.io/
RUN [ "${KIND_VERSION:-latest}" = "latest" ] && \
        KIND_VERSION=$(./gh-get-latest-release.sh "kubernetes-sigs/kind") || \
        KIND_VERSION="v$(echo ${KIND_VERSION} | sed s/^v//g)" && \
    curl -LO "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" && \
    curl -LO "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64.sha256sum" && \
    CHECKSUM_VERIFY_STATUS=$(cat kind-linux-amd64.sha256sum | grep --color=never kind-linux-amd64 | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "kind-linux-amd64: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install kind-linux-amd64 /usr/local/bin/kind && \
    kind --version >> /.versions

# https://github.com/doitintl/kube-no-trouble
RUN sh -c "$(curl -sSL https://git.io/install-kubent)"

# Install kubectx and kubens
# https://github.com/ahmetb/kubectx/blob/master/README.md#manual-installation-macos-and-linux
RUN [ "${KUBECTX:-latest}" = "latest" ] && \
        KUBECTX_VERSION=$(./gh-get-latest-release.sh "ahmetb/kubectx") || \
        KUBECTX_VERSION="v$(echo ${KUBECTX_VERSION} | sed s/^v//g)" && \
    curl -LO "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_linux_x86_64.tar.gz" && \
    curl -LO "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_linux_x86_64.tar.gz" && \
    curl -L "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/checksums.txt" -o "kubectx-${KUBECTX_VERSION}.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(cat kubectx-${KUBECTX_VERSION}.sha256 | grep --color=never kubectx_${KUBECTX_VERSION}_linux_x86_64.tar.gz | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "kubectx_${KUBECTX_VERSION}_linux_x86_64.tar.gz: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    tar -xvzf kubectx_${KUBECTX_VERSION}_linux_x86_64.tar.gz && \
    install kubectx /usr/local/bin/kubectx && \
    printf "kubectx: %s\n" "$(kubectx --version)" >> /.versions && \
    CHECKSUM_VERIFY_STATUS=$(cat kubectx-${KUBECTX_VERSION}.sha256 | grep --color=never kubens_${KUBECTX_VERSION}_linux_x86_64.tar.gz | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "kubens_${KUBECTX_VERSION}_linux_x86_64.tar.gz: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    tar -xvzf kubens_${KUBECTX_VERSION}_linux_x86_64.tar.gz && \
    install kubens /usr/local/bin/kubens && \
    printf "kubens: %s\n" "$(kubens --version)" >> /.versions

# curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=x86_64 sh - 
RUN [ "${ISTIO_VERSION:-latest}" = "latest" ] && \
        ISTIO_VERSION=$(./gh-get-latest-release.sh "istio/istio") || \
        ISTIO_VERSION="$(echo ${ISTIO_VERSION} | sed s/^v//g)" && \
    curl -LO "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz" && \
    curl -LO "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz.sha256" && \
    CHECKSUM_VERIFY_STATUS=$(cat istio-${ISTIO_VERSION}-linux-amd64.tar.gz.sha256 | grep --color=never istio-${ISTIO_VERSION}-linux-amd64.tar.gz | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "istio-${ISTIO_VERSION}-linux-amd64.tar.gz: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    tar -xvzf istio-${ISTIO_VERSION}-linux-amd64.tar.gz && \
    install istio-${ISTIO_VERSION}/bin/istioctl /usr/local/bin/istioctl && \
    cp istio-${ISTIO_VERSION}/tools/istioctl.bash $HOME/istioctl.bash && \
    printf "istio: %s\n" "$(istioctl version --remote=false --short)" >> /.versions

RUN [ "${TERRAFORM_VERSION:-latest}" = "latest" ] && \
        TERRAFORM_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version') || \
        TERRAFORM_VERSION="$(echo ${TERRAFORM_VERSION} | sed s/^v//g)" && \
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" && \
    CHECKSUM_VERIFY_STATUS=$(cat terraform_${TERRAFORM_VERSION}_SHA256SUMS | grep --color=never terraform_${TERRAFORM_VERSION}_linux_amd64.zip | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "terraform_${TERRAFORM_VERSION}_linux_amd64.zip: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    install terraform /usr/local/bin/terraform && \
    echo "$(echo $(terraform version))" | awk '{print $1" "$2}' >> /.versions && \
    terraform -install-autocomplete

RUN [ "${TERRAGRUNT_VERSION:-latest}" = "latest" ] && \
        TERRAGRUNT_VERSION=$(./gh-get-latest-release.sh "gruntwork-io/terragrunt") || \
        TERRAGRUNT_VERSION="v$(echo ${TERRAGRUNT_VERSION} | sed s/^v//g)" && \
    curl -LO "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" && \
    curl -L "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/SHA256SUMS" -o "terragrunt_${TERRAGRUNT_VERSION}_SHA256SUMS" && \
    CHECKSUM_VERIFY_STATUS=$(cat terragrunt_${TERRAGRUNT_VERSION}_SHA256SUMS | grep --color=never terragrunt_linux_amd64 | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "terragrunt_linux_amd64: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    install terragrunt_linux_amd64 /usr/local/bin/terragrunt && \
    terragrunt --version >> /.versions

RUN [ "${K9S_VERSION:-latest}" = "latest" ] && \
        K9S_VERSION=$(./gh-get-latest-release.sh "derailed/k9s") || \
        K9S_VERSION="v$(echo ${K9S_VERSION} | sed s/^v//g)" && \
    curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" && \
    curl -L "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.txt" -o "k9s-${K9S_VERSION}-checksums.txt" && \
    CHECKSUM_VERIFY_STATUS=$(cat "k9s-${K9S_VERSION}-checksums.txt" | grep --color=never k9s_Linux_amd64.tar.gz | sha256sum -c -) && \
    LAST_ERR=$? && \
    [ "$CHECKSUM_VERIFY_STATUS" = "k9s_Linux_amd64.tar.gz: OK" -a $LAST_ERR -eq 0 ] && printf "\033[92;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS" || { printf "\033[91;1m%s\033[0m\n" "$CHECKSUM_VERIFY_STATUS"; printf "Error %d. Exiting ...\n" $LAST_ERR >&2; exit $LAST_ERR; } && \
    tar -xvzf k9s_Linux_amd64.tar.gz k9s -C . && \
    install k9s /usr/local/bin/k9s && \
    k9s version

RUN rm -rf /tmp/downloads && \
    echo "EDITOR=\${EDITOR}" >> "${HOME}/.profile" && \
    echo "VISUAL=\${EDITOR}" >> "${HOME}/.profile" && \
    echo "GIT_EDITOR=\${EDITOR}" >> "${HOME}/.profile" && \
    echo "KUBE_EDITOR=\${EDITOR}" >> "${HOME}/.profile" && \
    echo "complete -C /usr/local/bin/aws_completer aws" >> "${HOME}/.bashrc" && \
    echo "source <(kubectl completion bash)" >> "${HOME}/.bashrc" && \
    echo "[ -f ~/istioctl.bash ] && . ~/istioctl.bash" >> "${HOME}/.bashrc" && \
    echo "init.sh" >> "${HOME}/.bashrc" && \
    echo "source ${HOME}/.platform_aliases"

USER $USER
WORKDIR $HOME

VOLUME [ "/data", "$HOME/.ssh", "$HOME/.gnupg", "$HOME/.password-store", "$HOME/.awsvault" ]

ENTRYPOINT [ "/usr/local/bin/docker-entrypoint.sh" ]

# Additional Metadata
ARG VERSION=base-latest
ARG IMAGE_NAME=
LABEL org.opencontainers.image.base.name="${IMAGE_NAME}:${VERSION}"
LABEL org.opencontainers.image.description="usage: \
   run.sh -u|--racfid <racfid> -t|--team <team_name> -n|--name <full_name> -m|--email <email> -e|--editor <editor>"
