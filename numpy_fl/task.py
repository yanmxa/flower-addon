"""NumPy-based linear regression for federated learning.

This module contains a simple linear regression model implemented
with NumPy only - no PyTorch or TensorFlow required.
"""

from typing import List, Tuple
import numpy as np


class LinearRegression:
    """Simple linear regression model using NumPy."""

    def __init__(self, n_features: int = 10) -> None:
        self.n_features = n_features
        self.weights = np.zeros(n_features)
        self.bias = 0.0

    def predict(self, X: np.ndarray) -> np.ndarray:
        """Make predictions."""
        return X @ self.weights + self.bias

    def get_parameters(self) -> List[np.ndarray]:
        """Get model parameters as list of arrays."""
        return [self.weights.copy(), np.array([self.bias])]

    def set_parameters(self, parameters: List[np.ndarray]) -> None:
        """Set model parameters from list of arrays."""
        self.weights = parameters[0].copy()
        self.bias = float(parameters[1][0])


def generate_data(
    partition_id: int,
    num_partitions: int,
    n_samples: int = 100,
    n_features: int = 10,
    noise: float = 0.1,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Generate synthetic regression data for a partition.

    Each partition gets different data based on partition_id.

    Returns:
        Tuple of (X_train, y_train, X_test, y_test)
    """
    # Use partition_id as seed for reproducible but different data
    rng = np.random.default_rng(seed=42 + partition_id)

    # True weights (same across all partitions for consistency)
    np.random.seed(42)
    true_weights = np.random.randn(n_features)
    true_bias = 2.0

    # Generate features
    X = rng.standard_normal((n_samples, n_features))

    # Generate targets with noise
    y = X @ true_weights + true_bias + rng.normal(0, noise, n_samples)

    # Split into train/test
    split_idx = int(0.8 * n_samples)
    X_train, X_test = X[:split_idx], X[split_idx:]
    y_train, y_test = y[:split_idx], y[split_idx:]

    return X_train, y_train, X_test, y_test


def train(
    model: LinearRegression,
    X: np.ndarray,
    y: np.ndarray,
    epochs: int = 10,
    learning_rate: float = 0.01,
) -> Tuple[float, int]:
    """Train the model using gradient descent.

    Returns:
        Tuple of (final_loss, num_samples)
    """
    n_samples = len(y)

    for _ in range(epochs):
        # Forward pass
        predictions = model.predict(X)

        # Compute gradients
        error = predictions - y
        grad_weights = (2 / n_samples) * (X.T @ error)
        grad_bias = (2 / n_samples) * np.sum(error)

        # Update parameters
        model.weights -= learning_rate * grad_weights
        model.bias -= learning_rate * grad_bias

    # Final loss (MSE)
    final_predictions = model.predict(X)
    loss = np.mean((final_predictions - y) ** 2)

    return float(loss), n_samples


def evaluate(
    model: LinearRegression,
    X: np.ndarray,
    y: np.ndarray,
) -> Tuple[float, float, int]:
    """Evaluate the model.

    Returns:
        Tuple of (mse_loss, r2_score, num_samples)
    """
    predictions = model.predict(X)

    # MSE
    mse = np.mean((predictions - y) ** 2)

    # R² score
    ss_res = np.sum((y - predictions) ** 2)
    ss_tot = np.sum((y - np.mean(y)) ** 2)
    r2 = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0.0

    return float(mse), float(r2), len(y)
