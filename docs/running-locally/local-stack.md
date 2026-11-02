# Run The Lab Locally

## Purpose

One machine runs the whole lab: a k3d cluster with Elasticsearch and Kibana (ECK), TLS from a lab CA (cert-manager), and Terraform state in floci. Nothing here touches `~/.kube/config`.

## Topology

| Component | Where | Notes |
|---|---|---|
| floci `:4566` | Docker on the host | S3 bucket `zk-tfstate` holds Terraform state; shared with other projects, never stopped by `down.sh` |
| `k3d-zk-registry` `:5001` | Docker on the host | local images for the cluster |
| k3d cluster `zk-lab` | Docker, ports 80/443 | Traefik ingress (built into k3s); kubeconfig `~/.kube/config.zk-lab` |
| cert-manager | ns `cert-manager` | `zk-lab Root CA` -> ClusterIssuer `zk-ca` |
| ECK operator | ns `elastic-system` | manages Elasticsearch and Kibana |
| Elasticsearch, Kibana 9.5.0 | ns `siem` | single node: health `yellow` is expected |
| Elastic Agent (DaemonSet) | ns `siem` | zk-auth pod logs (ECS) -> `logs-zkauth-default`; Suricata `eve.json` -> Logstash |
| Logstash | ns `siem` | runs `zk-detections/pipelines/suricata.conf` -> `logs-suricata-default` |
| Suricata (DaemonSet) | ns `ids` | sniffs `cni0` (pod bridge) with `zk-detections/rules/suricata/local.rules` |
| zk-auth | ns `zk-auth` | signed GHCR image pinned by digest, `https://auth.zk.local` |

`zk-platform` reads pipelines and rules from the sibling checkout `repos/zk-detections`: pull it before `make up`.

## Data Flow

```
client --TLS--> Traefik --HTTP (cni0)--> zk-auth --stdout ECS--> /var/log/pods --> Elastic Agent --> Elasticsearch
                                 \--> Suricata (eve.json) --> Elastic Agent --> Logstash (ECS) --> Elasticsearch --> Kibana
```

Inside k3d, client IPs are rewritten by the service load balancer: `source.ip` in zk-auth events is the bridge gateway (`10.42.0.1`), and Suricata sees Traefik as the source.

## Prerequisites

docker, k3d, floci, terraform, kubectl, sops, age (key in `~/.config/sops/age/keys.txt`), aws CLI.

One-time host setup:

1. `/etc/hosts`: `127.0.0.1 kibana.zk.local auth.zk.local`
2. Trust the lab CA in the browser. Export it: `kubectl --kubeconfig ~/.kube/config.zk-lab -n cert-manager get secret zk-root-ca -o jsonpath='{.data.ca\.crt}' | base64 -d > zk-root-ca.crt`, then import it in the browser certificate settings (Firefox: Settings > Certificates > Authorities > Import). Remove it when the course ends.

## Start And Stop

All from `repos/zk-platform`:

| Command | Does |
|---|---|
| `make init` | Creates the state bucket and runs `terraform init` (once) |
| `make up` | Starts floci, registry and cluster, then `terraform apply` on `envs/local` |
| `make down` | Stops cluster and registry; data is kept |
| `make plan` | Shows drift without changing anything |
| `make detections` | Loads the Sigma rules from `repos/zk-detections` into Elastic Security (also run by `make up`) |
| `make show-password` | Prints the `zk-admin` Kibana password (humans only; the assistant is blocked from `sops -d`) |

Kibana: `https://kibana.zk.local`, user `zk-admin`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `make up` fails on the S3 backend | floci is not running: `floci aws start --persist ~/.floci/data` |
| Elasticsearch `yellow` | Normal on one node (replicas have nowhere to go) |
| Browser certificate warning | The lab CA is not imported, or `/etc/hosts` is missing the entry |
| Port 443 already in use | Another cluster (for example `nerds-qa`) is running; stop it first |
