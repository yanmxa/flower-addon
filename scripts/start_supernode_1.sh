#!/bin/bash
# Start Flower SuperNode 1 with TLS
#
# SuperNode connects to the SuperLink and runs ClientApps.
# This node is configured with partition-id=0.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$PROJECT_DIR/certificates"

# Check if CA certificate exists
if [ ! -f "$CERT_DIR/ca.crt" ]; then
    echo "Error: CA certificate not found at $CERT_DIR/ca.crt"
    echo "Please run: python generate_certs.py"
    exit 1
fi

echo "Starting Flower SuperNode 1..."
echo "  - Partition ID: 0"
echo "  - Num Partitions: 2"
echo "  - ClientApp IO API: 0.0.0.0:9094"
echo "  - SuperLink: 127.0.0.1:9092"
echo ""

cd "$PROJECT_DIR"

flower-supernode \
    --root-certificates "$CERT_DIR/ca.crt" \
    --superlink "127.0.0.1:9092" \
    --clientappio-api-address "0.0.0.0:9094" \
    --node-config "partition-id=0 num-partitions=2"
