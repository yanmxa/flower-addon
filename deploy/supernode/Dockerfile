FROM python:3.11-slim

# Install flwr and ML dependencies
RUN python -m pip install -U --no-cache-dir \
    "flwr>=1.25.0" \
    "flwr-datasets[vision]>=0.5.0" \
    torch torchvision

# Set entrypoint to flower-supernode
ENTRYPOINT ["flower-supernode"]
