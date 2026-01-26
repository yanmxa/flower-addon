package main

import (
	"context"
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/client-go/kubernetes"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	"k8s.io/klog/v2"
	"open-cluster-management.io/addon-framework/pkg/addonfactory"
	"open-cluster-management.io/addon-framework/pkg/addonmanager"
	addonv1alpha1 "open-cluster-management.io/api/addon/v1alpha1"
	addonv1alpha1client "open-cluster-management.io/api/client/addon/clientset/versioned"
	clusterv1 "open-cluster-management.io/api/cluster/v1"
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/yanmxa/flower-addon/pkg/addon"
)

var (
	scheme = runtime.NewScheme()
)

func init() {
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))
	utilruntime.Must(clusterv1.AddToScheme(scheme))
	utilruntime.Must(addonv1alpha1.AddToScheme(scheme))
}

func main() {
	cmd := &cobra.Command{
		Use:   "flower-addon-manager",
		Short: "Flower Federated Learning Addon Manager",
		RunE: func(cmd *cobra.Command, args []string) error {
			return run(ctrl.SetupSignalHandler())
		},
	}

	if err := cmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run(ctx context.Context) error {
	klog.Info("Starting Flower Addon Manager")

	config, err := rest.InClusterConfig()
	if err != nil {
		// Fallback to kubeconfig for local development
		config = ctrl.GetConfigOrDie()
	}

	kubeClient, err := kubernetes.NewForConfig(config)
	if err != nil {
		return fmt.Errorf("failed to create kube client: %w", err)
	}

	addonClient, err := addonv1alpha1client.NewForConfig(config)
	if err != nil {
		return fmt.Errorf("failed to create addon client: %w", err)
	}

	mgr, err := addonmanager.New(config)
	if err != nil {
		return fmt.Errorf("failed to create addon manager: %w", err)
	}

	agentAddon, err := addonfactory.NewAgentAddonFactory(addon.AddonName, addon.FS, addon.AgentManifestPath).
		WithConfigGVRs(addon.AddOnDeploymentConfigGVR).
		WithGetValuesFuncs(
			addon.GetDefaultValues,
			addonfactory.GetAddOnDeploymentConfigValues(
				addonfactory.NewAddOnDeploymentConfigGetter(addonClient),
				addonfactory.ToAddOnDeploymentConfigValues,
			),
		).
		WithAgentRegistrationOption(addon.NewRegistrationOption(kubeClient)).
		BuildTemplateAgentAddon()
	if err != nil {
		return fmt.Errorf("failed to build agent addon: %w", err)
	}

	if err := mgr.AddAgent(agentAddon); err != nil {
		return fmt.Errorf("failed to add agent addon: %w", err)
	}

	klog.Info("Starting addon manager")
	return mgr.Start(ctx)
}
