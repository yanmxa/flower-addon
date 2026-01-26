#!/bin/bash
# Start the Flower SuperLink (insecure mode for development)
#
# SuperLink is the central coordinator in a Flower federation.
# It exposes three ports:
#   - 9091: App IO API (SuperExec <-> SuperLink communication)
#   - 9092: Fleet API (SuperNode <-> SuperLink communication)
#   - 9093: Control API (CLI <-> SuperLink communication)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Starting Flower SuperLink (insecure mode)..."
echo "  - App IO API: 0.0.0.0:9091"
echo "  - Fleet API: 0.0.0.0:9092"
echo "  - Control API: 0.0.0.0:9093"
echo ""

cd "$PROJECT_DIR"

flower-superlink --insecure
