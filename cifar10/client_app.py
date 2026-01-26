"""Flower ClientApp for federated learning.

This module defines the client-side logic for federated learning,
including fit (training) and evaluate (testing) methods.
"""

import torch
from flwr.client import ClientApp, NumPyClient
from flwr.common import Context

from cifar10.task import Net, get_weights, load_data, set_weights, test, train


class FlowerClient(NumPyClient):
    """Flower client for CIFAR-10 classification."""

    def __init__(
        self,
        train_loader,
        test_loader,
        local_epochs: int,
        learning_rate: float,
    ) -> None:
        self.train_loader = train_loader
        self.test_loader = test_loader
        self.local_epochs = local_epochs
        self.learning_rate = learning_rate
        self.model = Net()
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    def get_parameters(self, config):
        """Return the current local model parameters."""
        return get_weights(self.model)

    def fit(self, parameters, config):
        """Train the model on the local dataset."""
        set_weights(self.model, parameters)

        loss, num_samples = train(
            self.model,
            self.train_loader,
            epochs=self.local_epochs,
            learning_rate=self.learning_rate,
            device=self.device,
        )

        return get_weights(self.model), num_samples, {"train_loss": loss}

    def evaluate(self, parameters, config):
        """Evaluate the model on the local test dataset."""
        set_weights(self.model, parameters)

        loss, accuracy, num_samples = test(
            self.model,
            self.test_loader,
            device=self.device,
        )

        return loss, num_samples, {"accuracy": accuracy}


def client_fn(context: Context):
    """Create a Flower client for the given context."""
    # Get node configuration
    partition_id = context.node_config["partition-id"]
    num_partitions = context.node_config["num-partitions"]

    # Get run configuration
    batch_size = context.run_config.get("batch-size", 32)
    local_epochs = context.run_config.get("local-epochs", 1)
    learning_rate = context.run_config.get("learning-rate", 0.01)

    # Load data for this partition
    train_loader, test_loader = load_data(
        partition_id=partition_id,
        num_partitions=num_partitions,
        batch_size=batch_size,
    )

    return FlowerClient(
        train_loader=train_loader,
        test_loader=test_loader,
        local_epochs=local_epochs,
        learning_rate=learning_rate,
    ).to_client()


# Create the ClientApp
app = ClientApp(client_fn=client_fn)
