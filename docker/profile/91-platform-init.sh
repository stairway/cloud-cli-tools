# Connect to Tailscale if not already logged in
if ! tailscale status > /dev/null; then
  printf "\n%s\n" "Connecting Tailscale VPN (sign in via Liatrio Google SSO)"
  tailscale up --accept-routes
fi

if ! command -v kpv3-cli ; then
  # Set up platform config if not already done
  source <($HOME/.kpv3-cli/bin/kpv3-cli source)
  if ! [ -s $HOME/.kube/k8s-platform-v3 ]; then
    printf "\n%s\n\n" "Configuring Kubernetes (sign in via Liatrio GitHub)"
    kpv3-cli --headless kubeconfig -w
  fi
  if [ -s $HOME/.kube/k8s-platform-v3 ]; then
    printf "\n🏁 %s 🏁\n" "Platform setup complete"
    printf "• %s\n" "Run 'k9s' (or 'kubectl' etc.) to interact with platform resources."
    printf "\n🎉 %s 🎉\n" "Happy Platforming"
  fi
fi
