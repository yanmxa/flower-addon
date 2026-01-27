# Run Federated Learning Applications

This guide explains how to submit and run Flower federated learning applications on your OCM-managed federation.

## Prerequisites

- **Infrastructure deployed**: Complete [Install Flower Addon Guide](install-flower-addon.md) first
- **SuperNodes connected**: At least 2 SuperNodes connected to SuperLink
- **Python environment**: `uv` or `pip` for running the Flower CLI
- **flwr CLI**: Installed via `uv pip install flwr` or `pip install flwr`

Verify SuperNodes are connected:

```bash
kubectl logs -n flower-system -l app.kubernetes.io/component=superlink | grep "PullMessages"
```

You should see log entries like:

```
INFO :      [Fleet.PullMessages]
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Developer Machine                                          │
│  flwr run . ocm-deployment --stream                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (port 30093 - Exec API)
┌─────────────────────────────────────────────────────────────┐
│  Hub Cluster - SuperLink                                    │
│  - Receives job submission                                  │
│  - Executes ServerApp (subprocess mode)                     │
│  - Coordinates training rounds                              │
└─────────────────────────────────────────────────────────────┘
                              │ (port 30092 - Fleet API)
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│  Managed Cluster 1          │ │  Managed Cluster 2          │
│  SuperNode (partition=0)    │ │  SuperNode (partition=1)    │
│  - Executes ClientApp       │ │  - Executes ClientApp       │
│  - Local training           │ │  - Local training           │
└─────────────────────────────┘ └─────────────────────────────┘
```

**Execution Flow:**

1. Developer submits FL app via `flwr run` to SuperLink Exec API (port 30093)
2. SuperLink executes ServerApp in subprocess mode
3. SuperLink coordinates with SuperNodes via Fleet API (port 30092)
4. Each SuperNode executes ClientApp, training on its local data partition
5. ServerApp aggregates model updates using FedAvg strategy
6. Process repeats for configured number of rounds

## Running the CIFAR-10 Example

### Step 1: Set Up Python Environment

```bash
# Create virtual environment and install dependencies
uv venv && uv pip install -e .

# Or with pip
python -m venv .venv
source .venv/bin/activate
pip install -e .
```

### Step 2: Verify Infrastructure Status

```bash
make status
```

Ensure:
- SuperLink pod is Running
- ManagedClusterAddons show `AVAILABLE: True`

### Step 3: Submit the FL Application

```bash
make run-app
```

This command:
1. Detects the hub node IP automatically
2. Submits the CIFAR-10 app to SuperLink via Exec API (port 30093)
3. Streams execution logs in real-time

Expected output:

```
Submitting FL app to SuperLink at 192.168.x.x:30093...
Loading project configuration...
Success
```

### Step 4: Monitor Execution

**Terminal 1 - Watch FL app execution** (already streaming from `make run-app`)

**Terminal 2 - SuperLink logs** (ServerApp execution):

```bash
kubectl logs -n flower-system -l app.kubernetes.io/component=superlink -f
```

**Terminal 3 - SuperNode logs** (ClientApp execution):

```bash
# Cluster 1
kubectl --context kind-cluster1 logs -n open-cluster-management-agent-addon \
  -l app.kubernetes.io/component=supernode -f

# Cluster 2
kubectl --context kind-cluster2 logs -n open-cluster-management-agent-addon \
  -l app.kubernetes.io/component=supernode -f
```

## Understanding the Output

### ServerApp (SuperLink) Logs

```
INFO :      Starting Flower ServerApp
INFO :      Starting Flower simulation
INFO :      [ROUND 1]
INFO :      configure_fit: strategy sampled 2 clients
INFO :      aggregate_fit: received 2 results
INFO :      fit progress: (1, 0.4523, {'accuracy': 0.3245})
INFO :      [ROUND 2]
...
INFO :      [ROUND 3]
INFO :      fit progress: (3, 0.2134, {'accuracy': 0.5678})
```

### ClientApp (SuperNode) Logs

```
INFO :      Starting Flower ClientApp
INFO :      Partition ID: 0, Num Partitions: 2
INFO :      Loading CIFAR-10 data partition 0/2
INFO :      Training model on partition 0 for 1 epoch(s)
INFO :      Epoch 1: Loss=1.234, Accuracy=0.456
```

## Configuration Options

### Application Settings

Configured in `pyproject.toml`:

| Setting | Description | Default |
|---------|-------------|---------|
| `num-server-rounds` | Number of federated learning rounds | `3` |
| `fraction-evaluate` | Fraction of clients for evaluation | `0.5` |
| `local-epochs` | Training epochs per round per client | `1` |
| `learning-rate` | SGD learning rate | `0.1` |
| `batch-size` | Training batch size | `32` |

### Federation Settings

| Setting | Description | Default |
|---------|-------------|---------|
| `address` | SuperLink Exec API address | Auto-detected |
| `insecure` | Disable TLS (development only) | `true` |

## Make Targets

| Target | Description |
|--------|-------------|
| `run-app` | Submit FL app to OCM federation |
| `app-logs` | Show recent SuperLink logs |

## Manual Execution

If you need more control over the execution:

```bash
# Get hub node IP
HUB_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Run with custom address
flwr run . ocm-deployment --federation-config address="$HUB_IP:30093" --stream
```

## Troubleshooting

### "No SuperNodes connected"

SuperLink requires at least 2 SuperNodes to start training.

1. **Verify SuperNodes are running**:
   ```bash
   kubectl --context kind-cluster1 get pods -n open-cluster-management-agent-addon
   kubectl --context kind-cluster2 get pods -n open-cluster-management-agent-addon
   ```

2. **Check SuperNode logs for connection errors**:
   ```bash
   kubectl --context kind-cluster1 logs -n open-cluster-management-agent-addon \
     -l app.kubernetes.io/component=supernode
   ```

3. **Verify network connectivity** between SuperNodes and SuperLink port 30092.

### "Connection refused" on Port 30093

1. **Verify SuperLink service**:
   ```bash
   kubectl get svc -n flower-system superlink
   ```

2. **Check if port 30093 is accessible**:
   ```bash
   kubectl get nodes -o wide  # Get node IP
   curl -v <node-ip>:30093    # Test connectivity
   ```

### Training Not Progressing

1. **Check SuperLink logs** for errors:
   ```bash
   kubectl logs -n flower-system -l app.kubernetes.io/component=superlink --tail=100
   ```

2. **Check SuperNode logs** for training errors:
   ```bash
   kubectl --context kind-cluster1 logs -n open-cluster-management-agent-addon \
     -l app.kubernetes.io/component=supernode --tail=100
   ```

3. **Verify partition configuration**:
   ```bash
   kubectl get addondeploymentconfigs -A -o yaml | grep -A5 PARTITION
   ```

### Slow Training

The CIFAR-10 example downloads data on first run. Subsequent runs use cached data.

For faster iterations during development:
- Reduce `num-server-rounds` in `pyproject.toml`
- Reduce `local-epochs` for quicker rounds

## Next Steps

- Modify `cifar10/server_app.py` to experiment with different aggregation strategies
- Modify `cifar10/client_app.py` to customize local training
- Create custom FL applications following the same structure
