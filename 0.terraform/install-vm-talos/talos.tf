resource "talos_machine_secrets" "capi_secret" {
  depends_on = [resource.ovh_dedicated_server_reinstall_task.server_reinstall]
}

locals {
  cluster_name = "weebo4"
  node_ip      = data.ovh_dedicated_server.server.ip
}

data "talos_machine_configuration" "capi_config_controlplane" {
  cluster_name     = local.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.node_ip}:6443"
  machine_secrets  = talos_machine_secrets.capi_secret.machine_secrets
  config_patches = [
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      },
      machine = {
        kubelet = {
          extraArgs = {
            rotate-server-certificates = "true"
          }
          extraMounts = [
            {
              source      = "/var/local-path-provisioner",
              destination = "/var/local-path-provisioner",
              type        = "bind"
              options = [
                "bind",
                "rshared",
                "rw"
              ]
            }
          ]
        }
        install = {
          image = data.talos_image_factory_urls.metal.urls.installer,
          extraKernelArgs = [
            "net.ifnames=0"
          ],
        },
        #   network = {
        #     nameservers = [
        #       "8.8.8.8"
        #     ]
        #     interfaces = [
        #       {
        #         interface = "eth0",
        #         addresses = [
        #           "${local.node_ip}/24"
        #         ],
        #         routes = [
        #           {
        #             network = "0.0.0.0/0"
        #             gateway = "192.168.100.1"
        #           }
        #         ]
        #       }
        #     ]
        #   }
      }
    })
  ]
}

data "talos_client_configuration" "capi_config_client" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.capi_secret.client_configuration
  nodes                = [local.node_ip]
}

resource "talos_machine_configuration_apply" "capi_config_apply" {
  client_configuration        = talos_machine_secrets.capi_secret.client_configuration
  machine_configuration_input = data.talos_machine_configuration.capi_config_controlplane.machine_configuration
  node                        = local.node_ip
}

resource "talos_machine_bootstrap" "capi_bootstrap" {
  depends_on = [
    talos_machine_configuration_apply.capi_config_apply
  ]
  node                 = local.node_ip
  client_configuration = talos_machine_secrets.capi_secret.client_configuration
}

resource "talos_cluster_kubeconfig" "capi_kubeconfig" {
  depends_on = [
    talos_machine_bootstrap.capi_bootstrap
  ]
  client_configuration = talos_machine_secrets.capi_secret.client_configuration
  node                 = local.node_ip
}

resource "local_file" "capi_kubeconfig_file" {
  depends_on = [
    talos_cluster_kubeconfig.capi_kubeconfig
  ]
  content  = talos_cluster_kubeconfig.capi_kubeconfig.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}

resource "local_file" "capi_talos_config" {
  content  = data.talos_client_configuration.capi_config_client.talos_config
  filename = "${path.module}/talos-config.yaml"
}
