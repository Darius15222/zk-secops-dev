#!/usr/bin/env bash
# Starts the zk-lab local stack: floci (Terraform state), local registry, k3d cluster. Safe to rerun.
# Writes its own kubeconfig; ~/.kube/config (the real MicroK8s) is never touched.
set -euo pipefail

KC=${ZK_KUBECONFIG:-$HOME/.kube/config.zk-lab}

docker start floci >/dev/null 2>&1 || floci aws start --persist "$HOME/.floci/data"
floci aws wait

docker start k3d-zk-registry >/dev/null 2>&1 || k3d registry create zk-registry --port 5001

if k3d cluster get zk-lab >/dev/null 2>&1; then
  k3d cluster start zk-lab
else
  # k3s ships Traefik as the ingress controller; zk-platform uses ingressClassName traefik
  k3d cluster create zk-lab \
    --registry-use k3d-zk-registry:5001 \
    -p "443:443@loadbalancer" -p "80:80@loadbalancer" \
    --kubeconfig-update-default=false --kubeconfig-switch-context=false --wait
fi

mkdir -p "$(dirname "$KC")"
k3d kubeconfig get zk-lab >"$KC"
chmod 600 "$KC"
kubectl --kubeconfig "$KC" wait --for=condition=Ready node --all --timeout=120s >/dev/null

echo "Up. kubeconfig: $KC"
