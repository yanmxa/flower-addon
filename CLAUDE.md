# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kubernetes addon integrating [Flower Federated Learning](https://flower.ai) with [Open Cluster Management (OCM)](https://open-cluster-management.io). Automates deployment and orchestration of federated learning workloads across multi-cluster Kubernetes environments.

**Core Components:**
- **SuperLink**: Central FL coordinator deployed on hub cluster (ports 9091-9093, NodePort 30091-30093)
- **SuperNode**: Client agents auto-deployed to managed clusters via OCM addon
- **OCM AddOnTemplate**: Declarative template enabling consistent SuperNode deployment across clusters

## Commands

### Quick Setup
```bash
make setup-clusters          # Deploy everything + configure cluster1/cluster2
make status                  # Show deployment status across all components
```

### SuperLink (Hub)
```bash
make deploy-superlink        # Deploy SuperLink on hub cluster
make undeploy-superlink      # Remove SuperLink
```

### OCM Addon
```bash
make deploy-addon            # Deploy AddOnTemplate and ClusterManagementAddOn
make update-superlink-address # Update SuperLink IP in AddOnDeploymentConfig
make undeploy-addon          # Remove addon resources
```

### Cluster Management
```bash
make enable-addon CLUSTER=cluster1                    # Enable addon on cluster
make disable-addon CLUSTER=cluster1                   # Disable addon on cluster
make deploy-cluster-config CLUSTER=cluster1 PARTITION_ID=0 NUM_PARTITIONS=2
```

### Auto-Install (Placement-based)
```bash
make deploy-auto-gpu         # Auto-install on clusters with gpu=true label
make deploy-auto-all         # Auto-install on all clusters in global ClusterSet
make label-gpu-cluster CLUSTER=cluster1  # Label cluster for GPU placement
```

### Python/Flower
```bash
uv venv && uv pip install -e .   # Create venv and install dependencies
.venv/bin/flwr run               # Run federated learning app locally
```

## Architecture

```
Hub Cluster                           Managed Clusters
├── flower-system namespace           ├── open-cluster-management-agent-addon ns
│   └── SuperLink deployment          │   └── SuperNode deployment
├── open-cluster-management ns        │       (auto-created by OCM addon)
│   ├── AddOnTemplate                 │
│   ├── ClusterManagementAddOn        │
│   └── AddOnDeploymentConfig         │
└── Placement (for auto-install)      │
```

**Data Flow:**
1. OCM addon-manager watches ClusterManagementAddOn
2. For each target cluster, renders AddOnTemplate with variables (SUPERLINK_ADDRESS, PARTITION_ID, etc.)
3. SuperNode deployed to managed cluster, connects to SuperLink
4. Flower orchestrates federated learning across SuperNodes

## Project Structure

```
deploy/
├── superlink/              # Hub SuperLink deployment (Kustomize)
├── addon-template/         # OCM addon definitions
│   ├── addon-template.yaml      # SuperNode manifest template
│   ├── clustermanagementaddon.yaml
│   └── addon-deployment-config.yaml
└── addon/
    ├── install/            # Manual per-cluster configs (cluster1, cluster2)
    └── auto-install/       # Placement-based configs (gpu-clusters, all-clusters)

cifar10/                    # Example FL application (CIFAR-10 image classification)
├── server_app.py           # FedAvg strategy, aggregation logic
├── client_app.py           # FlowerClient, training on local partition
└── task.py                 # CNN model, data loading, train/test functions
```

## Key Configuration Variables

AddOnDeploymentConfig customizedVariables (templated into SuperNode deployment):
- `SUPERLINK_ADDRESS`: Hub node IP for SuperLink connection
- `SUPERLINK_PORT`: NodePort for SuperLink (default: 30092)
- `IMAGE`: SuperNode container image (default: flwr/supernode:1.25.0)
- `PARTITION_ID`: Data partition index for this cluster
- `NUM_PARTITIONS`: Total number of data partitions

## Debugging

```bash
# SuperLink logs (hub)
kubectl logs -n flower-system deployment/superlink

# SuperNode logs (managed cluster)
kubectl logs -n open-cluster-management-agent-addon -l app=flower-supernode

# Addon status
kubectl get managedclusteraddons -A
kubectl get addondeploymentconfigs -A

# Placement decisions (auto-install)
kubectl get placementdecisions -n open-cluster-management
```

## Current Limitations

- Uses `--insecure` flag (no TLS) - production TLS is on roadmap
- Subprocess isolation mode only - process mode (custom app images) planned
- IID data partitioning in example - real deployments need custom partitioning strategy
