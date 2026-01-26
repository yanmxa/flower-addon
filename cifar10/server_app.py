"""Flower ServerApp for federated learning.

This module defines the server-side logic for federated learning,
including the aggregation strategy and server configuration.
"""

from flwr.common import Context, ndarrays_to_parameters
from flwr.server import ServerApp, ServerAppComponents, ServerConfig
from flwr.server.strategy import FedAvg

from cifar10.task import Net, get_weights


def server_fn(context: Context) -> ServerAppComponents:
    """Configure the server for federated learning."""
    # Get run configuration
    num_rounds = context.run_config.get("num-server-rounds", 3)
    fraction_evaluate = context.run_config.get("fraction-evaluate", 0.5)

    # Initialize model parameters
    model = Net()
    initial_parameters = ndarrays_to_parameters(get_weights(model))

    # Define the aggregation strategy
    strategy = FedAvg(
        fraction_fit=1.0,  # Sample 100% of available clients for training
        fraction_evaluate=fraction_evaluate,
        min_fit_clients=2,  # Minimum clients required for training
        min_evaluate_clients=2,  # Minimum clients required for evaluation
        min_available_clients=2,  # Minimum clients that need to be connected
        initial_parameters=initial_parameters,
    )

    # Server configuration
    config = ServerConfig(num_rounds=num_rounds)

    return ServerAppComponents(strategy=strategy, config=config)


# Create the ServerApp
app = ServerApp(server_fn=server_fn)
