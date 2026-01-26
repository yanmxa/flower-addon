#!/bin/bash
# Script to generate Flower CA and SuperLink TLS certificates
# Usage: ./generate-certs.sh [output-dir]

set -e

OUTPUT_DIR="${1:-./certificates}"
mkdir -p "$OUTPUT_DIR"

echo "Generating Flower CA and TLS certificates in $OUTPUT_DIR"

# Generate CA key and certificate
openssl genrsa -out "$OUTPUT_DIR/ca.key" 4096
openssl req -x509 -new -nodes -key "$OUTPUT_DIR/ca.key" -sha256 -days 3650 \
  -out "$OUTPUT_DIR/ca.crt" \
  -subj "/C=US/ST=CA/L=San Francisco/O=Flower/OU=FL/CN=Flower CA"

# Generate SuperLink server key
openssl genrsa -out "$OUTPUT_DIR/server.key" 4096

# Create server certificate config
cat > "$OUTPUT_DIR/server.cnf" << EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = CA
L = San Francisco
O = Flower
OU = FL
CN = superlink

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = superlink
DNS.2 = superlink.flower-system
DNS.3 = superlink.flower-system.svc
DNS.4 = superlink.flower-system.svc.cluster.local
DNS.5 = localhost
IP.1 = 127.0.0.1
EOF

# Generate CSR and sign server certificate
openssl req -new -key "$OUTPUT_DIR/server.key" -out "$OUTPUT_DIR/server.csr" -config "$OUTPUT_DIR/server.cnf"
openssl x509 -req -in "$OUTPUT_DIR/server.csr" -CA "$OUTPUT_DIR/ca.crt" -CAkey "$OUTPUT_DIR/ca.key" \
  -CAcreateserial -out "$OUTPUT_DIR/server.crt" -days 365 -sha256 \
  -extfile "$OUTPUT_DIR/server.cnf" -extensions req_ext

# Cleanup CSR and config
rm -f "$OUTPUT_DIR/server.csr" "$OUTPUT_DIR/server.cnf" "$OUTPUT_DIR/ca.srl"

echo "Certificates generated successfully!"
echo ""
echo "Files created:"
echo "  - $OUTPUT_DIR/ca.key      (CA private key - keep secure!)"
echo "  - $OUTPUT_DIR/ca.crt      (CA certificate - distribute to clients)"
echo "  - $OUTPUT_DIR/server.key  (SuperLink private key)"
echo "  - $OUTPUT_DIR/server.crt  (SuperLink certificate)"
echo ""
echo "To create Kubernetes secrets:"
echo ""
echo "# CA signing secret for addon manager (in open-cluster-management namespace)"
echo "kubectl create secret tls flower-ca-signing-secret \\"
echo "  --cert=$OUTPUT_DIR/ca.crt \\"
echo "  --key=$OUTPUT_DIR/ca.key \\"
echo "  -n open-cluster-management"
echo ""
echo "# SuperLink TLS secret (in flower-system namespace)"
echo "kubectl create secret generic superlink-tls \\"
echo "  --from-file=ca.crt=$OUTPUT_DIR/ca.crt \\"
echo "  --from-file=tls.crt=$OUTPUT_DIR/server.crt \\"
echo "  --from-file=tls.key=$OUTPUT_DIR/server.key \\"
echo "  -n flower-system"
