# Kubernetes configuration
KUBECTL ?= kubectl
NAMESPACE ?= open-cluster-management

# Image configuration
FLOWER_VERSION ?= 1.25.0
IMAGE_REGISTRY ?= localhost:5000
SUPERLINK_IMAGE ?= $(IMAGE_REGISTRY)/flower-superlink:$(FLOWER_VERSION)
SUPERNODE_IMAGE ?= $(IMAGE_REGISTRY)/flower-supernode:$(FLOWER_VERSION)

.PHONY: all
all: help

##@ Image Build

.PHONY: build-images
build-images: ## Build custom SuperLink and SuperNode images with ML dependencies
	@echo "Building custom SuperLink image..."
	cp pyproject.toml deploy/superlink/
	docker build -t $(SUPERLINK_IMAGE) deploy/superlink/
	rm deploy/superlink/pyproject.toml
	@echo ""
	@echo "Building custom SuperNode image..."
	cp pyproject.toml deploy/supernode/
	docker build -t $(SUPERNODE_IMAGE) deploy/supernode/
	rm deploy/supernode/pyproject.toml
	@echo ""
	@echo "Images built successfully!"
	@echo "  - $(SUPERLINK_IMAGE)"
	@echo "  - $(SUPERNODE_IMAGE)"

.PHONY: push-images
push-images: ## Push custom images to registry
	docker push $(SUPERLINK_IMAGE)
	docker push $(SUPERNODE_IMAGE)

.PHONY: load-images-kind
load-images-kind: ## Load images into kind clusters
	kind load docker-image $(SUPERLINK_IMAGE) --name hub
	kind load docker-image $(SUPERNODE_IMAGE) --name cluster1
	kind load docker-image $(SUPERNODE_IMAGE) --name cluster2

##@ SuperLink Deployment

.PHONY: deploy-superlink
deploy-superlink: ## Deploy SuperLink on hub cluster
	@echo "Deploying SuperLink..."
	$(KUBECTL) apply -k deploy/superlink/
	@echo ""
	@echo "SuperLink deployment complete!"
	@echo "Waiting for SuperLink to be ready..."
	$(KUBECTL) wait --for=condition=available --timeout=120s deployment/superlink -n flower-system || true

.PHONY: undeploy-superlink
undeploy-superlink: ## Remove SuperLink from hub cluster
	$(KUBECTL) delete -k deploy/superlink/ --ignore-not-found

##@ OCM Addon Deployment

.PHONY: deploy-addon
deploy-addon: ## Deploy OCM addon template resources (AddOnTemplate, ClusterManagementAddOn in Manual mode)
	@echo "Deploying OCM addon template resources..."
	$(KUBECTL) apply -k deploy/addon-template/
	@echo ""
	@echo "Addon template deployment complete!"
	@echo "Next: Update SuperLink address with: make update-superlink-address"

.PHONY: undeploy-addon
undeploy-addon: ## Remove OCM addon template resources
	$(KUBECTL) delete -k deploy/addon-template/ --ignore-not-found

