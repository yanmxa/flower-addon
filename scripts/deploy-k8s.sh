#!/bin/bash
# Deploy Flower Federated Learning to Kubernetes (insecure mode)
#
# Prerequisites:
# - kubectl configured with target cluster
# - Docker for building custom image
#
# Usage:
#   ./scripts/deploy-k8s.sh [build|deploy|teardown]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="flower"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

build_image() {
    log_info "Building custom SuperExec image..."
    cd "$PROJECT_DIR"

    # For Minikube, use minikube's Docker daemon
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        log_info "Using Minikube's Docker daemon..."
        eval $(minikube docker-env)
    fi

    docker build -t flowerexample-superexec:latest -f docker/Dockerfile.superexec .
    log_info "Image built successfully!"
}

deploy() {
    log_info "Deploying Flower to Kubernetes (insecure mode)..."

    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    cd "$PROJECT_DIR"
    kubectl apply -k k8s/

    log_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/superlink -n "$NAMESPACE" || true
    kubectl wait --for=condition=available --timeout=300s deployment/supernode-1 -n "$NAMESPACE" || true
    kubectl wait --for=condition=available --timeout=300s deployment/supernode-2 -n "$NAMESPACE" || true

    log_info "Deployment complete!"
    log_info ""
    log_info "To access the Control API, run:"
    log_info "  kubectl port-forward svc/superlink 9093:9093 -n flower"
    log_info ""
    log_info "Then run federated learning:"
    log_info "  flwr run . k8s-deployment --stream"
}

teardown() {
    log_warn "Tearing down Flower deployment..."

    cd "$PROJECT_DIR"
    kubectl delete -k k8s/ --ignore-not-found
    kubectl delete pvc superlink-state -n "$NAMESPACE" --ignore-not-found

    log_info "Teardown complete!"
}

status() {
    log_info "Checking deployment status..."
    kubectl get all -n "$NAMESPACE"
}

case "${1:-deploy}" in
    build)
        build_image
        ;;
    deploy)
        build_image
        deploy
        ;;
    teardown)
        teardown
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 [build|deploy|teardown|status]"
        exit 1
        ;;
esac
