provider "google" {
  project = var.project_id
}

module "cloud_run" {
  source = "./modules/cloud_run"
  project_id = var.project_id
  region = var.region
  app_name = var.app_name
}

module "iap" {
  source = "./modules/iap"
  cloud_run_name = module.cloud_run.cloud_run_name
  project_id = var.project_id
  region = var.region
  domain = var.domain
  app_name = var.app_name
  iap_client_id = var.iap_client_id
  iap_client_secret = var.iap_client_secret
  iap_group = var.iap_group
}

output "load-balancer-ip" {
  value = module.iap.load-balancer-ip
}

output "oauth2-redirect-uri" {
  value = "https://iap.googleapis.com/v1/oauth/clientIds/${var.iap_client_id}:handleRedirect"
}
