resource "talos_machine_secrets" "capi_secret" {
  depends_on = [resource.proxmox_virtual_environment_vm.capi_template]
}

locals {
  cluster_name = "capi"
  node_ip      = element(local.capi_possible_ip[0], 0)
}

data "talos_machine_configuration" "capi_config_controlplane" {
  cluster_name     = local.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.node_ip}:6443"
  machine_secrets  = talos_machine_secrets.capi_secret.machine_secrets
}

data "talos_client_configuration" "capi_config_client" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.capi_secret.client_configuration
  nodes                = ["${local.node_ip}"]
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
