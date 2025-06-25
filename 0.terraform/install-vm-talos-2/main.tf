terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    ovh = {
      source = "ovh/ovh"
    }
    helm = {
      source = "hashicorp/helm"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.8.2"
    }
    cilium = {
      source  = "littlejo/cilium"
      version = "0.3.1"
    }
  }
}

variable "kubeconfig" {
  type        = string
  description = "Path to the kubeconfig file for the Kubernetes cluster"
  default     = "../install-vm-talos/kubeconfig"
}

variable "cilium_version" {
  type        = string
  description = "Version of Cilium to install"
  default     = "1.17.4"
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

provider "cilium" {
  config_path = var.kubeconfig
}
