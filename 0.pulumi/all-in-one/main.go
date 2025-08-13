package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/littlejo/pulumi-cilium/sdk/go/cilium"
	"github.com/ovh/pulumi-ovh/sdk/v2/go/ovh/dedicated"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
	"github.com/pulumiverse/pulumi-talos/sdk/go/talos/client"
	"github.com/pulumiverse/pulumi-talos/sdk/go/talos/cluster"
	"github.com/pulumiverse/pulumi-talos/sdk/go/talos/imagefactory"
	"github.com/pulumiverse/pulumi-talos/sdk/go/talos/machine"
	"gopkg.in/yaml.v3"

	"github.com/pulumi/pulumi-local/sdk/go/local"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		conf := config.New(ctx, "")
		talosVersion := conf.Require("talosVersion")
		kubeVersion := conf.Get("kubeVersion")
		ciliumVersion := conf.Get("ciliumVersion")
		platform := "metal"
		nodeName := "weebo4"

		// Prepare Talos

		tmpYamlSchema, err := yaml.Marshal(map[string]interface{}{
			"customization": map[string]interface{}{
				"extraKernelArgs": []string{
					"net.ifnames=0",
				},
				"systemExtensions": map[string]interface{}{
					"officialExtensions": []string{
						"siderolabs/iscsi-tools",
						"siderolabs/util-linux-tools",
						"siderolabs/intel-ucode",
						"siderolabs/mei",
					},
				},
			},
		})
		if err != nil {
			return err
		}

		schema, err := imagefactory.NewSchematic(ctx, "schematicResource", &imagefactory.SchematicArgs{
			Schematic: pulumi.String(tmpYamlSchema),
		})
		if err != nil {
			return err
		}

		schematicID := schema.ID().ApplyT(func(s pulumi.ID) (string, error) {
			return string(s), nil
		}).(pulumi.StringOutput)

		ctx.Export("schematicId", schematicID)

		urlResult := imagefactory.GetUrlsOutput(ctx, imagefactory.GetUrlsOutputArgs{
			Platform:     pulumi.StringPtr(platform),
			TalosVersion: pulumi.String(talosVersion),
			SchematicId:  schematicID.ToStringOutput(),
		})

		qcow2Url := urlResult.SchematicId().ApplyT(func(schematicId string) (string, error) {
			ctx.Export("schematicId", pulumi.String(schematicId))
			return fmt.Sprintf("https://factory.talos.dev/image/%s/%s/%s-amd64.qcow2", schematicId, talosVersion, platform), nil
		}).(pulumi.StringOutput)
		ctx.Export("imageUrl", urlResult.ToGetUrlsResultOutput().Urls().Installer())
		ctx.Export("qcow2Url", qcow2Url)

		// Prepare OVH
		serviceName := os.Getenv("SERVER_NAME")
		if serviceName == "" {
			return fmt.Errorf("SERVER_NAME environment variable is not set")
		}
		dnsName := os.Getenv("PROXMOX_DNS")
		if dnsName == "" {
			return fmt.Errorf("PROXMOX_DNS environment variable is not set")
		}

		// Reinstall the server with Talos
		reinstall, err := dedicated.NewServerReinstallTask(ctx, "reinstallTalos", &dedicated.ServerReinstallTaskArgs{
			ServiceName: pulumi.String(serviceName),
			Os:          pulumi.String("byoi_64"),
			Customizations: &dedicated.ServerReinstallTaskCustomizationsArgs{
				Hostname:          pulumi.String(nodeName),
				ImageType:         pulumi.String("qcow2"),
				ImageUrl:          qcow2Url,
				EfiBootloaderPath: pulumi.String("\\EFI\\BOOT\\BOOTX64.EFI"),
			},
		})
		if err != nil {
			return err
		}

		serverNetwork, err := dedicated.GetServerSpecificationsNetwork(ctx, &dedicated.GetServerSpecificationsNetworkArgs{
			ServiceName: serviceName,
		}, nil)
		if err != nil {
			return err
		}

		secrets, err := machine.NewSecrets(ctx, "secrets", nil)
		if err != nil {
			return err
		}

		configuration := machine.GetConfigurationOutput(ctx, machine.GetConfigurationOutputArgs{
			ClusterName:       pulumi.String(fmt.Sprintf("%s-cluster", nodeName)),
			MachineType:       pulumi.String("controlplane"),
			ClusterEndpoint:   pulumi.String(fmt.Sprintf("https://%s:6443", serverNetwork.Routing.Ipv4.Ip)),
			MachineSecrets:    secrets.MachineSecrets,
			TalosVersion:      pulumi.String(talosVersion),
			KubernetesVersion: pulumi.StringPtr(kubeVersion),
		})

		talosConfig := client.GetConfigurationOutput(ctx, client.GetConfigurationOutputArgs{
			ClusterName: configuration.ClusterName(),
			ClientConfiguration: client.GetConfigurationClientConfigurationArgs{
				CaCertificate:     secrets.ClientConfiguration.CaCertificate(),
				ClientCertificate: secrets.ClientConfiguration.ClientCertificate(),
				ClientKey:         secrets.ClientConfiguration.ClientKey(),
			},
			Nodes: pulumi.StringArray{
				pulumi.String(serverNetwork.Routing.Ipv4.Ip),
			},
			Endpoints: pulumi.StringArray{
				pulumi.String(serverNetwork.Routing.Ipv4.Ip),
			},
		}, nil)

		_, err = local.NewFile(ctx, "talosconfig", &local.FileArgs{
			Content:  talosConfig.TalosConfig(),
			Filename: pulumi.String("talos-config.yaml"),
		})
		if err != nil {
			return err
		}

		ctx.Export("clusterName", configuration.ClusterName())
		ctx.Export("clusterEndpoint", configuration.ClusterEndpoint())
		ctx.Export("MasterIPv4", pulumi.String(serverNetwork.Routing.Ipv4.Ip))
		ctx.Export("MasterIPv6", pulumi.String(serverNetwork.Routing.Ipv6.Ip))

		jsonPatchConfig := urlResult.Urls().Installer().ApplyT(func(installerUrl string) (string, error) {
			swapJsonPatchConfig, err := json.Marshal(map[string]interface{}{
				"cluster": map[string]interface{}{
					"allowSchedulingOnControlPlanes": true,
					"extraManifests": []string{
						"https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml",
						"https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
					},
					"network": map[string]interface{}{
						"cni": map[string]interface{}{
							"name": "none",
						},
						"podSubnets": []string{
							"10.244.0.0/16",
							"fd00:10:244::/56",
						},
						"serviceSubnets": []string{
							"10.96.0.0/12",
							"fd00:10:96::/112",
						},
						// "controllerManager": map[string]interface{}{
						// 	"extraArgs": map[string]interface{}{
						// 		"node-cidr-mask-size-ipv4": "24",
						// 		"node-cidr-mask-size-ipv6": "112",
						// 		"controllers":              "*,tokencleaner,-node-ipam-controller",
						// 	},
						// },
					},
					"proxy": map[string]interface{}{
						"disabled": true,
					},
					"apiServer": map[string]interface{}{
						"certSANs": []string{
							serverNetwork.Routing.Ipv4.Ip,
							strings.Replace(serverNetwork.Routing.Ipv6.Ip, "/128", "", -1),
							dnsName,
						},
					},
				},
				"machine": map[string]interface{}{
					"sysctls": map[string]interface{}{
						"net.ipv4.ip_forward":              1,
						"net.ipv6.conf.all.forwarding":     1,
						"vm.nr_hugepages":                  2048,
						"net.ipv6.conf.all.autoconf":       0,
						"net.ipv6.conf.all.accept_ra":      0,
						"net.ipv4.conf.all.src_valid_mark": 1,
					},
					"kubelet": map[string]interface{}{
						"extraArgs": map[string]interface{}{
							"rotate-server-certificates": true,
						},
						"extraMounts": []map[string]interface{}{
							{
								"source":      "/var/local-path-provisioner",
								"destination": "/var/local-path-provisioner",
								"type":        "bind",
								"options":     []string{"bind", "rshared", "rw"},
							},
						},
					},
					"install": map[string]interface{}{
						"image": installerUrl,
						"disk":  "/dev/sda",
						"extraKernelArgs": []string{
							"net.ifnames=0",
						},
					},
					"network": map[string]interface{}{
						"hostname": fmt.Sprintf("%s-controlplane", nodeName),
						"nameservers": []string{
							"213.186.33.99",
							"2001:41d0:3:163::1",
						},
						"interfaces": []map[string]interface{}{
							{
								"addresses": []string{
									strings.ReplaceAll(serverNetwork.Routing.Ipv6.Ip, "/128", "/48"),
								},
								"interface": "eth0",
								"dhcp":      true,
								"dhcpOptions": map[string]interface{}{
									"ipv4": true,
									"ipv6": false,
								},
								"routes": []map[string]interface{}{
									{
										"network": "::/0",
										"gateway": serverNetwork.Routing.Ipv6.Gateway,
									},
								},
							},
						},
						// "interfaces": []map[string]interface{}{
						// 	{
						// 		"interface": "eth0",
						// 		"addresses": []string{
						// 			fmt.Sprintf("%s/24", serverNetwork.Routing.Ipv4.Ip),
						// 			serverNetwork.Routing.Ipv6.Ip,
						// 		},
						// 		"dhcp": false,
						// 		"dhcpOptions": map[string]interface{}{
						// 			"ipv4": true,
						// 			"ipv6": false,
						// 		},
						// 		"routes": []map[string]interface{}{
						// 			{
						// 				"network": "0.0.0.0/0",
						// 				"gateway": serverNetwork.Routing.Ipv4.Gateway,
						// 			},
						// 		},
						// 	},
						// },
					},
				},
			})
			if err != nil {
				return "", fmt.Errorf("failed to marshal JSON patch config: %w", err)
			}

			return string(swapJsonPatchConfig), nil
		}).(pulumi.StringOutput)

		_, err = local.NewFile(ctx, "patchJson", &local.FileArgs{
			Content:  jsonPatchConfig,
			Filename: pulumi.String("patch.json"),
		})
		if err != nil {
			return err
		}

		jsonPatchUserVolume, err := json.Marshal(map[string]interface{}{
			"apiVersion": "v1alpha1",
			"kind":       "UserVolumeConfig",
			"name":       "longhorn",
			"provisioning": map[string]interface{}{
				"diskSelector": map[string]interface{}{
					"match": "disk.dev_path == '/dev/sdb'",
				},
				"minSize": "450GB",
			},
		})
		if err != nil {
			return err
		}

		// Apply the configuration and Bootstrap the cluster
		configurationApply, err := machine.NewConfigurationApply(ctx, "configurationApply", &machine.ConfigurationApplyArgs{
			ClientConfiguration:       secrets.ClientConfiguration,
			MachineConfigurationInput: configuration.MachineConfiguration(),
			Node:                      pulumi.String(serverNetwork.Routing.Ipv4.Ip),
			Endpoint:                  pulumi.String(serverNetwork.Routing.Ipv4.Ip),
			ConfigPatches: pulumi.StringArray{
				jsonPatchConfig,
				pulumi.String(string(jsonPatchUserVolume)),
			},
		}, pulumi.DependsOn([]pulumi.Resource{
			reinstall,
		}))
		if err != nil {
			return fmt.Errorf("failed to create configuration apply: %w", err)
		}

		bootstrap, err := machine.NewBootstrap(ctx, "bootstrap", &machine.BootstrapArgs{
			Node:                pulumi.String(serverNetwork.Routing.Ipv4.Ip),
			ClientConfiguration: secrets.ClientConfiguration,
		}, pulumi.DependsOn([]pulumi.Resource{
			configurationApply,
			reinstall,
		}))
		if err != nil {
			return fmt.Errorf("failed to create bootstrap: %w", err)
		}

		// Create the kubeconfig file
		kubeconfig, err := cluster.NewKubeconfig(ctx, "kubeconfig", &cluster.KubeconfigArgs{
			ClientConfiguration: cluster.KubeconfigClientConfigurationArgs{
				CaCertificate:     secrets.ClientConfiguration.CaCertificate(),
				ClientCertificate: secrets.ClientConfiguration.ClientCertificate(),
				ClientKey:         secrets.ClientConfiguration.ClientKey(),
			},
			Endpoint: pulumi.String(serverNetwork.Routing.Ipv4.Ip),
			Node:     pulumi.String(serverNetwork.Routing.Ipv4.Ip),
		}, pulumi.DependsOn([]pulumi.Resource{
			bootstrap,
		}))
		if err != nil {
			return fmt.Errorf("failed to create kubeconfig: %w", err)
		}

		fileKubeconfig, err := local.NewFile(ctx, "kubeconfig", &local.FileArgs{
			Content:  kubeconfig.KubeconfigRaw,
			Filename: pulumi.String("kubeconfig.yaml"),
		}, pulumi.DependsOn([]pulumi.Resource{
			kubeconfig,
		}))
		if err != nil {
			return err
		}

		// Install Cilium
		ciliumValues, err := os.ReadFile("cilium-values.yaml")
		if err != nil {
			return fmt.Errorf("failed to read cilium values file: %w", err)
		}

		ciliumInstall, err := cilium.NewInstall(ctx, "ciliumInstall", &cilium.InstallArgs{
			Version: pulumi.String(ciliumVersion),
			Sets: pulumi.StringArray{
				pulumi.Sprintf("k8sServiceHost=%s", serverNetwork.Routing.Ipv4.Ip),
			},
			Values: pulumi.String(string(ciliumValues)),
		}, pulumi.DependsOn([]pulumi.Resource{
			kubeconfig,
			fileKubeconfig,
		}))

		if err != nil {
			return fmt.Errorf("failed to create Cilium install: %w", err)
		}

		// Install Hubble for cilium
		_, err = cilium.NewHubble(ctx, "example", &cilium.HubbleArgs{
			Ui: pulumi.Bool(true),
		}, pulumi.DependsOn([]pulumi.Resource{
			ciliumInstall,
		}))

		if err != nil {
			return fmt.Errorf("failed to create Hubble: %w", err)
		}
		return nil
	})
}
