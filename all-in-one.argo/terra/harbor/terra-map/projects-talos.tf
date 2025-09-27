resource "harbor_project" "talos" {
  name          = "talos"
  public        = "false"
  storage_quota = 10
}