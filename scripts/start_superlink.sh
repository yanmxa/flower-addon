#!/bin/bash
# Start the Flower SuperLink with TLS enabled
#
# SuperLink is the central coordinator in a Flower federation.
# It exposes three ports:
#   - 9091: App IO API (SuperExec <-> SuperLink communication)
#   - 9092: Fleet API (SuperNode <-> SuperLink communication)
#   - 9093: Control API (CLI <-> SuperLink communication)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$PROJECT_DIR/certificates"

# Check if certificates exist
if [ ! -f "$CERT_DIR/ca.crt" ] || [ ! -f "$CERT_DIR/server.pem" ] || [ ! -f "$CERT_DIR/server.key" ]; then
    echo "Error: TLS certificates not found in $CERT_DIR"
    echo "Please run: python generate_certs.py"
    exit 1
fi

echo "Starting Flower SuperLink with TLS..."
echo "  - CA Certificate: $CERT_DIR/ca.crt"
echo "  - Server Certificate: $CERT_DIR/server.pem"
echo "  - Server Key: $CERT_DIR/server.key"
echo ""

cd "$PROJECT_DIR"

flower-superlink \
    --ssl-ca-certfile "$CERT_DIR/ca.crt" \
    --ssl-certfile "$CERT_DIR/server.pem" \
    --ssl-keyfile "$CERT_DIR/server.key"
