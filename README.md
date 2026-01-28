# Flower Addon for Open Cluster Management

Integrate [Flower Federated Learning](https://flower.ai) with [Open Cluster Management (OCM)](https://open-cluster-management.io) to enable automated distribution and orchestration of federated learning workloads across multi-cloud environments.

## Why This Project?

### The Challenge

Deploying federated learning at scale across multiple clusters and edge devices presents significant operational challenges:

- **Complex Deployment**: SuperNodes must be deployed and configured on each participating cluster
- **Registration Overhead**: Manual registration of SuperNodes with the central SuperLink
- **Security Configuration**: Setting up secure TLS connections between distributed components
- **Dynamic Membership**: Managing which clusters participate based on resources, location, or data availability

### The Solution

Flower Addon leverages OCM's multi-cluster management capabilities to automate the entire federated learning infrastructure lifecycle:

- **Declarative Deployment**: Define once, deploy everywhere through OCM's addon framework
- **Automatic Registration**: SuperNodes automatically discover and register with SuperLink
- **Policy-Based Placement**: Use OCM Placement to select clusters by attributes (GPU, region, labels)
- **Dynamic Scaling**: Automatically adjust federation membership as clusters join or leave

## Features

| Capability | Description |
|------------|-------------|
| **Deployment** | Simplify [SuperNodes](https://flower.ai/docs/framework/ref-api/flwr.supernode.html) deployment to clusters/devices with [OCM Addon](https://open-cluster-management.io/concepts/addon/) |
| **Registration** | SuperNodes automatically register with [SuperLink](https://flower.ai/docs/framework/ref-api/flwr.superlink.html), establishing secure connections |
| **Scheduling** | Select target clusters/devices using [Placement](https://open-cluster-management.io/concepts/placement/) based on labels, resources, topology, or custom strategies |
| **Membership** | Dynamically adjust participating clusters based on cluster status or attributes |
| **Application Distribution** | Distribute [ClientApp](https://flower.ai/docs/framework/docker/tutorial-quickstart-docker.html) via [ManifestWorkReplicaSet](https://open-cluster-management.io/docs/concepts/work-distribution/manifestworkreplicaset/) for [process isolation mode](https://flower.ai/docs/framework/docker/tutorial-quickstart-docker.html) |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Hub Cluster                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  SuperLink (Federated Learning Coordinator)            │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  OCM Addon                                             │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│   Managed Cluster 1         │ │   Managed Cluster 2         │
│   SuperNode (auto-deployed) │ │   SuperNode (auto-deployed) │
└─────────────────────────────┘ └─────────────────────────────┘
```

## Progress

- [x] [Install Flower Addon](docs/install-flower-addon.md) - Deploy SuperLink and SuperNodes via OCM Addon
- [x] [Auto-Install with Placement](docs/auto-install-by-placement.md) - Schedule SuperNodes across clusters via OCM Placement
- [x] [Run Federated Learning Applications](docs/run-federated-app.md) - Run federated learning applications on the Flower Addon environment
- [ ] TLS-secured SuperNode-SuperLink connections via Addon auto-registration
- [ ] Process isolation mode on OCM (ServerApp/ClientApp via Docker)
- [ ] Automatic ClientApp distribution via ManifestWorkReplicaSet

## Related Projects

- [Flower](https://flower.ai) - A friendly federated learning framework
- [Open Cluster Management](https://open-cluster-management.io) - Multi-cluster management for Kubernetes
