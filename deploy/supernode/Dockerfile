FROM flwr/supernode:1.25.0

# Install ML dependencies directly (flwr is already installed in base image)
# PyTorch 2.6+ supports Python 3.13
RUN python -m pip install -U --no-cache-dir \
    "flwr-datasets[vision]>=0.5.0" \
    torch torchvision
