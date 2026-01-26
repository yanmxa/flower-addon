# Flower Addon for Open Cluster Management

Deploy Flower federated learning (SuperLink + SuperNode) across OCM managed clusters.

> **Note**: Uses insecure mode for simplicity. Enable TLS for production.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Hub Cluster                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  SuperLink (flower-system)      NodePort: 30091-30093  │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  OCM Addon (open-cluster-management)                   │ │
│  │  AddOnTemplate → ClusterManagementAddon → Placement    │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│   Managed Cluster 1         │ │   Managed Cluster 2         │
│   SuperNode (partition=0)   │ │   SuperNode (partition=1)   │
└─────────────────────────────┘ └─────────────────────────────┘
```

## Quick Start

```bash
# One-step setup: deploy SuperLink, addon, and enable on cluster1/cluster2
make setup-clusters

# Check status
make status
```

### Step-by-Step

```bash
# 1. Deploy SuperLink on hub
make deploy-superlink

# 2. Deploy OCM addon resources
make deploy-addon
make update-superlink-address

# 3. Enable addon on managed clusters
make enable-addon CLUSTER=cluster1
make enable-addon CLUSTER=cluster2
```

## Documentation

- [Install Flower Addon Guide](docs/install-flower-addon.md) - Manual installation, configuration, and troubleshooting
- [Auto-Install with Placement](docs/auto-install-by-placement.md) - Automatic deployment using OCM Placement (GPU clusters, all clusters)

## Local Development

```bash
uv venv .venv --seed
.venv/bin/pip install -e .
flwr run . local-deployment --stream
```
