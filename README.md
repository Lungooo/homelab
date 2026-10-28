<div align="center">

# Homelab

**GitOps-managed home infrastructure — a k3s cluster driven by Argo CD, with Ansible for everything that isn't Kubernetes.**

[![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)](https://ansible.com/)&nbsp;&nbsp;
[![Argo CD](https://img.shields.io/badge/Argo%20CD-EF7B4D?style=flat&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)&nbsp;&nbsp;
[![Forgejo](https://img.shields.io/badge/Forgejo-FB923C?style=flat&logo=forgejo&logoColor=white)](https://forgejo.org/)&nbsp;&nbsp;
[![k3s](https://gist.githubusercontent.com/Lungooo/5ec603c683d92941895ea14302c06d0f/raw/1a6a35ab08c3f8dba886dac28b1101d0b1005472/k3s.svg)](https://k3s.io/)&nbsp;&nbsp;
[![AlmaLinux](https://img.shields.io/badge/AlmaLinux-4CA30D?style=flat&logo=almalinux&logoColor=white)](https://almalinux.org/)&nbsp;&nbsp;
[![Traefik](https://img.shields.io/badge/Traefik-24A1C1?style=flat&logo=traefikproxy&logoColor=white)](https://traefik.io/)&nbsp;&nbsp;
[![Renovate](https://img.shields.io/badge/Renovate-308BE3?style=flat&logo=renovate&logoColor=white)](https://docs.renovatebot.com/)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)&nbsp;&nbsp;
[![Longhorn](https://img.shields.io/badge/Longhorn-5F224A?style=flat&logo=longhorn&logoColor=white)](https://longhorn.io/)&nbsp;&nbsp;

[![License](https://img.shields.io/github/license/lungooo/homelab?style=flat&color=red)](LICENSE)&nbsp;
[![Last commit](https://img.shields.io/github/last-commit/Lungooo/homelab?style=flat&color=red)](https://github.com/Lungooo/homelab/commits/main)

</div>

---

## Overview

This repository is the single source of truth for my homelab. Every workload on the cluster is declared here and reconciled automatically by **Argo CD**; hosts outside the cluster are configured with **Ansible**; and the S3-compatible object store on the NAS runs from a **Docker Compose** file that redeploys itself on change.

- **Declarative** — if it isn't in Git, it doesn't exist (Argo CD prunes it).
- **Self-updating** — Renovate opens PRs for new image and chart versions; minor/patch updates are merged automatically.
- **Validated** — every PR is rendered and checked against Kubernetes schemas on self-hosted GitHub Actions runners running *inside* the cluster.
- **Secure by default** — SSO via Authelia + LLDAP, CrowdSec in front of public services, and secrets pulled from Bitwarden Secrets Manager rather than committed.

## How it fits together

Argo CD uses an **app-of-apps** pattern: two root `Application`s (`apps` and `core-components`) each render a small Helm chart whose `values.yaml` lists the child applications. Adding an app means creating its directory **and** adding an entry to that `values.yaml`.

## Stack

### Cluster

| Component | Purpose |
|---|---|
| [AlmaLinux](https://almalinux.org/) + [k3s](https://k3s.io/) | 3 control-plane, 3 worker and 3 dedicated storage nodes |
| [Argo CD](https://argo-cd.readthedocs.io/) | GitOps continuous delivery |
| [Traefik](https://traefik.io/) | Two ingress controllers: internal (`*.home.lungoo.de`) and external (`*.lungoo.dev`) |
| [MetalLB](https://metallb.io/) | LoadBalancer IPs on bare metal |
| [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) | Attaching pods to additional networks |
| [cert-manager](https://cert-manager.io/) | Automatic TLS certificates |
| [Authelia](https://www.authelia.com/) + [LLDAP](https://github.com/lldap/lldap) | SSO / forward-auth backed by a lightweight LDAP directory |
| [CrowdSec](https://www.crowdsec.net/) | Collaborative intrusion prevention |
| [External Secrets](https://external-secrets.io/) | Syncs secrets from Bitwarden Secrets Manager |
| [Longhorn](https://longhorn.io/) | Replicated block storage with snapshots and backups |
| [CloudNativePG](https://cloudnative-pg.io/) | Shared PostgreSQL cluster for all apps |
| [Reloader](https://github.com/stakater/Reloader) | Rolls pods when ConfigMaps/Secrets change |
| [Reflector](https://github.com/emberstack/kubernetes-reflector) | Mirrors Secrets/ConfigMaps across namespaces |
| [kured](https://kured.dev/) | Reboots nodes one at a time after OS updates, within a nightly window |
| [Actions Runner Controller](https://github.com/actions/actions-runner-controller) | Self-hosted GitHub Actions runners for CI |

### Applications

Everything under [`kubernetes/apps/`](kubernetes/apps/) is a user-facing application (media, photos, documents, finance, chat bridges and more), each deployed as its own Argo CD `Application`.

### Outside the cluster

| Host | Managed by |
|---|---|
| [Forgejo](https://forgejo.org/) — Git server Argo CD pulls from | Ansible role `forgejo` |
| AlmaLinux automatic updates on all nodes | Ansible role `alma-auto-update` |
| [Garage](https://garagehq.deuxfleurs.fr/) S3 object storage on the Synology NAS | Docker Compose + self-updating script |

## Repository layout

```text
.
├── ansible/                 # Playbooks, roles and inventory for non-Kubernetes hosts
├── docker/
│   └── garage/              # Compose stack + auto-update script for the NAS
├── kubernetes/
│   ├── app-of-apps/         # Root Argo CD Applications and their Helm charts
│   ├── apps/                # User-facing workloads (one Kustomize dir per app)
│   └── core-components/     # Cluster infrastructure
└── .github/workflows/       # CI: manifest validation, ansible-lint, workflow lint
```

Each app directory is a Kustomize directory with one file per resource type (`deployment.yaml`, `service.yaml`, `ingress.yaml`, …). Upstream Helm charts are pulled in via Kustomize `helmCharts:`, and image versions are pinned by tag **and** digest in `kustomization.yaml` so Renovate can bump them.

## Validation

CI only checks the paths changed in a PR. To run the same checks locally:

```bash
# Render and validate a Kubernetes app
kustomize build --enable-helm kubernetes/apps/<app> | kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -skip CustomResourceDefinition,IngressRoute,IngressRouteTCP

# Lint Ansible
ansible-lint ansible/<file>

# Lint workflows
yamllint -c _yamllint.yaml .github/workflows/<file>.yaml
```

## License

Distributed under the [MIT License](LICENSE).
