# Flower Addon for Open Cluster Management

A Flower Federated Learning addon for OCM (Open Cluster Management) that deploys SuperNode agents on managed clusters to connect to a central SuperLink server.

> **Note**: This uses insecure mode for simplicity. For production, enable TLS.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Hub Cluster                             │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  flower-system namespace (deploy/superlink/)          │   │
│  │  ┌─────────────────┐   ┌───────────────────────────┐ │   │
│  │  │ SuperLink       │   │ Service (NodePort)        │ │   │
│  │  │ flwr/superlink  │◄──│ 30091/30092/30093         │ │   │
│  │  └─────────────────┘   └───────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  open-cluster-management namespace (deploy/addon/)    │   │
│  │  ┌─────────────────────┐  ┌────────────────────────┐ │   │
│  │  │ ClusterManagement   │  │ AddOnTemplate          │ │   │
│  │  │ AddOn               │  │ (SuperNode manifests)  │ │   │
│  │  └─────────────────────┘  └────────────────────────┘ │   │
│  │  ┌─────────────────────┐  ┌────────────────────────┐ │   │
│  │  │ AddOnDeployment     │  │ Placement              │ │   │
│  │  │ Config (default)    │  │                        │ │   │
│  │  └─────────────────────┘  └────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│   Managed Cluster 1         │ │   Managed Cluster 2         │
│   (examples/cluster1/)      │ │   (examples/cluster2/)      │
│  ┌───────────────────────┐  │ │  ┌───────────────────────┐  │
│  │ flower-addon ns       │  │ │  │ flower-addon ns       │  │
│  │ ┌───────────────────┐ │  │ │  │ ┌───────────────────┐ │  │
│  │ │ SuperNode         │ │  │ │  │ │ SuperNode         │ │  │
│  │ │ partition-id=0    │ │  │ │  │ │ partition-id=1    │ │  │
│  │ └───────────────────┘ │  │ │  │ └───────────────────┘ │  │
│  └───────────────────────┘  │ │  └───────────────────────┘  │
└─────────────────────────────┘ └─────────────────────────────┘
```

## Project Structure

```
flower-addon/
├── deploy/
│   ├── superlink/                 # SuperLink deployment (hub cluster)
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   │
│   └── addon/                     # OCM Addon resources
│       ├── kustomization.yaml
│       ├── addon-template.yaml    # AddOnTemplate (core)
│       ├── addon-deployment-config.yaml
│       ├── placement.yaml
│       └── clustermanagementaddon.yaml
│
├── examples/                      # Per-cluster configurations
│   ├── cluster1/
│   │   ├── kustomization.yaml
│   │   ├── managedclusteraddon.yaml
│   │   └── addondeploymentconfig.yaml
│   └── cluster2/
│       ├── kustomization.yaml
│       ├── managedclusteraddon.yaml
│       └── addondeploymentconfig.yaml
│
├── cifar10/                       # CIFAR-10 FL example (CNN + FedAvg)
│   ├── __init__.py
│   ├── client_app.py              # ClientApp implementation
│   ├── server_app.py              # ServerApp with FedAvg strategy
│   └── task.py                    # CNN model, training, data loading
│
├── Makefile
├── pyproject.toml
└── README.md
```

## Prerequisites

- Kubernetes cluster with OCM installed
- `kubectl` configured for hub cluster access
- Python 3.11+ (for local development)

## Quick Start

### 1. Deploy SuperLink (Hub Cluster)

```bash
# Deploy SuperLink
make deploy-superlink

# Verify
kubectl get pods -n flower-system
kubectl get svc -n flower-system
```

### 2. Deploy OCM Addon Resources

```bash
# Deploy addon resources
make deploy-addon

# Update SuperLink address with hub node IP
make update-superlink-address

# Verify
kubectl get addontemplates
kubectl get clustermanagementaddons
kubectl get addondeploymentconfigs -A
```

### 3. Enable Addon on Managed Clusters

```bash
# Enable on cluster1
make enable-addon CLUSTER=cluster1

# Enable on cluster2
make enable-addon CLUSTER=cluster2

# Verify
kubectl get managedclusteraddons -A
```

### One-Step Setup (for testing)

```bash
# Deploy everything and configure cluster1 + cluster2
make setup-clusters

# Check status
make status
```

## Make Targets

### SuperLink Deployment

| Target | Description |
|--------|-------------|
| `deploy-superlink` | Deploy SuperLink on hub cluster |
| `undeploy-superlink` | Remove SuperLink from hub cluster |

### OCM Addon Deployment

| Target | Description |
|--------|-------------|
| `deploy-addon` | Deploy OCM addon resources |
| `undeploy-addon` | Remove OCM addon resources |
| `update-superlink-address` | Update SuperLink address with hub node IP |

### Cluster Configuration

| Target | Description |
|--------|-------------|
| `enable-addon CLUSTER=<name>` | Enable addon on a cluster |
| `disable-addon CLUSTER=<name>` | Disable addon on a cluster |
| `deploy-cluster-config CLUSTER=<name> PARTITION_ID=<n> NUM_PARTITIONS=<total>` | Deploy per-cluster config |

### Quick Setup

| Target | Description |
|--------|-------------|
| `deploy-all` | Deploy SuperLink and addon (one-step) |
| `undeploy-all` | Remove all hub components |
| `setup-clusters` | Full setup with cluster1 and cluster2 |

### Status

| Target | Description |
|--------|-------------|
| `status` | Show addon status |
| `help` | Display all available targets |

## Configuration Variables

The AddOnTemplate uses these variables from AddOnDeploymentConfig:

| Variable | Description | Default |
|----------|-------------|---------|
| `SUPERLINK_ADDRESS` | Hub node IP address | `<HUB_NODE_IP>` |
| `SUPERLINK_PORT` | SuperLink fleet API port | `30092` |
| `IMAGE` | SuperNode container image | `flwr/supernode:1.25.0` |
| `PARTITION_ID` | Data partition ID (0-indexed) | `0` |
| `NUM_PARTITIONS` | Total number of partitions | `2` |

## Verification

### Check SuperNode Connection

```bash
# View SuperNode logs on managed cluster
kubectl --context kind-cluster1 logs -n flower-addon -l app.kubernetes.io/component=supernode

# Should see connection to SuperLink
```

### Check All Components

```bash
make status
```

## Local Development

For local Flower development without Kubernetes:

```bash
# Create virtual environment
uv venv .venv --seed

# Install dependencies
.venv/bin/pip install -e .

# Run locally (see pyproject.toml for configuration)
flwr run . local-deployment --stream
```

## Model

Simple CNN for CIFAR-10 image classification:
- 3 convolutional layers (32 → 64 → 64 channels)
- Max pooling after each conv layer
- 2 fully connected layers (1024 → 64 → 10)
- FedAvg aggregation strategy
