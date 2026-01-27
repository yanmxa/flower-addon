"""Flower ServerApp for NumPy-based federated learning."""

from flwr.common import Context, ndarrays_to_parameters
from flwr.server import ServerApp, ServerAppComponents, ServerConfig
from flwr.server.strategy import FedAvg

from numpy_fl.task import LinearRegression


def server_fn(context: Context) -> ServerAppComponents:
    """Configure the server for federated learning."""
    # Get run configuration
    num_rounds = context.run_config.get("num-server-rounds", 3)
    fraction_evaluate = context.run_config.get("fraction-evaluate", 0.5)
    n_features = context.run_config.get("n-features", 10)

    # Initialize model parameters
    model = LinearRegression(n_features=n_features)
    initial_parameters = ndarrays_to_parameters(model.get_parameters())

    # Define the aggregation strategy
    strategy = FedAvg(
        fraction_fit=1.0,
        fraction_evaluate=fraction_evaluate,
        min_fit_clients=2,
        min_evaluate_clients=2,
        min_available_clients=2,
        initial_parameters=initial_parameters,
    )

    # Server configuration
    config = ServerConfig(num_rounds=num_rounds)

    return ServerAppComponents(strategy=strategy, config=config)


# Create the ServerApp
app = ServerApp(server_fn=server_fn)
