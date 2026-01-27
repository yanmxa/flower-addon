# Automatic SuperNode Deployment with Placement

Use OCM Placement to automatically deploy the Flower addon to managed clusters that match specific criteria.

## Prerequisites

- Hub cluster with OCM installed
- SuperLink deployed on hub (`make deploy-superlink`)
- Addon template deployed (`make deploy-addon`)
- Managed clusters registered with OCM

## How It Works

OCM's Placement API enables automatic addon deployment based on cluster selection:

1. **Placement** defines which clusters should receive the addon (by labels, cluster sets, etc.)
2. **ClusterManagementAddOn** references the Placement with `installStrategy.type: Placements`
3. **OCM addon-manager** automatically creates ManagedClusterAddOn resources on matching clusters
4. **SuperNode** pods are deployed to selected clusters without manual intervention

## Scenario 1: Deploy to All Managed Clusters

Deploy the Flower addon to all clusters in the `global` cluster set.

```bash
# Deploy auto-install configuration for all clusters
make deploy-auto-all
```

This applies:
- Placement selecting all clusters in the `global` cluster set
- ManagedClusterSetBinding for the `global` cluster set
- Patches ClusterManagementAddOn to use Placements mode

Verify automatic deployment:

```bash
kubectl get managedclusteraddons -A -l addon.open-cluster-management.io/name=flower-addon
```

## Scenario 2: Deploy to GPU Clusters Only

Deploy the Flower addon only to clusters labeled with `gpu=true`.

### Step 1: Apply GPU Auto-Install Configuration

```bash
make deploy-auto-gpu
```

### Step 2: Label Target Clusters

```bash
# Label clusters that have GPU resources
make label-gpu-cluster CLUSTER=cluster1
make label-gpu-cluster CLUSTER=cluster2
```

Or manually:

```bash
kubectl label managedcluster cluster1 gpu=true --overwrite
```

### Step 3: Verify Automatic Deployment

When a cluster is labeled, OCM automatically:
1. Updates the PlacementDecision to include the cluster
2. Creates a ManagedClusterAddOn in the cluster's namespace
3. Deploys the SuperNode pod to the cluster

```bash
# Check placement decisions
kubectl get placementdecisions -n open-cluster-management

# Check auto-created ManagedClusterAddOns
kubectl get managedclusteraddons -A

# Verify ManagedClusterAddOn is available
kubectl get managedclusteraddon -n cluster1 flower-addon
```

Expected output:
```
NAME           AVAILABLE   DEGRADED   PROGRESSING
flower-addon   True                   False
```

### Step 4: Verify SuperNode Pod Running

Check that the SuperNode pod is running on the managed cluster:

```bash
# Check pod status (use the managed cluster context)
kubectl get pods -n open-cluster-management-agent-addon --context kind-cluster1

# Verify pod is ready
kubectl get pods -n open-cluster-management-agent-addon --context kind-cluster1 -o wide
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
flower-supernode-xxxxxxxxx-xxxxx   1/1     Running   0          5m
```

Check SuperNode logs to ensure it connected to SuperLink:

```bash
kubectl logs -n open-cluster-management-agent-addon -l app=flower-supernode --context kind-cluster1
```

Look for connection messages indicating successful SuperLink connection.

### Removing a Cluster from Auto-Install

Remove the label to automatically undeploy:

```bash
kubectl label managedcluster cluster1 gpu-
```

The ManagedClusterAddOn and SuperNode pod will be automatically removed.

## Switching Between Manual and Auto-Install

### From Manual to Auto-Install

```bash
# Apply auto-install configuration (patches ClusterManagementAddOn)
make deploy-auto-gpu
# or
make deploy-auto-all
```

### From Auto-Install to Manual

Revert ClusterManagementAddOn to Manual mode:

```bash
kubectl patch clustermanagementaddon flower-addon --type=merge -p '{"spec":{"installStrategy":{"type":"Manual"}}}'
```

Or re-apply the base addon template:

```bash
make deploy-addon
```

## Advanced: Custom Placement Criteria

Create your own Placement for specific requirements:

```yaml
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: flower-addon-custom-placement
  namespace: open-cluster-management
spec:
  predicates:
    - requiredClusterSelector:
        labelSelector:
          matchExpressions:
            # Clusters with GPU and in production
            - key: gpu
              operator: In
              values: ["true"]
            - key: environment
              operator: In
              values: ["production"]
        claimSelector:
          matchExpressions:
            # Clusters with at least 4 CPUs
            - key: platform.open-cluster-management.io/os
              operator: In
              values: ["linux"]
  numberOfClusters: 5  # Optional: limit to 5 clusters
```

Then update ClusterManagementAddOn to reference your custom Placement.

## Troubleshooting

### Addon Not Being Deployed Automatically

1. **Check Placement decisions**:
   ```bash
   kubectl get placementdecisions -n open-cluster-management -o yaml
   ```

2. **Verify cluster labels**:
   ```bash
   kubectl get managedclusters --show-labels
   ```

3. **Check ManagedClusterSetBinding**:
   ```bash
   kubectl get managedclustersetbindings -n open-cluster-management
   ```

4. **Check addon-manager logs**:
   ```bash
   kubectl logs -n open-cluster-management -l app=addon-manager
   ```

### Cluster Not Selected by Placement

Ensure the cluster:
- Has the required labels (for label-based selection)
- Is in the correct ManagedClusterSet
- Is in a healthy/available state

```bash
kubectl get managedcluster <cluster-name> -o yaml
```

## Cleanup

Remove auto-install configuration:

```bash
# Remove GPU auto-install
kubectl delete -k deploy/addon/auto-install/gpu-clusters/

# Remove all-clusters auto-install
kubectl delete -k deploy/addon/auto-install/all-clusters/
```

This reverts ClusterManagementAddOn to Manual mode and removes the Placement resources. Existing ManagedClusterAddOns will remain until manually deleted.
