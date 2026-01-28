# Auto-Install with Placement

This guide configures automatic addon deployment using OCM Placement API.

**How it works:**
- **Placement** selects clusters by labels (e.g., `gpu=true`) or cluster sets
- **ClusterManagementAddOn** uses `installStrategy: Placements` mode
- OCM automatically creates/removes ManagedClusterAddOn when clusters match/unmatch

This is an alternative to manual `make enable-addon` per cluster.

## Deploy to GPU Clusters

```bash
# Deploy with GPU placement
make deploy-auto-gpu

# Label clusters
kubectl label managedcluster cluster1 gpu=true
kubectl label managedcluster cluster2 gpu=true
```

Verify:

```bash
kubectl get placementdecisions -n open-cluster-management
kubectl get managedclusteraddons -A
```

## Deploy to All Clusters

```bash
make deploy-auto-all
```

## Remove from Auto-Install

Remove label to automatically undeploy:

```bash
kubectl label managedcluster cluster1 gpu-
```

## Switch Back to Manual Mode

```bash
make deploy
```
