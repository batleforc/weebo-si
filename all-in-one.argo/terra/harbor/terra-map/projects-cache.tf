resource "harbor_registry" "docker" {
  provider_name = "docker-hub"
  name          = "dockerhub"
  endpoint_url  = "https://hub.docker.com"
}

resource "harbor_registry" "github" {
  provider_name = "github"
  name          = "github"
  endpoint_url  = "https://ghcr.io"
}

resource "harbor_registry" "quay" {
  provider_name = "quay"
  name          = "quay"
  endpoint_url  = "https://quay.io"
}

resource "harbor_registry" "talos" {
  provider_name = "harbor"
  name          = "talos"
  endpoint_url  = "https://factory.talos.dev"
  
}

resource "harbor_project" "cache-dck" {
  name          = "cache-dck"
  registry_id   = resource.harbor_registry.docker.registry_id
  public        = "false"
  storage_quota = 15
}

resource "harbor_project" "cache-ghub" {
  name          = "cache-ghub"
  registry_id   = resource.harbor_registry.github.registry_id
  public        = "false"
  storage_quota = 15
}

resource "harbor_project" "cache-quay" {
  name          = "cache-quay"
  registry_id   = resource.harbor_registry.quay.registry_id
  public        = "false"
  storage_quota = 15
}

resource "harbor_project" "cache-talos" {
  name          = "cache-talos"
  registry_id   = resource.harbor_registry.talos.registry_id
  public        = "false"
  storage_quota = 15
}