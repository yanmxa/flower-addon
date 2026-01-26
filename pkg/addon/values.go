package addon

import (
	"context"
	"sort"

	"k8s.io/klog/v2"
	"open-cluster-management.io/addon-framework/pkg/addonfactory"
	addonv1alpha1 "open-cluster-management.io/api/addon/v1alpha1"
	clusterv1 "open-cluster-management.io/api/cluster/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// GetDefaultValues returns the default values for rendering agent manifests
func GetDefaultValues(cluster *clusterv1.ManagedCluster, addon *addonv1alpha1.ManagedClusterAddOn) (addonfactory.Values, error) {
	values := DefaultFlowerAddonValues()
	values.ClusterName = cluster.Name

	return addonfactory.JsonStructToValues(values)
}

// GetValuesWithPartition returns values with partition information calculated
func GetValuesWithPartition(
	ctx context.Context,
	hubClient client.Client,
	cluster *clusterv1.ManagedCluster,
	addon *addonv1alpha1.ManagedClusterAddOn,
) (addonfactory.Values, error) {
	values := DefaultFlowerAddonValues()
	values.ClusterName = cluster.Name

	// Get all managed clusters with flower addon enabled
	partitionID, numPartitions, err := calculatePartition(ctx, hubClient, cluster.Name)
	if err != nil {
		klog.Warningf("Failed to calculate partition for cluster %s: %v, using defaults", cluster.Name, err)
	} else {
		values.PartitionID = partitionID
		values.NumPartitions = numPartitions
	}

	return addonfactory.JsonStructToValues(values)
}

// calculatePartition calculates the partition ID and total partitions for a cluster
func calculatePartition(ctx context.Context, hubClient client.Client, clusterName string) (int, int, error) {
	// List all ManagedClusterAddOns for flower-addon
	addonList := &addonv1alpha1.ManagedClusterAddOnList{}
	if err := hubClient.List(ctx, addonList); err != nil {
		return 0, 1, err
	}

	// Collect cluster names that have flower addon
	var flowerClusters []string
	for _, addon := range addonList.Items {
		if addon.Name == AddonName {
			flowerClusters = append(flowerClusters, addon.Namespace)
		}
	}

	// Sort cluster names for consistent ordering
	sort.Strings(flowerClusters)

	// Find the partition ID for this cluster
	partitionID := 0
	for i, name := range flowerClusters {
		if name == clusterName {
			partitionID = i
			break
		}
	}

	return partitionID, len(flowerClusters), nil
}

// MergeValues merges multiple value maps, with later maps taking precedence
func MergeValues(valueMaps ...addonfactory.Values) addonfactory.Values {
	result := make(addonfactory.Values)
	for _, values := range valueMaps {
		for k, v := range values {
			result[k] = v
		}
	}
	return result
}
