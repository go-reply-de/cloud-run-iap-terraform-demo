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