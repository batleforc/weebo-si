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

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		conf := config.New(ctx, "")
		argoAppsVersion := conf.Get("argoAppsVersion")

		// Prepare OVH
		serviceName := os.Getenv("SERVER_NAME")
		if serviceName == "" {
			return fmt.Errorf("SERVER_NAME environment variable is not set")
		}
		dnsName := os.Getenv("PROXMOX_DNS")
		if dnsName == "" {
			return fmt.Errorf("PROXMOX_DNS environment variable is not set")
		}

		serverNetwork, err := dedicated.GetServerSpecificationsNetwork(ctx, &dedicated.GetServerSpecificationsNetworkArgs{
			ServiceName: serviceName,
		}, nil)
		if err != nil {
			return err
		}

		// Create Cilium IpPool
		_, err = yamlv2.NewConfigGroup(ctx, "ciliumIpPool", &yamlv2.ConfigGroupArgs{
			Objs: pulumi.Array{
				pulumi.Any(map[string]interface{}{
					"apiVersion": "cilium.io/v2alpha1",
					"kind":       "CiliumLoadBalancerIPPool",
					"metadata": map[string]interface{}{
						"name": "ip-pool",
					},
					"spec": map[string]interface{}{
						"blocks": []map[string]interface{}{
							{
								"start": serverNetwork.Routing.Ipv4.Ip,
								"stop":  serverNetwork.Routing.Ipv4.Ip,
							},
							{
								"start": strings.Replace(serverNetwork.Routing.Ipv6.Ip, "/128", "", -1),
								"stop":  strings.Replace(serverNetwork.Routing.Ipv6.Ip, "/128", "", -1),
							},
						},
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
		}, pulumi.DependsOn([]pulumi.Resource{
			ns,
		}))
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
    name: Weebo-SI
    id: weebo-si
    config:
      issuer: $argo-dev-auth:url
      clientID: $argo-dev-auth:client_id
      clientSecret: $argo-dev-auth:client_secret
      insecureEnableGroups: true
      requestedScopes:
        - "openid"
        - "profile"
        - "email"
        - "groups"`),
						"url": pulumi.String("https://argo.4.weebo.fr"),
					},
					"params": pulumi.Map{
						"server.insecure": pulumi.Bool(true),
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
					"domain": pulumi.String("argo.4.weebo.fr"),
				},
				"server": pulumi.Map{
					"ingress": pulumi.Map{
						"enabled": pulumi.Bool(true),
						"tls":     pulumi.Bool(true),
						"annotations": pulumi.StringMap{
							"cert-manager.io/cluster-issuer": pulumi.String("outbound"),
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
							"repoURL":        "https://github.com/batleforc/weebo-si.git",
							"path":           "all-in-one.argo/app",
							"targetRevision": "HEAD",
							"directory": map[string]interface{}{
								"recurse": true,
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
