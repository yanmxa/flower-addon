package addon

import (
	"context"
	"fmt"

	certificatesv1 "k8s.io/api/certificates/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"open-cluster-management.io/addon-framework/pkg/agent"
	addonv1alpha1 "open-cluster-management.io/api/addon/v1alpha1"
	clusterv1 "open-cluster-management.io/api/cluster/v1"
)

// NewRegistrationOption returns the registration option for the flower addon
func NewRegistrationOption(kubeClient kubernetes.Interface) *agent.RegistrationOption {
	return &agent.RegistrationOption{
		CSRConfigurations: func(cluster *clusterv1.ManagedCluster, addon *addonv1alpha1.ManagedClusterAddOn) ([]addonv1alpha1.RegistrationConfig, error) {
			return []addonv1alpha1.RegistrationConfig{
				{
					SignerName: FlowerCASignerName,
					Subject: addonv1alpha1.Subject{
						User: fmt.Sprintf("system:flower:cluster:%s", cluster.Name),
						Groups: []string{
							"system:flower:clusters",
						},
					},
				},
			}, nil
		},
		CSRApproveCheck: func(cluster *clusterv1.ManagedCluster, addon *addonv1alpha1.ManagedClusterAddOn, csr *certificatesv1.CertificateSigningRequest) bool {
			// Auto-approve CSRs for flower addon
			return true
		},
		CSRSign: func(cluster *clusterv1.ManagedCluster, addon *addonv1alpha1.ManagedClusterAddOn, csr *certificatesv1.CertificateSigningRequest) ([]byte, error) {
			// The actual signing is handled by the custom signer controller
			// This function is called after the CSR is approved
			return nil, nil
		},
		AgentInstallNamespace: func(addon *addonv1alpha1.ManagedClusterAddOn) (string, error) {
			return FlowerAddonNamespace, nil
		},
	}
}

// GetCustomSignerSecretName returns the secret name containing the CA for custom signing
func GetCustomSignerSecretName() string {
	return FlowerCASecretName
}

// GetCustomSignerSecretNamespace returns the namespace of the CA secret
func GetCustomSignerSecretNamespace() string {
	return FlowerCASecretNamespace
}

// IsValidFlowerCSR validates if the CSR is a valid flower addon CSR
func IsValidFlowerCSR(csr *certificatesv1.CertificateSigningRequest) bool {
	if csr.Spec.SignerName != FlowerCASignerName {
		return false
	}
	return true
}

// GetSignerFromSecret creates a signer configuration from the CA secret
type SignerConfig struct {
	CASecretName      string
	CASecretNamespace string
	SignerName        string
}

// NewSignerConfig returns a new signer configuration for flower CA
func NewSignerConfig() SignerConfig {
	return SignerConfig{
		CASecretName:      FlowerCASecretName,
		CASecretNamespace: FlowerCASecretNamespace,
		SignerName:        FlowerCASignerName,
	}
}

// EnsureCASecret ensures the CA secret exists, creating it if necessary
func EnsureCASecret(ctx context.Context, kubeClient kubernetes.Interface) error {
	// Check if secret exists
	_, err := kubeClient.CoreV1().Secrets(FlowerCASecretNamespace).Get(ctx, FlowerCASecretName, metav1.GetOptions{})
	if err == nil {
		// Secret already exists
		return nil
	}

	// TODO: Generate CA certificate and create secret
	// For now, this will be handled by the CA generation job
	return nil
}
