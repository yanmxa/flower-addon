package addon

import (
	"embed"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
	addonv1alpha1 "open-cluster-management.io/api/addon/v1alpha1"
)

const (
	// AddonName is the name of the flower addon
	AddonName = "flower-addon"

	// AgentManifestPath is the path to the agent manifests in the embedded FS
	AgentManifestPath = "manifests/templates"

	// FlowerAddonNamespace is the namespace for flower addon on managed clusters
	FlowerAddonNamespaceKey = "FlowerAddonNamespace"

	// FlowerCASignerName is the signer name for Flower CA
	FlowerCASignerName = "flower.io/flower-ca"

	// FlowerCASecretName is the name of the CA signing secret
	FlowerCASecretName = "flower-ca-signing-secret"

	// FlowerCASecretNamespace is the namespace of the CA signing secret
	FlowerCASecretNamespace = "open-cluster-management"

	// FlowerAddonNamespace is the namespace for flower addon on managed clusters
	FlowerAddonNamespace = "flower-addon"

	// DefaultSuperLinkAddress is the default SuperLink address
	DefaultSuperLinkAddress = "superlink.flower-system.svc.cluster.local"
)

//go:embed manifests
var FS embed.FS

// AddOnDeploymentConfigGVR is the GVR for AddOnDeploymentConfig
var AddOnDeploymentConfigGVR = schema.GroupVersionResource{
	Group:    "addon.open-cluster-management.io",
	Version:  "v1alpha1",
	Resource: "addondeploymentconfigs",
}

// FlowerAddonValues contains values for rendering the agent manifests
type FlowerAddonValues struct {
	// ClusterName is the name of the managed cluster
	ClusterName string `json:"clusterName"`
	// SuperLinkAddress is the address of the SuperLink server
	SuperLinkAddress string `json:"superLinkAddress"`
	// SuperLinkPort is the port of the SuperLink Fleet API
	SuperLinkPort int `json:"superLinkPort"`
	// PartitionID is the partition ID for this cluster
	PartitionID int `json:"partitionID"`
	// NumPartitions is the total number of partitions
	NumPartitions int `json:"numPartitions"`
	// Image is the SuperNode image
	Image string `json:"image"`
	// ImagePullPolicy is the image pull policy
	ImagePullPolicy string `json:"imagePullPolicy"`
}

// DefaultFlowerAddonValues returns the default values
func DefaultFlowerAddonValues() FlowerAddonValues {
	return FlowerAddonValues{
		SuperLinkAddress: DefaultSuperLinkAddress,
		SuperLinkPort:    9092,
		PartitionID:      0,
		NumPartitions:    1,
		Image:            "flwr/supernode:1.15.0",
		ImagePullPolicy:  "IfNotPresent",
	}
}

// ClusterManagementAddOnAnnotations returns annotations for the ClusterManagementAddOn
func ClusterManagementAddOnAnnotations() map[string]string {
	return map[string]string{
		addonv1alpha1.AddonLifecycleAnnotationKey: addonv1alpha1.AddonLifecycleAddonManagerAnnotationValue,
	}
}

// ManagedClusterAddOnOwnerReference returns the owner reference for ManagedClusterAddOn
func ManagedClusterAddOnOwnerReference(name, uid string) metav1.OwnerReference {
	return metav1.OwnerReference{
		APIVersion: "addon.open-cluster-management.io/v1alpha1",
		Kind:       "ManagedClusterAddOn",
		Name:       name,
		UID:        "uid",
	}
}
