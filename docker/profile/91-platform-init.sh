# Connect to Tailscale if not already logged in
if ! tailscale status > /dev/null; then
  printf "\n%s\n" "Connecting Tailscale VPN (sign in via Liatrio Google SSO)"
  tailscale up --accept-routes
fi

if ! command -v kpv3-cli ; then
  # Set up platform config if not already done
  source <(/root/.kpv3-cli/bin/kpv3-cli source)
  if ! [ -s /root/.kube/k8s-platform-v3 ]; then
    printf "\n%s\n\n" "Configuring Kubernetes (sign in via Liatrio GitHub)"
    kpv3-cli --headless kubeconfig -w

    printf "\n ^=^o^a %s  ^=^o^a\n" "Platform setup complete"
    printf " ^`  %s" "Run 'k9s' (or 'kubectl' etc.) to interact with platform resources."
    printf " ^`  %s" "Platform git repository is available in '/workspaces'.  You may wish to add it to your Workspace."
    printf " ^`  %s" "Commit/Push are enabled for both your app's repo and the Platform repo."
    printf "\n ^=^n^i %s  ^=^n^i\n" "Happy Platforming"
  fi
fi
