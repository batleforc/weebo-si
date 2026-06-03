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
		talosInstallVersion := conf.Get("talosInstallVersion")
		kubeVersion := conf.Get("kubeVersion")
		ciliumVersion := conf.Get("ciliumVersion")
		authEnabled := conf.GetBool("authEnabled")
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
			TalosVersion: pulumi.String(talosInstallVersion),
			SchematicId:  schematicID.ToStringOutput(),
		})

		qcow2Url := urlResult.SchematicId().ApplyT(func(schematicId string) (string, error) {
			ctx.Export("schematicId", pulumi.String(schematicId))
			return fmt.Sprintf("https://factory.talos.dev/image/%s/%s/%s-amd64.qcow2", schematicId, talosInstallVersion, platform), nil
		}).(pulumi.StringOutput)
		ctx.Export("imageUrl", urlResult.ToGetUrlsResultOutput().Urls().Installer())
		ctx.Export("qcow2Url", qcow2Url)

		// Prepare OVH
		serviceName := os.Getenv("SERVER_NAME")
		if serviceName == "" {
			return fmt.Errorf("SERVER_NAME environment variable is not set")
		}
		dnsName := os.Getenv("DNS_NAME")
		if dnsName == "" {
			return fmt.Errorf("DNS_NAME environment variable is not set")
		}
		dnsAltName := os.Getenv("DNS_ALT_NAME")
		if dnsAltName == "" {
			return fmt.Errorf("DNS_ALT_NAME environment variable is not set")
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
			Filename: pulumi.String("../0.config/talosconfig2.yaml"),
		})
		if err != nil {
			return err
		}

		ctx.Export("clusterName", configuration.ClusterName())
		ctx.Export("clusterEndpoint", configuration.ClusterEndpoint())
		ctx.Export("MasterIPv4", pulumi.String(serverNetwork.Routing.Ipv4.Ip))
		ctx.Export("MasterIPv6", pulumi.String(serverNetwork.Routing.Ipv6.Ip))

		jsonPatchConfig := urlResult.Urls().Installer().ApplyT(func(installerUrl string) (string, error) {
			conf := map[string]interface{}{
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
							strings.ReplaceAll(serverNetwork.Routing.Ipv6.Ip, "/128", ""),
							dnsName,
							dnsAltName,
						},
						"extraArgs": map[string]interface{}{
							"feature-gates": "UserNamespacesSupport=true",
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
						"user.max_user_namespaces":         11255,
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
						"extraConfig": map[string]interface{}{
							"featureGates": map[string]interface{}{
								"UserNamespacesSupport": true,
							},
						},
					},
					"seccompProfiles": []map[string]interface{}{
						{
							"name": "ci-build.json",
							"value": map[string]interface{}{
								"defaultAction": "SCMP_ACT_ERRNO",
								"architectures": []string{
									"SCMP_ARCH_X86_64",
									"SCMP_ARCH_X86",
									"SCMP_ARCH_X32",
								},
								"syscalls": []map[string]interface{}{
									{
										"action": "SCMP_ACT_ALLOW",
										"names": []string{
											"_llseek",
											"_newselect",
											"accept",
											"accept4",
											"access",
											"alarm",
											"arch_prctl",
											"bind",
											"brk",
											"capget",
											"capset",
											"chdir",
											"chmod",
											"chown",
											"chown32",
											"chroot",
											"clock_getres",
											"clock_getres_time64",
											"clock_gettime",
											"clock_gettime64",
											"clock_nanosleep",
											"clock_nanosleep_time64",
											"clone",
											"clone3",
											"close",
											"close_range",
											"connect",
											"copy_file_range",
											"creat",
											"dup",
											"dup2",
											"dup3",
											"epoll_create",
											"epoll_create1",
											"epoll_ctl",
											"epoll_ctl_old",
											"epoll_pwait",
											"epoll_pwait2",
											"epoll_wait",
											"epoll_wait_old",
											"eventfd",
											"eventfd2",
											"execve",
											"execveat",
											"exit",
											"exit_group",
											"faccessat",
											"faccessat2",
											"fadvise64",
											"fadvise64_64",
											"fallocate",
											"fchdir",
											"fchmod",
											"fchmodat",
											"fchmodat2",
											"fchown",
											"fchown32",
											"fchownat",
											"fcntl",
											"fcntl64",
											"fdatasync",
											"fgetxattr",
											"flistxattr",
											"flock",
											"fork",
											"fremovexattr",
											"fsetxattr",
											"fstat",
											"fstat64",
											"fstatat64",
											"fstatfs",
											"fstatfs64",
											"fsync",
											"ftruncate",
											"ftruncate64",
											"futex",
											"futex_time64",
											"futimesat",
											"get_mempolicy",
											"get_robust_list",
											"getcpu",
											"getcwd",
											"getdents",
											"getdents64",
											"getegid",
											"getegid32",
											"geteuid",
											"geteuid32",
											"getgid",
											"getgid32",
											"getgroups",
											"getgroups32",
											"getitimer",
											"getpeername",
											"getpgid",
											"getpgrp",
											"getpid",
											"getppid",
											"getpriority",
											"getrandom",
											"getresgid",
											"getresgid32",
											"getresuid",
											"getresuid32",
											"getrlimit",
											"getrusage",
											"getsid",
											"getsockname",
											"getsockopt",
											"gettid",
											"gettimeofday",
											"getuid",
											"getuid32",
											"getxattr",
											"inotify_add_watch",
											"inotify_init",
											"inotify_init1",
											"inotify_rm_watch",
											"io_cancel",
											"io_destroy",
											"io_getevents",
											"io_pgetevents",
											"io_pgetevents_time64",
											"io_setup",
											"io_submit",
											"ioctl",
											"ioprio_get",
											"kill",
											"landlock_add_rule",
											"landlock_create_ruleset",
											"landlock_restrict_self",
											"lchown",
											"lchown32",
											"lgetxattr",
											"link",
											"linkat",
											"listen",
											"listxattr",
											"llistxattr",
											"lremovexattr",
											"lseek",
											"lsetxattr",
											"lstat",
											"lstat64",
											"madvise",
											"membarrier",
											"memfd_create",
											"mincore",
											"mkdir",
											"mkdirat",
											"mknod",
											"mknodat",
											"mmap",
											"mmap2",
											"mount",
											"mprotect",
											"mq_getsetattr",
											"mq_notify",
											"mq_open",
											"mq_timedreceive",
											"mq_timedreceive_time64",
											"mq_timedsend",
											"mq_timedsend_time64",
											"mq_unlink",
											"mremap",
											"msgctl",
											"msgget",
											"msgrcv",
											"msgsnd",
											"msync",
											"munmap",
											"nanosleep",
											"newfstatat",
											"open",
											"openat",
											"openat2",
											"pause",
											"pidfd_open",
											"pipe",
											"pipe2",
											"poll",
											"ppoll",
											"ppoll_time64",
											"prctl",
											"pread64",
											"preadv",
											"preadv2",
											"prlimit64",
											"pselect6",
											"pselect6_time64",
											"pwrite64",
											"pwritev",
											"pwritev2",
											"read",
											"readahead",
											"readlink",
											"readlinkat",
											"readv",
											"recv",
											"recvfrom",
											"recvmmsg",
											"recvmmsg_time64",
											"recvmsg",
											"removexattr",
											"rename",
											"renameat",
											"renameat2",
											"restart_syscall",
											"rmdir",
											"rseq",
											"rt_sigaction",
											"rt_sigpending",
											"rt_sigprocmask",
											"rt_sigqueueinfo",
											"rt_sigreturn",
											"rt_sigsuspend",
											"rt_sigtimedwait",
											"rt_sigtimedwait_time64",
											"rt_tgsigqueueinfo",
											"sched_get_priority_max",
											"sched_get_priority_min",
											"sched_getaffinity",
											"sched_getattr",
											"sched_getparam",
											"sched_getscheduler",
											"sched_rr_get_interval",
											"sched_rr_get_interval_time64",
											"sched_yield",
											"seccomp",
											"select",
											"semctl",
											"semget",
											"semop",
											"semtimedop",
											"semtimedop_time64",
											"send",
											"sendfile",
											"sendfile64",
											"sendmmsg",
											"sendmsg",
											"sendto",
											"set_robust_list",
											"set_tid_address",
											"setfsgid",
											"setfsgid32",
											"setfsuid",
											"setfsuid32",
											"setgid",
											"setgid32",
											"setgroups",
											"setgroups32",
											"setitimer",
											"setpgid",
											"setpriority",
											"setregid",
											"setregid32",
											"setresgid",
											"setresgid32",
											"setresuid",
											"setresuid32",
											"setreuid",
											"setreuid32",
											"setrlimit",
											"setsid",
											"setsockopt",
											"setuid",
											"setuid32",
											"setxattr",
											"shmat",
											"shmctl",
											"shmdt",
											"shmget",
											"shutdown",
											"sigaltstack",
											"signalfd",
											"signalfd4",
											"socket",
											"socketcall",
											"socketpair",
											"splice",
											"stat",
											"stat64",
											"statfs",
											"statfs64",
											"statx",
											"symlink",
											"symlinkat",
											"sync",
											"sync_file_range",
											"syncfs",
											"sysinfo",
											"tee",
											"tgkill",
											"time",
											"timer_create",
											"timer_delete",
											"timer_getoverrun",
											"timer_gettime",
											"timer_gettime64",
											"timer_settime",
											"timer_settime64",
											"timerfd_create",
											"timerfd_gettime",
											"timerfd_gettime64",
											"timerfd_settime",
											"timerfd_settime64",
											"times",
											"tkill",
											"truncate",
											"truncate64",
											"ugetrlimit",
											"umask",
											"umount2",
											"uname",
											"unshare",
											"unlink",
											"unlinkat",
											"utime",
											"utimensat",
											"utimensat_time64",
											"utimes",
											"vfork",
											"wait4",
											"waitid",
											"waitpid",
											"write",
											"writev",
										},
									},
									{
										"action": "SCMP_ACT_ERRNO",
										"names": []string{
											"acct",
											"bdflush",
											"bpf",
											"cachestat",
											"clock_settime",
											"clock_settime64",
											"delete_module",
											"finit_module",
											"fsconfig",
											"fsmount",
											"fsopen",
											"fspick",
											"init_module",
											"ioperm",
											"iopl",
											"kcmp",
											"kexec_file_load",
											"kexec_load",
											"keyctl",
											"lookup_dcookie",
											"map_shadow_stack",
											"mbind",
											"memfd_secret",
											"migrate_pages",
											"modify_ldt",
											"mount_setattr",
											"move_mount",
											"move_pages",
											"name_to_handle_at",
											"nfsservctl",
											"nice",
											"oldfstat",
											"oldlstat",
											"oldolduname",
											"oldstat",
											"olduname",
											"open_by_handle_at",
											"open_tree",
											"pciconfig_iobase",
											"pciconfig_read",
											"pciconfig_write",
											"perf_event_open",
											"pivot_root",
											"process_madvise",
											"process_vm_readv",
											"process_vm_writev",
											"ptrace",
											"query_module",
											"quotactl",
											"reboot",
											"set_mempolicy",
											"setdomainname",
											"sethostname",
											"setns",
											"settimeofday",
											"sgetmask",
											"ssetmask",
											"stime",
											"swapoff",
											"swapon",
											"syscall",
											"sysfs",
											"syslog",
											"uselib",
											"userfaultfd",
											"ustat",
											"vhangup",
											"vm86",
											"vm86old",
											"vmsplice",
										},
									},
								},
							},
						},
					},
					"install": map[string]interface{}{
						"image": installerUrl,
						"disk":  "/dev/sda",
					},
					"nodeLabels": map[string]interface{}{
						"node.kubernetes.io/exclude-from-external-load-balancers": map[string]interface{}{
							"$patch": "delete",
						},
					},
					"network": map[string]interface{}{
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
					},
				},
			}
			if authEnabled {
				oidcIssuerUrl := os.Getenv("OIDC_ISSUER_URL")
				if oidcIssuerUrl == "" {
					return "", fmt.Errorf("OIDC_ISSUER_URL environment variable is not set")
				}
				oidcClientID := os.Getenv("OIDC_CLIENT_ID")
				if oidcClientID == "" {
					return "", fmt.Errorf("OIDC_CLIENT_ID environment variable is not set")
				}
				conf["cluster"].(map[string]interface{})["apiServer"].(map[string]interface{})["extraArgs"].(map[string]interface{})["authentication-config"] = "/var/lib/apiserver/authentication.yaml"
				conf["cluster"].(map[string]interface{})["apiServer"].(map[string]interface{})["extraVolumes"] = []map[string]interface{}{
					{
						"hostPath":  "/var/lib/apiserver",
						"mountPath": "/var/lib/apiserver",
						"readonly":  true,
					},
				}
				conf["machine"].(map[string]interface{})["files"] = []map[string]interface{}{
					{
						"permissions": 0644,
						"path":        "/var/lib/apiserver/authentication.yaml",
						"op":          "create",
						"content": fmt.Sprintf(`apiVersion: apiserver.config.k8s.io/v1beta1
kind: AuthenticationConfiguration
jwt:
  - issuer:
      url: '%s'
      audiences:
        - '%s'
      audienceMatchPolicy: MatchAny
    claimValidationRules:
      - expression: "claims.email_verified == true"
        message: "email must be verified"
    claimMappings:
      username:
        expression: '"weebsso:" + claims.email'
      groups:
        expression: "claims.groups"
      uid:
        expression: "claims.sub"
    userValidationRules:
      - expression: "!user.username.startsWith('system:')"
        message: "username cannot used reserved system: prefix"
      - expression: "user.groups.all(group, !group.startsWith('system:'))"
        message: "groups cannot used reserved system: prefix"`, oidcIssuerUrl, oidcClientID),
					},
				}
			}
			swapJsonPatchConfig, err := json.Marshal(conf)
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
			"name":       "staticdisk",
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
			Filename: pulumi.String("../0.config/kubeconfig.yaml"),
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
