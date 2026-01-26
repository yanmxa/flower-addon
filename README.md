# Flower Federated Learning Example

A minimal Flower federated learning example with local deployment.

> **Note**: This uses insecure mode for simplicity. For production, enable TLS.

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

## Quick Start

### 1. Setup Environment

```bash
# Create virtual environment
uv venv .venv --seed

# Install dependencies
.venv/bin/pip install -e .
```

### 2. Run Federated Learning

Open 4 terminals:

```bash
# Terminal 1: Start SuperLink
./scripts/start_superlink.sh

# Terminal 2: Start SuperNode 1
./scripts/start_supernode_1.sh

# Terminal 3: Start SuperNode 2
./scripts/start_supernode_2.sh

# Terminal 4: Run federated learning
source .venv/bin/activate
flwr run . local-deployment --stream
```

## Project Structure

```
flower-addon/
├── pyproject.toml              # Project configuration
├── flowerexample/              # Python package
│   ├── __init__.py
│   ├── client_app.py           # ClientApp implementation
│   ├── server_app.py           # ServerApp implementation
│   └── task.py                 # Model, training, data loading
└── scripts/
    ├── start_superlink.sh      # Start SuperLink
    ├── start_supernode_1.sh    # Start SuperNode 1
    └── start_supernode_2.sh    # Start SuperNode 2
```

## Configuration

### Training Parameters

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
