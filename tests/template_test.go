package test

import (
	"testing"

	appsv1 "k8s.io/api/apps/v1"

	"github.com/gruntwork-io/terratest/modules/helm"
)

const (
	Tag = "v20.07.0"
)

func TestRender(t *testing.T) {
	// Path to the helm chart we will test
	helmChartPath := "../charts/dgraph"

	// Setup the args. For this test, we will set the following input values:
	options := &helm.Options{
		SetValues: map[string]string{"image.tag": Tag},
	}

	// Run RenderTemplate to render the template and capture the output.
	output := helm.RenderTemplate(t, options, helmChartPath, "deployment", []string{"templates/alpha-statefulset.yaml"})

	// Now we use kubernetes/client-go library to render the template output into the Deployment struct. This will
	// ensure the Pod resource is rendered correctly.
	var dep appsv1.StatefulSet
	helm.UnmarshalK8SYaml(t, output, &dep)

	// Finally, we verify the pod spec is set to the expected container image value
	expectedContainerImage := "docker.io/dgraph/dgraph:" + Tag
	podContainers := dep.Spec.Template.Spec.Containers
	if podContainers[0].Image != expectedContainerImage {
		t.Fatalf("Rendered container image (%s) is not expected (%s)", podContainers[0].Image, expectedContainerImage)
	}
}
