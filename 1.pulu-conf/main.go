package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/ovh/pulumi-ovh/sdk/v2/go/ovh/dedicated"
	corev1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/core/v1"
	helmv4 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/helm/v4"
	metav1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/meta/v1"
	yamlv2 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/yaml/v2"
	"github.com/pulumi/pulumi-random/sdk/v4/go/random"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

// otelScrapeAnnotations opts a pod into the otel-node agent's annotation-driven
// metric discovery (k8s_observer + receiver_creator, configured in
// 2.argo/helm/monitoring/templates/otel/node-collector.yaml). Without these the
// argocd_* Prometheus metrics are never collected -- discovery is opt-in and
// nothing else in the cluster asks for it.
//
// The keys are suffixed with the metrics port on purpose. receivercreator's
// getHintAnnotation resolves "<prefix>.<port>/<hint>" before falling back to the
// bare "<prefix>/<hint>", and it evaluates one endpoint per declared container
// port -- so an unsuffixed hint would also make it scrape /metrics on
// argocd-server's 8080, the applicationset controller's 8081/7000, and so on.
//
// The chart merges these over global.podAnnotations
// (mergeOverwrite (deepCopy .Values.global.podAnnotations) .Values.<c>.podAnnotations),
// so inject-certs is preserved. Ingress on each component's "metrics" port is
// already allowed from every namespace by the chart's own NetworkPolicies.
func otelScrapeAnnotations(metricsPort string) pulumi.Map {
	prefix := "io.opentelemetry.discovery.metrics." + metricsPort
	return pulumi.Map{
		prefix + "/enabled": pulumi.String("true"),
		// Mandatory: receivercreator has no default scraper and silently skips
		// the endpoint when the hint is absent. prometheus_simple is why
		// otel-node runs the contrib image rather than otelcol-k8s.
		prefix + "/scraper": pulumi.String("prometheus_simple"),
		// `endpoint` in backticks is substituted with the discovered host:port.
		prefix + "/config": pulumi.String("collection_interval: \"30s\"\nendpoint: \"`endpoint`\"\nmetrics_path: \"/metrics\"\n"),
	}
}

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		conf := config.New(ctx, "")
		argoAppsVersion := conf.Get("argoAppsVersion")

		// Prepare OVH
		serviceName := os.Getenv("SERVER_NAME")
		if serviceName == "" {
			return fmt.Errorf("SERVER_NAME environment variable is not set")
		}
		dnsName := os.Getenv("DNS_NAME")
		if dnsName == "" {
			return fmt.Errorf("DNS_NAME environment variable is not set")
		}
		gitPassword := os.Getenv("GIT_PASSWORD")
		argoDNSName := os.Getenv("ARGO_DNS")
		if argoDNSName == "" {
			return fmt.Errorf("ARGO_DNS environment variable is not set")
		}
		gitRepo := os.Getenv("GIT_REPO")
		if gitRepo == "" {
			return fmt.Errorf("GIT_REPO environment variable is not set")
		}
		gitBranch := os.Getenv("GIT_BRANCH")
		if gitBranch == "" {
			return fmt.Errorf("GIT_BRANCH environment variable is not set")
		}

		deployed := conf.GetBool("deployed")

		serverNetwork, err := dedicated.GetServerSpecificationsNetwork(ctx, &dedicated.GetServerSpecificationsNetworkArgs{
			ServiceName: serviceName,
		}, nil)
		if err != nil {
			return err
		}

		// Create Cilium IpPool
		// Note: CiliumL2AnnouncementPolicy is intentionally omitted.
		// This single-node setup reuses the node's own public IP for LoadBalancer services.
		// L2 announcement sends gratuitous ARPs for that IP, which conflicts with the node's
		// native ARP on eth0 and disrupts all traffic to the IP (including the kube-apiserver
		// on port 6443). Cilium's kube-proxy eBPF replacement handles LoadBalancer DNAT
		// without needing L2 ARP since the IP is already reachable via the node's interface.
		_, err = yamlv2.NewConfigGroup(ctx, "ciliumIpPool", &yamlv2.ConfigGroupArgs{
			Objs: pulumi.Array{
				pulumi.Any(map[string]interface{}{
					"apiVersion": "cilium.io/v2",
					"kind":       "CiliumLoadBalancerIPPool",
					"metadata": map[string]interface{}{
						"name": "ip-pool",
					},
					"spec": map[string]interface{}{
						"blocks": []map[string]interface{}{
							{
								"cidr": serverNetwork.Routing.Ipv4.Ip + "/32",
							},
							{
								"cidr": serverNetwork.Routing.Ipv6.Ip,
							},
						},
					},
				}),
				pulumi.Any(map[string]interface{}{
					"apiVersion": "cilium.io/v2alpha1",
					"kind":       "CiliumL2AnnouncementPolicy",
					"metadata": map[string]interface{}{
						"name": "policy1",
					},
					"spec": map[string]interface{}{
						"externalIPs":     true,
						"loadBalancerIPs": true,
					},
				}),
			},
		})
		if err != nil {
			return fmt.Errorf("failed to create Cilium IpPool: %w", err)
		}

		// Mise en place ArgoCD
		ns, err := corev1.NewNamespace(ctx, "argo-ns", &corev1.NamespaceArgs{
			Metadata: &metav1.ObjectMetaArgs{
				Name: pulumi.String("argocd"),
			},
		})
		if err != nil {
			return err
		}

		redisPasswordResource, err := random.NewRandomPassword(ctx, "argo-redis-password", &random.RandomPasswordArgs{
			Length: pulumi.Int(16),
		})
		if err != nil {
			return err
		}

		argoRedisSecret, err := corev1.NewSecret(ctx, "argo-redis-secret", &corev1.SecretArgs{
			Metadata: &metav1.ObjectMetaArgs{
				Name: pulumi.String("argocd-redis"),
				Namespace: ns.Metadata.ApplyT(func(metadata metav1.ObjectMeta) (*string, error) {
					return metadata.Name, nil
				}).(pulumi.StringPtrOutput),
			},
			Type: pulumi.String("Opaque"),
			StringData: pulumi.StringMap{
				"auth": redisPasswordResource.Result,
			},
		},
			pulumi.DependsOn([]pulumi.Resource{ns}),
		)
		if err != nil {
			return err
		}

		argocd, err := helmv4.NewChart(ctx, "argocd", &helmv4.ChartArgs{
			Chart:   pulumi.String("argo-cd"),
			Version: pulumi.String(argoAppsVersion),
			Namespace: ns.Metadata.ApplyT(func(metadata metav1.ObjectMeta) (*string, error) {
				return metadata.Name, nil
			}).(pulumi.StringPtrOutput),
			RepositoryOpts: &helmv4.RepositoryOptsArgs{
				Repo: pulumi.String("https://argoproj.github.io/argo-helm"),
			},
			Values: pulumi.Map{
				"configs": pulumi.Map{
					"cm": pulumi.Map{
						"dex.config": pulumi.String(`
connectors:
  - type: oidc
    name: Weebo
    id: weebo
    config:
      issuer: $argo-dev-auth:url
      clientID: $argo-dev-auth:client_id
      clientSecret: $argo-dev-auth:client_secret
      insecureEnableGroups: true
      requestedScopes:
        - "openid"
        - "profile"
        - "email"
        - "groups"
  - type: oidc
    name: forgejo-actions
    id: forgejo-actions
    config:
      issuer: https://git.batleforc.fr/api/actions
      scopes:
        - openid
        - groups
      userNameKey: sub`),
						"url":          pulumi.String(fmt.Sprintf("https://%s", argoDNSName)),
						"exec.enabled": pulumi.Bool(true),
					},
					"params": pulumi.Map{
						"server.insecure": pulumi.Bool(deployed),
					},
					"rbac": pulumi.Map{
						"scopes": pulumi.String("[groups]"),
						"policy.csv": pulumi.String(`g, admin, role:admin
g, dev, role:dev
g, reader, role:readonly
g, weebo_admin, role:admin
g, authentik Admins, role:admin`),
					},
				},
				"global": pulumi.Map{
					"domain": pulumi.String(argoDNSName),
					"networkPolicy": pulumi.Map{
						"create": pulumi.Bool(true),
					},
					"podAnnotations": pulumi.Map{
						"inject-certs": pulumi.String("disabled"),
					},
				},
				"dex": pulumi.Map{
					"podAnnotations": pulumi.Map{
						"inject-certs": pulumi.String("enabled"),
					},
				},
				// Metrics ports as declared on each container: controller 8082,
				// server 8083, repo-server 8084, applicationset 8080,
				// notifications 9001. dex and redis expose no argocd_* metrics
				// and are left alone.
				"controller": pulumi.Map{
					"podAnnotations": otelScrapeAnnotations("8082"),
				},
				"repoServer": pulumi.Map{
					"podAnnotations": otelScrapeAnnotations("8084"),
				},
				"applicationSet": pulumi.Map{
					"podAnnotations": otelScrapeAnnotations("8080"),
				},
				"notifications": pulumi.Map{
					"podAnnotations": otelScrapeAnnotations("9001"),
				},
				"server": pulumi.Map{
					"podAnnotations": otelScrapeAnnotations("8083"),
					"ingress": pulumi.Map{
						"enabled": pulumi.Bool(deployed),
						"tls":     pulumi.Bool(true),
						"annotations": pulumi.StringMap{
							"cert-manager.io/cluster-issuer":              pulumi.String("vault-issuer"),
							"cert-manager.io/private-key-size":            pulumi.String("4096"),
							"cert-manager.io/common-name":                 pulumi.String(argoDNSName),
							"cert-manager.io/subject-organizations":       pulumi.String("WeeboSI"),
							"cert-manager.io/subject-organizationalunits": pulumi.String("Infra"),
						},
					},
				},
			},
		}, pulumi.DependsOn([]pulumi.Resource{
			argoRedisSecret,
		}))
		if err != nil {
			return err
		}

		// Create argoCD app

		if gitPassword != "" {
			_, err = yamlv2.NewConfigGroup(ctx, "argoCDAppCred", &yamlv2.ConfigGroupArgs{
				Objs: pulumi.Array{
					pulumi.Any(map[string]interface{}{
						"apiVersion": "v1",
						"kind":       "Secret",
						"metadata": map[string]interface{}{
							"name": "argocd-main-weebo",
							"namespace": ns.Metadata.ApplyT(func(metadata metav1.ObjectMeta) (*string, error) {
								return metadata.Name, nil
							}).(pulumi.StringPtrOutput),
						},
						"stringData": map[string]interface{}{
							"url":      gitRepo,
							"type":     "git",
							"password": gitPassword,
						},
					}),
				},
			}, pulumi.DependsOn([]pulumi.Resource{
				argocd,
			}))
			if err != nil {
				return fmt.Errorf("failed to create argocd app: %w", err)
			}
		}

		_, err = yamlv2.NewConfigGroup(ctx, "argoCDApp", &yamlv2.ConfigGroupArgs{
			Objs: pulumi.Array{
				pulumi.Any(map[string]interface{}{
					"apiVersion": "argoproj.io/v1alpha1",
					"kind":       "Application",
					"metadata": map[string]interface{}{
						"name": "main",
						"namespace": ns.Metadata.ApplyT(func(metadata metav1.ObjectMeta) (*string, error) {
							return metadata.Name, nil
						}).(pulumi.StringPtrOutput),
					},
					"spec": map[string]interface{}{
						"syncPolicy": map[string]interface{}{
							"automated": map[string]interface{}{},
						},
						"destination": map[string]interface{}{
							"namespace": "default",
							"server":    "https://kubernetes.default.svc",
						},
						"project": "default",
						"source": map[string]interface{}{
							"repoURL":        gitRepo,
							"path":           "2.argo/app",
							"targetRevision": gitBranch,
							"helm": map[string]interface{}{
								"releaseName": "main",
								"valuesObject": map[string]interface{}{
									"repo":   gitRepo,
									"branch": gitBranch,
									"traefik": map[string]interface{}{
										"ips": fmt.Sprintf("%s,%s", serverNetwork.Routing.Ipv4.Ip, strings.ReplaceAll(serverNetwork.Routing.Ipv6.Ip, "/128", "")),
									},
								},
							},
						},
					},
				}),
			},
		}, pulumi.DependsOn([]pulumi.Resource{
			argocd,
		}))
		if err != nil {
			return fmt.Errorf("failed to create argocd app: %w", err)
		}

		return nil
	})
}