.PHONY: update-superlink-address
update-superlink-address: ## Update SuperLink address with hub node IP
	@HUB_IP=$$($(KUBECTL) get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'); \
	echo "Hub Node IP: $$HUB_IP"; \
	$(KUBECTL) patch addondeploymentconfig flower-addon-config -n $(NAMESPACE) \
		--type=json -p='[{"op":"replace","path":"/spec/customizedVariables/0/value","value":"'"$$HUB_IP"'"}]'

##@ Cluster Configuration

.PHONY: enable-addon
enable-addon: ## Enable addon on a cluster (usage: make enable-addon CLUSTER=cluster1)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make enable-addon CLUSTER=cluster1)
endif
	@echo "Enabling flower-addon on cluster $(CLUSTER)..."
	$(KUBECTL) apply -k deploy/addon/install/$(CLUSTER)/

.PHONY: disable-addon
disable-addon: ## Disable addon on a cluster (usage: make disable-addon CLUSTER=cluster1)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make disable-addon CLUSTER=cluster1)
endif
	$(KUBECTL) delete -k deploy/addon/install/$(CLUSTER)/ --ignore-not-found

##@ Auto-Install (Placement-based)

.PHONY: deploy-auto-gpu
deploy-auto-gpu: ## Deploy auto-install for GPU clusters (clusters with gpu=true label)
	@echo "Deploying auto-install configuration for GPU clusters..."
	$(KUBECTL) apply -k deploy/addon/auto-install/gpu-clusters/
	@echo ""
	@echo "GPU auto-install deployed!"
	@echo "Label clusters with: make label-gpu-cluster CLUSTER=<cluster-name>"

.PHONY: deploy-auto-all
deploy-auto-all: ## Deploy auto-install for all clusters (global cluster set)
	@echo "Deploying auto-install configuration for all clusters..."
	$(KUBECTL) apply -k deploy/addon/auto-install/all-clusters/
	@echo ""
	@echo "All-clusters auto-install deployed!"

.PHONY: undeploy-auto-gpu
undeploy-auto-gpu: ## Remove GPU auto-install configuration
	$(KUBECTL) delete -k deploy/addon/auto-install/gpu-clusters/ --ignore-not-found

.PHONY: undeploy-auto-all
undeploy-auto-all: ## Remove all-clusters auto-install configuration
	$(KUBECTL) delete -k deploy/addon/auto-install/all-clusters/ --ignore-not-found

.PHONY: label-gpu-cluster
label-gpu-cluster: ## Label a cluster for GPU auto-install (usage: make label-gpu-cluster CLUSTER=cluster1)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make label-gpu-cluster CLUSTER=cluster1)
endif
	$(KUBECTL) label managedcluster $(CLUSTER) gpu=true --overwrite
	@echo "Cluster $(CLUSTER) labeled with gpu=true"

.PHONY: deploy-cluster-config
deploy-cluster-config: ## Deploy per-cluster config (usage: make deploy-cluster-config CLUSTER=cluster1 PARTITION_ID=0 NUM_PARTITIONS=2)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make deploy-cluster-config CLUSTER=cluster1 PARTITION_ID=0 NUM_PARTITIONS=2)
endif
ifndef PARTITION_ID
	$(error PARTITION_ID is not set. Usage: make deploy-cluster-config CLUSTER=cluster1 PARTITION_ID=0 NUM_PARTITIONS=2)
endif
ifndef NUM_PARTITIONS
	$(error NUM_PARTITIONS is not set. Usage: make deploy-cluster-config CLUSTER=cluster1 PARTITION_ID=0 NUM_PARTITIONS=2)
endif
	@HUB_IP=$$($(KUBECTL) get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'); \
	echo "Creating AddOnDeploymentConfig for $(CLUSTER) with partition $(PARTITION_ID)/$(NUM_PARTITIONS)..."; \
	echo "apiVersion: addon.open-cluster-management.io/v1alpha1" | \
	{ cat; echo "kind: AddOnDeploymentConfig"; } | \
	{ cat; echo "metadata:"; } | \
	{ cat; echo "  name: flower-addon-config"; } | \
	{ cat; echo "  namespace: $(CLUSTER)"; } | \
	{ cat; echo "spec:"; } | \
	{ cat; echo "  customizedVariables:"; } | \
	{ cat; echo "    - name: SUPERLINK_ADDRESS"; } | \
	{ cat; echo "      value: \"$$HUB_IP\""; } | \
	{ cat; echo "    - name: SUPERLINK_PORT"; } | \
	{ cat; echo "      value: \"30092\""; } | \
	{ cat; echo "    - name: IMAGE"; } | \
	{ cat; echo "      value: \"$(SUPERNODE_IMAGE)\""; } | \
	{ cat; echo "    - name: PARTITION_ID"; } | \
	{ cat; echo "      value: \"$(PARTITION_ID)\""; } | \
	{ cat; echo "    - name: NUM_PARTITIONS"; } | \
	{ cat; echo "      value: \"$(NUM_PARTITIONS)\""; } | \
	$(KUBECTL) apply -f -

##@ Quick Setup

.PHONY: deploy-all
deploy-all: deploy-superlink deploy-addon update-superlink-address ## Deploy SuperLink and addon (one-step setup)
	@echo ""
	@echo "All hub components deployed!"
	@echo "Enable addon on clusters with: make enable-addon CLUSTER=<cluster-name>"

.PHONY: undeploy-all
undeploy-all: undeploy-addon undeploy-superlink ## Remove all hub components
	@echo "All hub components removed."

.PHONY: setup-clusters
setup-clusters: deploy-all ## Deploy hub and configure example clusters (cluster1, cluster2)
	@echo "Setting up cluster1 (partition 0)..."
	$(MAKE) deploy-cluster-config CLUSTER=cluster1 PARTITION_ID=0 NUM_PARTITIONS=2
	$(MAKE) enable-addon CLUSTER=cluster1
	@echo "Setting up cluster2 (partition 1)..."
	$(MAKE) deploy-cluster-config CLUSTER=cluster2 PARTITION_ID=1 NUM_PARTITIONS=2
	$(MAKE) enable-addon CLUSTER=cluster2
	@echo ""
	@echo "Setup complete! Check addon status with: make status"

##@ Federated Learning

.PHONY: run-app
run-app: ## Run federated learning app on OCM federation
	@HUB_IP=$$($(KUBECTL) get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'); \
	echo "Submitting FL app to SuperLink at $$HUB_IP:30093..."; \
	flwr run . ocm-deployment --federation-config address="$$HUB_IP:30093" --stream

.PHONY: app-logs
app-logs: ## Show FL infrastructure logs
	@echo "=== SuperLink Logs ==="
	@$(KUBECTL) logs -n flower-system -l app.kubernetes.io/component=superlink --tail=30

##@ Status

.PHONY: status
status: ## Show addon status
	@echo "=== SuperLink Status ==="
	$(KUBECTL) get pods -n flower-system
	@echo ""
	@echo "=== AddOnTemplate ==="
	$(KUBECTL) get addontemplates
	@echo ""
	@echo "=== ClusterManagementAddOn ==="
	$(KUBECTL) get clustermanagementaddons
	@echo ""
	@echo "=== AddOnDeploymentConfigs ==="
	$(KUBECTL) get addondeploymentconfigs -A
	@echo ""
	@echo "=== Placements ==="
	$(KUBECTL) get placements -n $(NAMESPACE)
	@echo ""
	@echo "=== PlacementDecisions ==="
	$(KUBECTL) get placementdecisions -n $(NAMESPACE)
	@echo ""
	@echo "=== ManagedClusterAddOns ==="
	$(KUBECTL) get managedclusteraddons -A

##@ Help

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
