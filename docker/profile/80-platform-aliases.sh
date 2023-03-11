alias p-sandbox='export AWS_DEFAULT_PROFILE=di-sandbox.tf'
alias p-preview='export AWS_DEFAULT_PROFILE=di-preview.tf'
alias p-nonprod='export AWS_DEFAULT_PROFILE=di-nonprod.tf'
alias p-prod='export AWS_DEFAULT_PROFILE=di-prod'
alias p-master='export AWS_DEFAULT_PROFILE=master.tf'
alias p-gamut='export AWS_DEFAULT_PROFILE=gamut'

alias k='ve kubectl $@'
alias kns='ve kubens $@'
alias stern='ve stern $@'
alias eks-preview-services='aws-vault exec di-preview.tf -- aws eks update-kubeconfig --alias preview-services-cluster --name di-preview-services-cluster $@ && export AWS_DEFAULT_PROFILE=di-preview.tf'
alias eks-preview='aws-vault exec di-preview.tf -- aws eks update-kubeconfig --alias preview-cluster --name di-preview-cluster --region us-east-2 $@ && export AWS_DEFAULT_PROFILE=di-preview.tf'
alias eks-preview-us-east-1='aws-vault exec di-preview.tf -- aws eks update-kubeconfig --alias preview-cluster-us-east-1 --name di-preview-cluster-us-east-1 --region us-east-1 $@ && export AWS_DEFAULT_PROFILE=di-preview.tf'
alias eks-qa='aws-vault exec di-preview.tf -- aws eks update-kubeconfig --alias qa-cluster --name di-qa-cluster $@ && export AWS_DEFAULT_PROFILE=di-preview.tf'
alias eks-services='aws-vault exec di-prod -- aws eks update-kubeconfig --alias services-cluster --name di-services-cluster $@ && export AWS_DEFAULT_PROFILE=di-prod'
alias eks-sandbox='aws-vault exec di-sandbox.tf -- aws eks update-kubeconfig --alias sandbox-cluster --name di-sandbox-cluster $@ && export AWS_DEFAULT_PROFILE=di-sandbox.tf'
alias eks-nonprod='aws-vault exec di-nonprod.tf -- aws eks update-kubeconfig --alias nonprod-cluster --name di-nonprod-cluster --region us-east-1 $@ && export AWS_DEFAULT_PROFILE=di-nonprod.tf'
alias eks-nonprod-us-east-2='aws-vault exec di-nonprod.tf -- aws eks update-kubeconfig --alias nonprod-cluster-us-east-2 --name di-nonprod-cluster-us-east-2 --region us-east-2 $@ && export AWS_DEFAULT_PROFILE=di-nonprod.tf'
alias eks-prod='aws-vault exec di-prod -- aws eks update-kubeconfig --alias prod-cluster --name di-prod-cluster --region us-east-1 $@ && export AWS_DEFAULT_PROFILE=di-prod'
alias eks-prod-us-east-2='aws-vault exec di-prod -- aws eks update-kubeconfig --alias prod-cluster-us-east-2 --name di-prod-cluster-us-east-2 --region us-east-2 $@ && export AWS_DEFAULT_PROFILE=di-prod'
alias eks-breakglass='aws-vault exec di-breakglass -- aws eks update-kubeconfig --alias prod-cluster --name di-prod-cluster --region us-east-1 $@ && export AWS_DEFAULT_PROFILE=di-breakglass'
alias f='ve flux'
alias h='ve helm $@'
alias vel='ve velero $@'
alias tf='ve terraform $@'

alias kistio='k -n istio-system $@'
alias kkube='k -n kube-system $@'
alias kdog='k -n datadog $@'
alias kcore='k -n di-core $@'
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
alias v-prod='export AWS_DEFAULT_PROFILE=di-prod && export VAULT_ADDR=https://vault.services.graingercloud.com'
alias v-preview='export AWS_DEFAULT_PROFILE=di-preview && export VAULT_ADDR=https://vault.preview-services.graingercloud.com'
alias v-qa='export AWS_DEFAULT_PROFILE=di-preview && export VAULT_ADDR=https://vault.qa.graingercloud.com'
alias consul-login='export CONSUL_HTTP_TOKEN=$(vault read -field token consul/creds/admin)'
alias vault-login='aws-vault exec $AWS_DEFAULT_PROFILE -- vault login -method=aws role=admin'

# unset all AWS* like env vars
alias unsetaws='unset $(env | grep -i aws | sed '"'"'s/=/ /g'"'"' | awk "{print $1}" | xargs)'

alias aws-console='aws-vault login ${AWS_DEFAULT_PROFILE:-user}'
