alias p-sandbox='export AWS_DEFAULT_PROFILE="${TEAM_NAME}-sandbox.tf"'
alias p-preview='export AWS_DEFAULT_PROFILE="${TEAM_NAME}-preview.tf"'
alias p-nonprod='export AWS_DEFAULT_PROFILE="${TEAM_NAME}-nonprod.tf"'
alias p-prod='export AWS_DEFAULT_PROFILE="${TEAM_NAME}-prod"'
alias p-master='export AWS_DEFAULT_PROFILE=master.tf'
alias p-gamut='export AWS_DEFAULT_PROFILE=gamut'

alias k='ve kubectl $@'
alias kns='ve kubens $@'
alias stern='ve stern $@'
alias eks-preview-services='aws-vault exec "${TEAM_NAME}-preview.tf" -- aws eks update-kubeconfig --alias preview-services-cluster --name "${CLUSTER_PREFIX}-preview-services-cluster" $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-preview.tf"'
alias eks-preview='aws-vault exec "${TEAM_NAME}-preview.tf" -- aws eks update-kubeconfig --alias preview-cluster --name "${CLUSTER_PREFIX}-preview-cluster" --region us-east-2 $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-preview.tf"'
alias eks-preview-us-east-1='aws-vault exec "${TEAM_NAME}-preview.tf" -- aws eks update-kubeconfig --alias preview-cluster-us-east-1 --name "${CLUSTER_PREFIX}-preview-cluster-us-east-1" --region us-east-1 $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-preview.tf"'
alias eks-qa='aws-vault exec "${TEAM_NAME}-preview.tf" -- aws eks update-kubeconfig --alias qa-cluster --name "${CLUSTER_PREFIX}-qa-cluster" $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-preview.tf"'
alias eks-services='aws-vault exec "${TEAM_NAME}-prod" -- aws eks update-kubeconfig --alias services-cluster --name "${CLUSTER_PREFIX}-services-cluster" $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-prod"'
alias eks-sandbox='aws-vault exec "${TEAM_NAME}-sandbox.tf" -- aws eks update-kubeconfig --alias sandbox-cluster --name "${CLUSTER_PREFIX}-sandbox-cluster" $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-sandbox.tf"'
alias eks-nonprod='aws-vault exec "${TEAM_NAME}-nonprod.tf" -- aws eks update-kubeconfig --alias nonprod-cluster --name "${CLUSTER_PREFIX}-nonprod-cluster" --region us-east-1 $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-nonprod.tf"'
alias eks-nonprod-us-east-2='aws-vault exec "${TEAM_NAME}-nonprod.tf" -- aws eks update-kubeconfig --alias nonprod-cluster-us-east-2 --name "${CLUSTER_PREFIX}-nonprod-cluster-us-east-2" --region us-east-2 $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-nonprod.tf"'
alias eks-prod='aws-vault exec "${TEAM_NAME}-prod" -- aws eks update-kubeconfig --alias prod-cluster --name "${CLUSTER_PREFIX}-prod-cluster" --region us-east-1 $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-prod"'
alias eks-prod-us-east-2='aws-vault exec "${TEAM_NAME}-prod" -- aws eks update-kubeconfig --alias prod-cluster-us-east-2 --name "${CLUSTER_PREFIX}-prod-cluster-us-east-2" --region us-east-2 $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-prod"'
alias eks-breakglass='aws-vault exec "${TEAM_NAME}-breakglass" -- aws eks update-kubeconfig --alias prod-cluster --name "${CLUSTER_PREFIX}-prod-cluster" --region us-east-1 $@ && export AWS_DEFAULT_PROFILE="${TEAM_NAME}-breakglass"'
alias f='ve flux'
alias h='ve helm $@'
alias vel='ve velero $@'
alias tf='ve terraform $@'

alias kistio='k -n istio-system $@'
alias kkube='k -n kube-system $@'
alias kdog='k -n datadog $@'
alias kcore='k -n "${CLUSTER_PREFIX}-core" $@'
alias kallpods='k get pods --all-namespaces $@'
alias rochamber='AWS_DEFAULT_PROFILE=user ve chamber $@'
alias topcpu='k top pod --all-namespaces | sort --reverse --key 3 --numeric | head -20'
alias topmem='k top pod --all-namespaces | sort --reverse --key 4 --numeric | head -20'

# python
# new virtual environment
alias nvenv='python -m venv .venv && source .venv/bin/activate && pip install --upgrade pip setuptools wheel'

# watch with aliases
alias watcha='watch '

# watch kubectl
alias watchk='watch aws-vault exec $AWS_DEFAULT_PROFILE -- kubectl "$@"'
alias watchf='watch aws-vault exec $AWS_DEFAULT_PROFILE -- flux "$@"'

# vault
alias v-prod='export AWS_DEFAULT_PROFILE="${TEAM_NAME}-prod" && export VAULT_ADDR=https://vault.services.graingercloud.com'
alias v-preview='export AWS_DEFAULT_PROFILE="${TEAM_NAME}-preview" && export VAULT_ADDR=https://vault.preview-services.graingercloud.com'
alias v-qa='export AWS_DEFAULT_PROFILE="${TEAM_NAME}-preview" && export VAULT_ADDR=https://vault.qa.graingercloud.com'
alias consul-login='export CONSUL_HTTP_TOKEN=$(vault read -field token consul/creds/admin)'
alias vault-login='aws-vault exec $AWS_DEFAULT_PROFILE -- vault login -method=aws role=admin'

# unset all AWS* like env vars
alias unsetaws='unset $(env | grep -i aws | grep -v AWS_VAULT_BACKEND | sed '"'"'s/=/ /g'"'"' | awk "{print $1}" | xargs)'

alias aws-console='aws-vault login ${AWS_DEFAULT_PROFILE:-user}'
