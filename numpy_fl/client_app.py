"""Flower ClientApp for NumPy-based federated learning."""

from flwr.client import ClientApp, NumPyClient
from flwr.common import Context

from numpy_fl.task import LinearRegression, evaluate, generate_data, train


class FlowerClient(NumPyClient):
    """Flower client for linear regression."""

    def __init__(
        self,
        X_train,
        y_train,
        X_test,
        y_test,
        n_features: int,
        local_epochs: int,
        learning_rate: float,
    ) -> None:
        self.X_train = X_train
        self.y_train = y_train
        self.X_test = X_test
        self.y_test = y_test
        self.model = LinearRegression(n_features=n_features)
        self.local_epochs = local_epochs
        self.learning_rate = learning_rate

    def get_parameters(self, config):
        """Return the current local model parameters."""
        return self.model.get_parameters()

    def fit(self, parameters, config):
        """Train the model on the local dataset."""
        self.model.set_parameters(parameters)

        loss, num_samples = train(
            self.model,
            self.X_train,
            self.y_train,
            epochs=self.local_epochs,
            learning_rate=self.learning_rate,
        )

        return self.model.get_parameters(), num_samples, {"train_loss": loss}

    def evaluate(self, parameters, config):
        """Evaluate the model on the local test dataset."""
        self.model.set_parameters(parameters)

        loss, r2, num_samples = evaluate(
            self.model,
            self.X_test,
            self.y_test,
        )

        return loss, num_samples, {"r2_score": r2}


def client_fn(context: Context):
    """Create a Flower client for the given context."""
    # Get node configuration
    partition_id = context.node_config["partition-id"]
    num_partitions = context.node_config["num-partitions"]

    # Get run configuration
    n_features = context.run_config.get("n-features", 10)
    n_samples = context.run_config.get("n-samples", 100)
    local_epochs = context.run_config.get("local-epochs", 10)
    learning_rate = context.run_config.get("learning-rate", 0.01)

    # Generate data for this partition
    X_train, y_train, X_test, y_test = generate_data(
        partition_id=partition_id,
        num_partitions=num_partitions,
        n_samples=n_samples,
        n_features=n_features,
    )

    return FlowerClient(
        X_train=X_train,
        y_train=y_train,
        X_test=X_test,
        y_test=y_test,
        n_features=n_features,
        local_epochs=local_epochs,
        learning_rate=learning_rate,
    ).to_client()


# Create the ClientApp
app = ClientApp(client_fn=client_fn)
