package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/helm"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
)

func httpFunc(t *testing.T, msg string) func(statusCode int, body string) bool {
	return func(statusCode int, body string) bool {
		if statusCode != 200 {
			if statusCode != 503 {
				t.Fatalf("Invalid status code: %d", statusCode)
			}
			return false
		}
		if !strings.Contains(body, msg) {
			t.Fatalf("Invalid response: %s", body)
			return false
		}
		return true
	}
}

func TestDeploys(t *testing.T) {
	// Path to the helm chart we will test
	helmChartPath := "../charts/dgraph"

	// Setup the kubectl config and context. Here we choose to use the defaults, which is:
	// - HOME/.kube/config for the kubectl config file
	// - Current context of the kubectl config file
	// We also specify that we are working in the default namespace (required to get the Pod)
	kubectlOptions := k8s.NewKubectlOptions("", "", "default")

	options := &helm.Options{
		SetValues: map[string]string{"image.tag": Tag},
	}

	// We generate a unique release name so that we can refer to after deployment.
	// By doing so, we can schedule the delete call here so that at the end of the test, we run
	// `helm delete RELEASE_NAME` to clean up any resources that were created.
	releaseName := fmt.Sprintf("dgraph-%s", strings.ToLower(random.UniqueId()))
	defer helm.Delete(t, options, releaseName, true)

	// Deploy the chart using `helm install`. Note that we use the version without `E`, since we want to assert the
	// install succeeds without any errors.
	helm.Install(t, options, helmChartPath, releaseName)

	// Now that the chart is deployed, verify the deployment. This function will open a tunnel to the Pod and hit the
	verifyInstance(t, kubectlOptions, fmt.Sprintf("%s-dgraph-alpha-0", releaseName),
		"pod", "/health", 8080, httpFunc(t, "\"status\":\"healthy\""))
	verifyInstance(t, kubectlOptions, fmt.Sprintf("%s-dgraph-zero-0", releaseName),
		"pod", "/health", 6080, httpFunc(t, "OK"))
	verifyInstance(t, kubectlOptions, fmt.Sprintf("%s-dgraph-alpha", releaseName),
		"svc", "/health", 8080, httpFunc(t, "\"status\":\"healthy\""))
	verifyInstance(t, kubectlOptions, fmt.Sprintf("%s-dgraph-zero", releaseName),
		"svc", "/health", 6080, httpFunc(t, "OK"))
	verifyInstance(t, kubectlOptions, fmt.Sprintf("%s-dgraph-ratel", releaseName),
		"svc", "", 8000, httpFunc(t, "OK"))
}

func verifyInstance(t *testing.T, kubectlOptions *k8s.KubectlOptions, podName string,
	typ string, url string, port int, aftercall func(statusCode int, body string) bool) {
	// Wait for the pod to come up. It takes some time for the Pod to start, so retry a few times.
	retries := 25
	sleep := 5 * time.Second
	rt := k8s.ResourceTypePod
	switch typ {
	case "svc":
		rt = k8s.ResourceTypeService
		k8s.WaitUntilServiceAvailable(t, kubectlOptions, podName, retries, sleep)
	default:
		k8s.WaitUntilPodAvailable(t, kubectlOptions, podName, retries, sleep)
	}

	// We will first open a tunnel to the pod, making sure to close it at the end of the test.
	tunnel := k8s.NewTunnel(kubectlOptions, rt, podName, 0, port)
	defer tunnel.Close()
	tunnel.ForwardPort(t)

	// It takes some time for the Pod to start, so retry a few times.
	endpoint := fmt.Sprintf("http://%s%s", tunnel.Endpoint(), url)
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		endpoint,
		nil,
		retries,
		sleep,
		aftercall,
	)
}
