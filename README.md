# Flower Addon for Open Cluster Management

Integrate [Flower Federated Learning](https://flower.ai) with [Open Cluster Management (OCM)](https://open-cluster-management.io) to enable automated distribution and orchestration of federated learning workloads across multi-cloud environments.

## Challenges

Deploying federated learning at scale across multiple clusters and edge devices presents significant operational challenges:

- **Complex Deployment**: SuperNodes must be deployed and configured on each participating cluster
- **Manual Registration**: SuperNodes need to be manually registered with the central SuperLink
- **Collaborator Scheduling**: Manually select clusters based on resources (GPU, memory), location, or data availability
- **Dynamic Membership**: Managing cluster participation as clusters join, leave, or change status
- **Application Distribution**: Distributing FL applications (ClientApp) to participating clusters

Flower Addon leverages OCM's multi-cluster management to address these challenges:

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
- [ ] Process isolation mode on OCM (ServerApp/ClientApp via Docker)
- [ ] Automatic ClientApp distribution via ManifestWorkReplicaSet
- [ ] TLS-secured SuperNode-SuperLink connections via Addon auto-registration

## Related Projects

- [Flower](https://flower.ai) - A friendly federated learning framework
- [Open Cluster Management](https://open-cluster-management.io) - Multi-cluster management for Kubernetes
