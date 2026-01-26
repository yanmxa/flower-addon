"""Training and model utilities for federated learning.

This module contains:
- Net: A simple CNN for CIFAR-10 classification
- get_weights/set_weights: Functions to extract/set model parameters
- train/test: Training and evaluation functions
- load_data: Data loading with partitioning for federated learning
"""

from collections import OrderedDict
from typing import List, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from flwr_datasets import FederatedDataset
from flwr_datasets.partitioner import IidPartitioner
from torch.utils.data import DataLoader
from torchvision.transforms import Compose, Normalize, ToTensor


class Net(nn.Module):
    """Simple CNN for CIFAR-10 classification."""

    def __init__(self) -> None:
        super().__init__()
        self.conv1 = nn.Conv2d(3, 32, 3, padding=1)
        self.conv2 = nn.Conv2d(32, 64, 3, padding=1)
        self.conv3 = nn.Conv2d(64, 64, 3, padding=1)
        self.pool = nn.MaxPool2d(2, 2)
        self.fc1 = nn.Linear(64 * 4 * 4, 64)
        self.fc2 = nn.Linear(64, 10)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = self.pool(F.relu(self.conv3(x)))
        x = x.view(-1, 64 * 4 * 4)
        x = F.relu(self.fc1(x))
        x = self.fc2(x)
        return x


def get_weights(model: nn.Module) -> List[np.ndarray]:
    """Extract model weights as a list of numpy arrays."""
    return [val.cpu().detach().numpy() for val in model.state_dict().values()]


def set_weights(model: nn.Module, weights: List[np.ndarray]) -> None:
    """Set model weights from a list of numpy arrays."""
    state_dict = OrderedDict(
        {k: torch.from_numpy(np.copy(v)) for k, v in zip(model.state_dict().keys(), weights)}
    )
    model.load_state_dict(state_dict, strict=True)


fds: FederatedDataset | None = None


def load_data(
    partition_id: int,
    num_partitions: int,
    batch_size: int = 32,
) -> Tuple[DataLoader, DataLoader]:
    """Load CIFAR-10 data for a specific partition.

    Args:
        partition_id: The ID of this client's partition (0-indexed)
        num_partitions: Total number of partitions (clients)
        batch_size: Batch size for DataLoaders

    Returns:
        Tuple of (train_loader, test_loader)
    """
    global fds
    if fds is None:
        partitioner = IidPartitioner(num_partitions=num_partitions)
        fds = FederatedDataset(
            dataset="uoft-cs/cifar10",
            partitioners={"train": partitioner},
        )

    partition = fds.load_partition(partition_id)
    partition_train_test = partition.train_test_split(test_size=0.2, seed=42)

    # Define transforms
    transform = Compose([
        ToTensor(),
        Normalize((0.4914, 0.4822, 0.4465), (0.2470, 0.2435, 0.2616)),
    ])

    def apply_transforms(batch):
        """Apply transforms to a batch of examples."""
        batch["img"] = [transform(img) for img in batch["img"]]
        return batch

    partition_train_test = partition_train_test.with_transform(apply_transforms)

    train_loader = DataLoader(
        partition_train_test["train"],
        batch_size=batch_size,
        shuffle=True,
        collate_fn=collate_fn,
    )
    test_loader = DataLoader(
        partition_train_test["test"],
        batch_size=batch_size,
        shuffle=False,
        collate_fn=collate_fn,
    )

    return train_loader, test_loader


def collate_fn(batch: List[dict]) -> Tuple[torch.Tensor, torch.Tensor]:
    """Custom collate function for the DataLoader."""
    images = torch.stack([item["img"] for item in batch])
    labels = torch.tensor([item["label"] for item in batch])
    return images, labels


def train(
    model: nn.Module,
    train_loader: DataLoader,
    epochs: int = 1,
    learning_rate: float = 0.01,
    device: torch.device = torch.device("cpu"),
) -> Tuple[float, int]:
    """Train the model on the training set.

    Args:
        model: The model to train
        train_loader: DataLoader for training data
        epochs: Number of local epochs
        learning_rate: Learning rate for optimizer
        device: Device to use for training

    Returns:
        Tuple of (average loss, number of samples trained on)
    """
    model.to(device)
    model.train()

    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.SGD(
        model.parameters(),
        lr=learning_rate,
        momentum=0.9,
    )

    total_loss = 0.0
    total_samples = 0

    for _ in range(epochs):
        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device)

            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            total_loss += loss.item() * len(labels)
            total_samples += len(labels)

    avg_loss = total_loss / total_samples if total_samples > 0 else 0.0
    return avg_loss, total_samples


def test(
    model: nn.Module,
    test_loader: DataLoader,
    device: torch.device = torch.device("cpu"),
) -> Tuple[float, float, int]:
    """Evaluate the model on the test set.

    Args:
        model: The model to evaluate
        test_loader: DataLoader for test data
        device: Device to use for evaluation

    Returns:
        Tuple of (loss, accuracy, number of samples)
    """
    model.to(device)
    model.eval()

    criterion = nn.CrossEntropyLoss()
    total_loss = 0.0
    correct = 0
    total_samples = 0

    with torch.no_grad():
        for images, labels in test_loader:
            images, labels = images.to(device), labels.to(device)

            outputs = model(images)
            loss = criterion(outputs, labels)

            total_loss += loss.item() * len(labels)
            _, predicted = torch.max(outputs.data, 1)
            correct += (predicted == labels).sum().item()
            total_samples += len(labels)

    avg_loss = total_loss / total_samples if total_samples > 0 else 0.0
    accuracy = correct / total_samples if total_samples > 0 else 0.0

    return avg_loss, accuracy, total_samples
