
# Enable required APIs
resource "google_project_service" "enable_apis" {
  for_each = toset([
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudidentity.googleapis.com",
    "compute.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}