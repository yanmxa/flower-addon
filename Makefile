# Image configuration
IMAGE_REGISTRY ?= quay.io
IMAGE_REPO ?= $(IMAGE_REGISTRY)/yanmxa
IMAGE_NAME ?= flower-addon-manager
IMAGE_TAG ?= latest
IMAGE ?= $(IMAGE_REPO)/$(IMAGE_NAME):$(IMAGE_TAG)

# Go configuration
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

# Kubernetes configuration
KUBECTL ?= kubectl
NAMESPACE ?= open-cluster-management

.PHONY: all
all: build

##@ Development

.PHONY: fmt
fmt: ## Run go fmt against code
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code
	go vet ./...

.PHONY: lint
lint: ## Run golangci-lint
	golangci-lint run ./...

.PHONY: test
test: ## Run tests
	go test ./... -coverprofile cover.out

##@ Build

.PHONY: build
build: fmt vet ## Build the binary
	go build -o bin/flower-addon-manager ./cmd/manager

.PHONY: run
run: fmt vet ## Run the addon manager locally
	go run ./cmd/manager

.PHONY: docker-build
docker-build: ## Build Docker image
	docker build -t $(IMAGE) .

.PHONY: docker-push
docker-push: ## Push Docker image
	docker push $(IMAGE)

.PHONY: docker-build-push
docker-build-push: docker-build docker-push ## Build and push Docker image

##@ Certificate Management

.PHONY: generate-certs
generate-certs: ## Generate TLS certificates
	./scripts/generate-certs.sh ./certificates

.PHONY: create-cert-secrets
create-cert-secrets: ## Create certificate secrets in Kubernetes
	@echo "Creating namespace flower-system if not exists..."
	-$(KUBECTL) create namespace flower-system
	@echo "Creating CA signing secret..."
	$(KUBECTL) create secret tls flower-ca-signing-secret \
		--cert=./certificates/ca.crt \
		--key=./certificates/ca.key \
		-n $(NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	@echo "Creating SuperLink TLS secret..."
	$(KUBECTL) create secret generic superlink-tls \
		--from-file=ca.crt=./certificates/ca.crt \
		--from-file=tls.crt=./certificates/server.crt \
		--from-file=tls.key=./certificates/server.key \
		-n flower-system --dry-run=client -o yaml | $(KUBECTL) apply -f -

##@ Deployment

.PHONY: deploy-hub
deploy-hub: ## Deploy hub components (SuperLink, ClusterManagementAddOn)
	$(KUBECTL) apply -f manifests/hub/namespace.yaml
	$(KUBECTL) apply -f manifests/hub/clustermanagementaddon.yaml
	$(KUBECTL) apply -f manifests/hub/addon-deployment-config.yaml
	$(KUBECTL) apply -f manifests/hub/superlink-deployment.yaml
	$(KUBECTL) apply -f manifests/hub/superlink-service.yaml

.PHONY: undeploy-hub
undeploy-hub: ## Remove hub components
	-$(KUBECTL) delete -f manifests/hub/superlink-service.yaml
	-$(KUBECTL) delete -f manifests/hub/superlink-deployment.yaml
	-$(KUBECTL) delete -f manifests/hub/addon-deployment-config.yaml
	-$(KUBECTL) delete -f manifests/hub/clustermanagementaddon.yaml
	-$(KUBECTL) delete -f manifests/hub/namespace.yaml

.PHONY: deploy-manager
deploy-manager: ## Deploy the addon manager
	$(KUBECTL) apply -f manifests/manager/

.PHONY: undeploy-manager
undeploy-manager: ## Remove the addon manager
	-$(KUBECTL) delete -f manifests/manager/

.PHONY: enable-addon
enable-addon: ## Enable addon on a cluster (usage: make enable-addon CLUSTER=cluster1)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make enable-addon CLUSTER=cluster1)
endif
	@echo "Enabling flower-addon on cluster $(CLUSTER)..."
	@echo 'apiVersion: addon.open-cluster-management.io/v1alpha1\nkind: ManagedClusterAddOn\nmetadata:\n  name: flower-addon\n  namespace: $(CLUSTER)\nspec:\n  installNamespace: flower-addon' | $(KUBECTL) apply -f -

.PHONY: disable-addon
disable-addon: ## Disable addon on a cluster (usage: make disable-addon CLUSTER=cluster1)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make disable-addon CLUSTER=cluster1)
endif
	$(KUBECTL) delete managedclusteraddon flower-addon -n $(CLUSTER) --ignore-not-found

##@ Help

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
