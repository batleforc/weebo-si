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
  # Argo CD as admin: Authentik's argo-admin application (2.argo/helm/auth/sub),
  # behind admin-step-up (second factor). Its only group is the
  # weebo_admin:step-up marker, which policy.csv below makes role:admin.
  # The connector above, without the second factor, gives read-only at most.
  - type: oidc
    name: Weebo admin (2FA)
    id: weebo-admin
    config:
      issuer: $argo-admin-auth:url
      clientID: $argo-admin-auth:client_id
      clientSecret: $argo-admin-auth:client_secret
      insecureEnableGroups: true
      scopes:
        - openid
        - profile
        - email
  # Forgejo Actions OIDC tokens (git.batleforc.fr), for CI to come. Today it
  # grants nothing: no groups (insecureEnableGroups off), no email, and
  # policy.default is empty. Give it a project role on the exact sub
  # (repository and ref) it needs, never a policy.csv group.
  - type: oidc
    name: forgejo-actions
    id: forgejo-actions
    config:
      issuer: https://git.batleforc.fr/api/actions
      scopes:
        - openid
        - groups
      userNameKey: sub
# The BatleHub theme of the login and error pages: argocd-dex-theme, rendered
# by the root app (2.argo/app/templates/argocd-dex-theme.yaml) and mounted
# below into the image's own web directory. rundex passes this key through.
frontend:
  dir: /srv/dex/web
  theme: batlehub
  issuer: Argo CD
  logoURL: theme/logo.svg`),
						"url": pulumi.String(fmt.Sprintf("https://%s", argoDNSName)),
						// No web terminal into pods: a way into every workload that the
						// apiserver audit does not attribute to a labsso identity.
						"exec.enabled": pulumi.Bool(false),
						// The local `admin` account: kept until the stack is `deployed`
						// (no ingress yet, so no Authentik sign-in: it is the only way
						// in). Once deployed it is off: sign-in is Authentik only, and
						// the break-glass is the Talos kubeconfig, not a static password.
						"admin.enabled": pulumi.String(fmt.Sprintf("%t", !deployed)),
						// A working day, not the 24h default.
						"users.session.duration": pulumi.String("8h"),
						// The BatleHub theme: argocd-styles-cm, rendered by the root
						// app (2.argo/app/templates/argocd-theme.yaml) and mounted by
						// the chart at /shared/app/custom. Until it exists the UI
						// keeps its own look.
						"ui.cssurl": pulumi.String("./custom/batlehub.css"),
					},
					"params": pulumi.Map{
						"server.insecure": pulumi.Bool(deployed),
						// Log every RBAC denial (to ClickStack with the server logs).
						"server.rbac.log.enforce.enable": pulumi.String("true"),
					},
					"rbac": pulumi.Map{
						// email too: the che-users AppProject (2.argo/helm/che/hardening)
						// names each person by email in its per-user roles.
						"scopes": pulumi.String("[groups, email]"),
						// Nothing for whoever no line names: a plain weebo_user sees
						// only their che-users / che-config-<user> project roles
						// (2.argo/helm/che/hardening).
						"policy.default": pulumi.String(""),
						// Only groups Authentik's CRs manage. role:admin needs the
						// weebo_admin:step-up marker, emitted by the argo-admin
						// application alone (connector weebo-admin, second factor);
						// weebo_admin without it reads.
						"policy.csv": pulumi.String(`g, weebo_admin:step-up, role:admin
g, weebo_admin, role:readonly`),
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
					// The BatleHub theme (frontend in dex.config above), next to
					// the image's stock ones. Optional: until the root app has
					// rendered argocd-dex-theme, Dex serves an empty theme (its
					// pages unstyled) rather than failing to start. A plain
					// directory, no subPath: an update reaches the pod as is.
					"volumes": pulumi.Array{
						pulumi.Map{
							"name": pulumi.String("batlehub-theme"),
							"configMap": pulumi.Map{
								"name":     pulumi.String("argocd-dex-theme"),
								"optional": pulumi.Bool(true),
							},
						},
					},
					"volumeMounts": pulumi.Array{
						pulumi.Map{
							"name":      pulumi.String("batlehub-theme"),
							"mountPath": pulumi.String("/srv/dex/web/themes/batlehub"),
							"readOnly":  pulumi.Bool(true),
						},
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
						// Every object 2.argo/app renders names its namespace (argocd or
						// kube-system), so the default one only has to be one the
						// `bootstrap` project allows.
						"destination": map[string]interface{}{
							"namespace": "argocd",
							"server":    "https://kubernetes.default.svc",
						},
						// `bootstrap` (2.argo/app/values.yaml), not Argo CD's `default`,
						// which 2.argo/app locks once this is applied (lockDefaultProject).
						"project": "bootstrap",
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
