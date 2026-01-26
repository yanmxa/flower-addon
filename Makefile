# Kubernetes configuration
KUBECTL ?= kubectl
NAMESPACE ?= open-cluster-management

# Image configuration (official Flower images)
FLOWER_VERSION ?= 1.25.0
SUPERNODE_IMAGE ?= flwr/supernode:$(FLOWER_VERSION)

.PHONY: all
all: help

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
deploy-addon: ## Deploy OCM addon resources (AddOnTemplate, ClusterManagementAddOn, etc.)
	@echo "Deploying OCM addon resources..."
	$(KUBECTL) apply -k deploy/addon/
	@echo ""
	@echo "Addon deployment complete!"
	@echo "Next: Update SuperLink address with: make update-superlink-address"

.PHONY: undeploy-addon
undeploy-addon: ## Remove OCM addon resources
	$(KUBECTL) delete -k deploy/addon/ --ignore-not-found

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
	$(KUBECTL) apply -k examples/$(CLUSTER)/

.PHONY: disable-addon
disable-addon: ## Disable addon on a cluster (usage: make disable-addon CLUSTER=cluster1)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make disable-addon CLUSTER=cluster1)
endif
	$(KUBECTL) delete -k examples/$(CLUSTER)/ --ignore-not-found

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
	@echo "=== ManagedClusterAddOns ==="
	$(KUBECTL) get managedclusteraddons -A

##@ Help

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
