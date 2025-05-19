data "google_project" "project" {
}

variable "project_id" {
  type = string
}

variable "region" {
  description = "Location for load balancer and Cloud Run resources"
  default     = "us-central1"
}

variable "domain" {
  description = "Domain name to run the load balancer on."
  type        = string
}

variable "app_name" {
  description = "Name for load balancer and associated resources"
  default     = "iap-lb"
}

variable "iap_client_id" {
  type      = string
  sensitive = false
}

variable "iap_client_secret" {
  type      = string
  sensitive = true
}

variable "iap_group" {
  type      = string
  sensitive = true
}

provider "google" {
  project = var.project_id
}

resource "google_cloud_run_v2_service" "default" {
  name                = var.app_name
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    containers {
      image = "gcr.io/cloudrun/hello"
    }
  }
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  provider              = google
  name                  = "serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_v2_service.default.name
  }
}

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 12.0"

  project = var.project_id
  name    = var.app_name

  ssl                             = true
  managed_ssl_certificate_domains = [var.domain]
  https_redirect                  = true

  backends = {
    default = {
      description = null
      groups = [
        {
          group = google_compute_region_network_endpoint_group.serverless_neg.id
        }
      ]
      enable_cdn             = false
      security_policy        = null
      custom_request_headers = null

      iap_config = {
        enable               = true
        oauth2_client_id     = var.iap_client_id
        oauth2_client_secret = var.iap_client_secret
      }
      log_config = {
        enable      = false
        sample_rate = null
      }
    }
  }
}

data "google_iam_policy" "iap" {
  binding {
    role = "roles/iap.httpsResourceAccessor"
    members = [
      "group:${var.iap_group}", // a google group
      // "allAuthenticatedUsers"          // anyone with a Google account (not recommended)
      // "user:ahmetalpbalkan@gmail.com", // a particular user
    ]
  }
}

resource "google_iap_web_backend_service_iam_policy" "policy" {
  project             = var.project_id
  web_backend_service = "${var.app_name}-backend-default"
  policy_data         = data.google_iam_policy.iap.policy_data
  depends_on = [
    module.lb-http
  ]
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  location = google_cloud_run_v2_service.default.location
  project  = google_cloud_run_v2_service.default.project
  name     = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com"

  # Add this dependency
  depends_on = [
    module.lb-http,
    google_iap_web_backend_service_iam_policy.policy
  ]
}

output "load-balancer-ip" {
  value = module.lb-http.external_ip
}

output "oauth2-redirect-uri" {
  value = "https://iap.googleapis.com/v1/oauth/clientIds/${var.iap_client_id}:handleRedirect"
}
