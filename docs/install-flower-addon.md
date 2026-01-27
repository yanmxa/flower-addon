# Enable Flower Addon on OCM Managed Clusters

This guide walks you through deploying Flower federated learning infrastructure using Open Cluster Management (OCM).

## Prerequisites

- **Hub Cluster**: Kubernetes cluster with OCM installed
- **Managed Clusters**: One or more clusters registered with OCM
- **kubectl**: Configured for hub cluster access
- **make**: For running deployment commands

Verify OCM is running:

```bash
kubectl get pods -n open-cluster-management
kubectl get managedclusters
```

## Step 0: Set Up OCM Environment

Follow the [OCM Quick Start Guide](https://open-cluster-management.io/getting-started/quick-start/) to set up a hub cluster and register managed clusters.

## Architecture Overview

```
Hub Cluster                          Managed Clusters
┌─────────────────────────┐          ┌─────────────────────┐
│  SuperLink (NodePort)   │◄─────────│  SuperNode          │
│  - Fleet API: 30092     │          │  (partition-id=0)   │
│  - Exec API: 30093      │          └─────────────────────┘
└─────────────────────────┘          ┌─────────────────────┐
┌─────────────────────────┐          │  SuperNode          │
│  OCM Addon Controller   │─────────►│  (partition-id=1)   │
│  - AddOnTemplate        │          └─────────────────────┘
│  - ClusterManagementAddon│
└─────────────────────────┘
```

## Step 1: Deploy SuperLink on Hub Cluster

SuperLink is the central coordination server for federated learning.

```bash
make deploy-superlink
```

Verify deployment:

```bash
kubectl get pods -n flower-system
kubectl get svc -n flower-system
```

Expected output:

```
NAME                         READY   STATUS    RESTARTS   AGE
superlink-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

NAME        TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)
superlink   NodePort   10.96.xxx.xxx   <none>        9091:30091/TCP,9092:30092/TCP,9093:30093/TCP
```

Check SuperLink logs to verify it started correctly:

```bash
kubectl logs -n flower-system -l app.kubernetes.io/component=superlink --tail=10
```

Look for startup messages. Once SuperNodes connect, you'll see `[Fleet.PullMessages]` entries.

## Step 2: Deploy OCM Addon Resources

Deploy the OCM addon configuration (AddOnTemplate, ClusterManagementAddon, etc.):

```bash
make deploy-addon
```

Update SuperLink address with the hub node IP:

```bash
make update-superlink-address
```

Verify addon resources:

```bash
kubectl get addontemplates
kubectl get clustermanagementaddons
kubectl get addondeploymentconfigs -A
```

## Step 3: Enable Addon on Managed Clusters

Enable the flower addon on each managed cluster:

```bash
# Enable on cluster1 (partition-id=0)
make enable-addon CLUSTER=cluster1

# Enable on cluster2 (partition-id=1)
make enable-addon CLUSTER=cluster2
```

Or deploy with custom partition configuration:

```bash
make deploy-cluster-config CLUSTER=cluster1 PARTITION_ID=0 NUM_PARTITIONS=2
make deploy-cluster-config CLUSTER=cluster2 PARTITION_ID=1 NUM_PARTITIONS=2
```

Verify ManagedClusterAddons:

```bash
kubectl get managedclusteraddons -A
```

Expected output:

```
NAMESPACE   NAME           AVAILABLE   DEGRADED   PROGRESSING
cluster1    flower-addon   True                   False
cluster2    flower-addon   True                   False
```

## Step 4: Verify SuperNode Deployment

Check SuperNode pods on managed clusters:

```bash
# On cluster1
kubectl --context kind-cluster1 get pods -n open-cluster-management-agent-addon

# On cluster2
kubectl --context kind-cluster2 get pods -n open-cluster-management-agent-addon
```

View SuperNode logs to confirm connection to SuperLink:

```bash
kubectl --context kind-cluster1 logs -n open-cluster-management-agent-addon -l app.kubernetes.io/component=supernode
```

## Quick Setup (One Command)

For testing environments, deploy everything at once:

```bash
make setup-clusters
```

This command:
1. Deploys SuperLink on hub
2. Deploys OCM addon resources
3. Updates SuperLink address
4. Enables addon on cluster1 and cluster2

Check overall status:

```bash
make status
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SUPERLINK_ADDRESS` | Hub node IP address | Auto-detected |
| `SUPERLINK_PORT` | SuperLink fleet API port | `30092` |
| `IMAGE` | SuperNode container image | `flwr/supernode:1.25.0` |
| `PARTITION_ID` | Data partition ID (0-indexed) | `0` |
| `NUM_PARTITIONS` | Total number of partitions | `2` |

## Make Targets Reference

### SuperLink

| Target | Description |
|--------|-------------|
| `deploy-superlink` | Deploy SuperLink on hub cluster |
| `undeploy-superlink` | Remove SuperLink from hub cluster |

### OCM Addon

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
| `deploy-cluster-config CLUSTER=<name> PARTITION_ID=<n>` | Deploy per-cluster config |

### Convenience

| Target | Description |
|--------|-------------|
| `deploy-all` | Deploy SuperLink and addon |
| `undeploy-all` | Remove all hub components |
| `setup-clusters` | Full setup with cluster1 and cluster2 |
| `status` | Show addon status |

## Troubleshooting

### SuperNode Cannot Connect to SuperLink

1. **Check SuperLink service**:
   ```bash
   kubectl get svc -n flower-system superlink
   ```

2. **Verify SuperLink address in config**:
   ```bash
   kubectl get addondeploymentconfig -n open-cluster-management default -o yaml
   ```

3. **Check network connectivity** from managed cluster to hub node port 30092.

### Addon Not Available

1. **Check ManagedClusterAddon status**:
   ```bash
   kubectl get managedclusteraddon -n <cluster-name> flower-addon -o yaml
   ```

2. **Check addon-manager logs**:
   ```bash
   kubectl logs -n open-cluster-management -l app=addon-manager
   ```

### SuperNode Pod Not Starting

1. **Check pod events**:
   ```bash
   kubectl --context <cluster-context> describe pod -n open-cluster-management-agent-addon -l app.kubernetes.io/component=supernode
   ```

2. **Check image pull status** - ensure the cluster can pull `flwr/supernode` image.

## Cleanup

Remove addon from specific clusters:

```bash
make disable-addon CLUSTER=cluster1
make disable-addon CLUSTER=cluster2
```

Remove all components from hub:

```bash
make undeploy-all
```

## Next Steps

- Configure TLS for production deployments
- Customize SuperNode image with your ML workload
- Set up monitoring and logging
