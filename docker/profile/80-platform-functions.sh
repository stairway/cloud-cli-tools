# Function to always vault exec the kubectl command
kube() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}" -- kubectl "$@"
}

# Function to use vault exec with aws command
awv() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}" -- aws "$@"
}

# Function shorthand for aws-vault exec witcurrent profile
ve() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}" -- "$@"
}

eks() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}" -- aws eks update-kubeconfig --name $@
}

# Function to switch kubernetes contexts and make sure the info for that cluster is up to date
update-kube() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}" -- aws eks update-kubeconfig --name "${CLUSTER_PREFIX}-$1-cluster"
}

# Function to read secrets from chamber
rochamber() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}" -- chamber "$@"
}

# Function to generate semantic version based on a git tag with pattern 'prefix/major.minor'
sem_version() {
    # usage: sem_version 'v/*'
    # Requires current commit or a previous commit to be tagged.
    # One way is to tag your very first commit with something like 'v/0.1'
    # Tags should be of pattern v/major.minor eg: v/3.1
    # You can use any prefix for tag: eg: 'human/3.1'. sem_version 'human/*'
    # The pattern matching is not a regex. It is glob(7). Check git describe docs.
    IFS=-
    set -- `git describe --always --tags --match "$1"`
    unset IFS
    local major_minor=$1
    local patch=$2
    local v=`basename $major_minor.${patch:-0}`
    echo $v
}

pip_login() {
    # set pip global index-url with aws codeartifact link containing auth-token at ~/.config/pip/pip.conf, or .venv/pip.conf if it exists.
    #
    # this is a workaround for this bug:
    #    $ aws codeartifact login --tool pip --domain grainger --repository pip
    #
    #    pip was not found. Please verify installation.
    local flags="$1"
    flags=${flags:=--user}
    local token=$(codeartifact_auth_token)
    local url="https://aws:${token}@grainger-709741256416.d.codeartifact.us-east-2.amazonaws.com/pypi/pip/simple/"
    pip config "$flags" set global.index-url "${url}"
}

codeartifact_auth_token() {
    aws-vault exec "${AWS_DEFAULT_PROFILE:-$DEFAULT_PROFILE}" -- aws codeartifact get-authorization-token --region us-east-2 --domain grainger --query authorizationToken --output text
}

# Function to get a token for kiali url access
kiali_login() {
    echo ""
    echo "Fetching token for Kiali login..."
    echo "Copy token printed below and paste into the kiali login dialog that will open in your broswer momentarially."
    echo "( If you have pbcopy installed then you will be able to just paste into the browser window. )"
    echo ""
    echo "KIALI TOKEN:"
    local clustername=$(k config view --minify -o jsonpath={'.contexts[]'.context.cluster} | awk -F/ '{print $2}')
    local cluster_context_with_region=$(kubectl config view --minify -o jsonpath={'.contexts[]'.context.cluster} | awk -F/ '{print $1}')
    local cluster_region=$(echo $cluster_context_with_region | awk -F: '{print $4}')
    local token=$(ve aws eks get-token --cluster-name $clustername | jq -r .status.token )
    #   check if pbcopy is installed
    which pbcopy > /dev/null 2>&1
    if [[ $? == 0 ]]; then
        # then output token to screen via stderr and to pbcopy via stdout
        echo $token | tee /dev/stderr | pbcopy
    else
        # else output token to screen via stdout
        echo $token
    fi
    local subdomain=$(echo $clustername | awk -F- '{print $2}')
    if [[ $subdomain == 'prod' ]]; then
        local url="https://sensible-drt.di-$subdomain-cluster-$cluster_region.internal.graingercloud.com/kiali"
    elif [[ $subdomain == 'services' ]]; then
        local url="https://sensible-drt.di-$subdomain-cluster.$subdomain-internal.graingercloud.com/kiali"
    elif [[ $clustername == 'di-preview-services-cluster' ]]; then
        local url="https://sensible-drt.$clustername.$subdomain-services-internal.graingercloud.com/kiali"
    else
        local url="https://sensible-drt.di-$subdomain-cluster-$cluster_region.$subdomain-internal.graingercloud.com/kiali"
    fi
    echo ""
    echo ""
    echo "Launching Kiali interface in your default browser at the following url:"
    echo $url
    open $url
}

# function to create a kubectl "virtual env" using the KUBECONFIG env var to set the current config file to something other than ~/.kube/confg
# allows for per-shell kubeclt contexts
kubenv() {
    if [ "$#" -ne 0 ]; then
        if [ "$1" == "clear" ]; then
        # quick way to "deactivate" the "virtual env" and use the default context again
            unset KUBECONFIG
        else
        # if the user specifies a location, use it. useful if you wanted 2 shells to share context. Try $TMPDIR/my-kubeconfig
            export KUBECONFIG="$1"
        fi
    else
    # defaults to a random file in the system's temp directory
        export KUBECONFIG="$(mktemp)"
    fi
}

# short for git tag and push.  Just specify the tag you want to create an push.
gtp() {
	tag=$1
	git tag $tag && git push origin $tag
}

# set a profile to use so aws-vault can automatically pick it up if it isn't already a predefined command.
aws-profile() {
    AWS_DEFAULT_PROFILE="$1"
    export AWS_DEFAULT_PROFILE
}
