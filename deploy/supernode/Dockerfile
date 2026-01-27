FROM flwr/supernode:1.25.0

# Copy pyproject.toml and install dependencies
COPY pyproject.toml .

# Remove flwr dependency (already installed) and install other deps
RUN sed -i 's/.*flwr.*//' pyproject.toml && \
    python -m pip install -U --no-cache-dir .
