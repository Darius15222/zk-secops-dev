#!/usr/bin/env bash
# Stops the zk-lab cluster and registry without losing data. floci keeps running (other projects may use it).
# Full reset: k3d cluster delete zk-lab
set -euo pipefail

k3d cluster stop zk-lab
docker stop k3d-zk-registry >/dev/null
echo "Down. Data kept; up.sh resumes."
