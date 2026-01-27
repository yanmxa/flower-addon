FROM flwr/superlink:1.25.0

# Install ML dependencies directly (flwr is already installed in base image)
RUN python -m pip install -U --no-cache-dir \
    "flwr-datasets[vision]>=0.5.0" \
    "torch>=2.0.0" \
    "torchvision>=0.15.0"
