variable "project_id" {
  type = string
}

variable "region" {
  description = "Location for load balancer and Cloud Run resources"
  default     = "us-central1"
}

variable "app_name" {
  description = "Name for load balancer and associated resources"
  default     = "iap-lb"
}