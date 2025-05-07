terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "4.4.0"
    }
  }
}

variable "cluster_name" {
  description = "The name of the cluster."
  type        = string
  default     = "example-cluster"
}

variable "host" {
  description = "The host for the Kubernetes API server."
  type        = string
  default     = "http://example.com:443"
}

provider "vault" {
  token   = local.token_vault
  address = "https://vault.capi.weebo.poc"
}

locals {
  token       = file("/tmp/token")
  certificate = file("/tmp/kube_ca.crt")
  token_vault = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = var.cluster_name
}

resource "vault_kubernetes_auth_backend_config" "kube-auth" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.host
  kubernetes_ca_cert     = local.certificate
  token_reviewer_jwt     = local.token
  disable_iss_validation = "true"
}

resource "vault_kubernetes_auth_backend_role" "cert-manager" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "cert-manager"
  bound_service_account_names      = ["cert-manager", "vault-issuer"]
  bound_service_account_namespaces = ["cert-manager"]
  token_ttl                        = 3600
  token_policies                   = ["allow_pki"]
}
