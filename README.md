# Flower Federated Learning Deployment

A complete Flower federated learning setup with TLS encryption, supporting three deployment modes:
- **Local**: Direct process deployment for development/testing
- **Docker**: Containerized deployment with Docker Compose
- **Kubernetes**: Production-ready K8s deployment

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Federation                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    SuperLink                         │   │
│  │  - Port 9091: App IO API (SuperExec ↔ SuperLink)    │   │
│  │  - Port 9092: Fleet API (SuperNode ↔ SuperLink)     │   │
│  │  - Port 9093: Control API (CLI ↔ SuperLink)         │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                  │
│           ┌───────────────┴───────────────┐                 │
│           ▼                               ▼                 │
│  ┌─────────────────┐             ┌─────────────────┐       │
│  │   SuperNode 1    │             │   SuperNode 2    │       │
│  │  Port 9094       │             │  Port 9095       │       │
│  │  → ClientApp     │             │  → ClientApp     │       │
│  └─────────────────┘             └─────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Python 3.11+
- [uv](https://github.com/astral-sh/uv) (recommended) or pip
- Docker (for container deployment)
- kubectl + Minikube/Kind (for K8s deployment)

## Quick Start

### 1. Setup Environment

```bash
# Create virtual environment
uv venv .venv --seed

# Install dependencies
.venv/bin/pip install -e .

# Generate TLS certificates
.venv/bin/python generate_certs.py
```

### 2. Local Deployment (Phase 1)

Run in 3 separate terminals:

```bash
# Terminal 1: Start SuperLink
./scripts/start_superlink.sh

# Terminal 2: Start SuperNode 1
./scripts/start_supernode_1.sh

# Terminal 3: Start SuperNode 2
./scripts/start_supernode_2.sh
```

Then run federated learning:

```bash
# https://flower.ai/docs/framework/how-to-run-flower-with-deployment-engine.html
.venv/bin/flwr run . local-deployment --stream
```

### 3. Docker Deployment (Phase 2)

```bash
# Start all containers
docker compose -f docker/compose.yml up --build -d

# Check logs
docker compose -f docker/compose.yml logs -f

# Run federated learning (from host with remote-deployment config)
.venv/bin/flwr run . remote-deployment --stream

# Teardown
docker compose -f docker/compose.yml down -v
```

### 4. Kubernetes Deployment (Phase 3)

```bash
# Deploy to Kubernetes (builds image + deploys)
./scripts/deploy-k8s.sh deploy

# Check status
./scripts/deploy-k8s.sh status

# Port-forward to access Control API
kubectl port-forward svc/superlink 9093:9093 -n flower

# Run federated learning
.venv/bin/flwr run . k8s-deployment --stream

# Teardown
./scripts/deploy-k8s.sh teardown
```

## Project Structure

```
flower-addon/
├── pyproject.toml              # Project configuration
├── generate_certs.py           # TLS certificate generation
├── flowerexample/              # Python package
│   ├── __init__.py
│   ├── client_app.py           # ClientApp implementation
│   ├── server_app.py           # ServerApp implementation
│   └── task.py                 # Model, training, data loading
├── certificates/               # Generated TLS certificates
│   ├── ca.crt                  # CA certificate
│   ├── ca.key                  # CA private key
│   ├── server.pem              # Server certificate
│   └── server.key              # Server private key
├── scripts/
│   ├── start_superlink.sh      # Local SuperLink startup
│   ├── start_supernode_1.sh    # Local SuperNode 1 startup
│   ├── start_supernode_2.sh    # Local SuperNode 2 startup
│   └── deploy-k8s.sh           # Kubernetes deployment script
├── docker/
│   ├── compose.yml             # Docker Compose configuration
│   └── Dockerfile.superexec    # Custom SuperExec image
└── k8s/
    ├── namespace.yaml
    ├── kustomization.yaml
    ├── superlink/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── supernode/
    │   ├── deployment-1.yaml
    │   ├── deployment-2.yaml
    │   └── service.yaml
    └── superexec/
        ├── serverapp-deployment.yaml
        └── clientapp-deployments.yaml
```

## Configuration

### Federation Targets

Defined in `pyproject.toml`:

| Federation | Address | Description |
|------------|---------|-------------|
| `local-deployment` | 127.0.0.1:9093 | Local processes |
| `remote-deployment` | cloud-vm:9093 | Remote Docker |
| `k8s-deployment` | 127.0.0.1:9093 | K8s (via port-forward) |

### Training Configuration

```toml
[tool.flwr.app.config]
num-server-rounds = 3      # Number of FL rounds
fraction-evaluate = 0.5    # Fraction of clients for evaluation
local-epochs = 1           # Local training epochs per round
learning-rate = 0.1        # SGD learning rate
batch-size = 32            # Training batch size
```

## Model

Simple CNN for CIFAR-10 image classification:
- 3 convolutional layers (32 → 64 → 64 channels)
- Max pooling after each conv layer
- 2 fully connected layers (1024 → 64 → 10)
- FedAvg aggregation strategy

## TLS Certificates

Certificates are generated with the following SANs:
- `localhost`
- `superlink` (Docker/K8s service name)
- `superlink.flower.svc.cluster.local` (K8s FQDN)
- `127.0.0.1`
- `::1`

Valid for 365 days. Regenerate when expired:
```bash
rm -rf certificates/*
.venv/bin/python generate_certs.py
```

## Troubleshooting

### Connection refused
- Ensure SuperLink is running and healthy
- Check TLS certificates are valid and accessible
- Verify port mappings in Docker/K8s

### Certificate errors
- Regenerate certificates: `python generate_certs.py`
- Ensure CA cert path matches in client configuration

### K8s pods not starting
- Check logs: `kubectl logs -n flower <pod-name>`
- Verify TLS secret exists: `kubectl get secret -n flower`
- Check image availability: `kubectl describe pod -n flower <pod-name>`
