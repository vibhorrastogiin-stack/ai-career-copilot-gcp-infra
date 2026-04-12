variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "image" {
  type = string
}

variable "frontend_url" {
  type = string
}

variable "service_account_roles" {
  type = list(string)
}

variable "app_env" {
  type = map(string)
}

variable "secret_env" {
  type = map(string)
}

variable "contact_bucket" {
  type = string
}

variable "content_bucket" {
  type = string
}

locals {
  secret_env_pairs = var.secret_env
}

resource "google_service_account" "backend" {
  project      = var.project_id
  account_id   = replace(var.service_name, "_", "-")
  display_name = "${var.service_name} runtime"
}

resource "google_project_iam_member" "backend_service_account_roles" {
  for_each = toset(var.service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.backend.email}"
}

resource "google_cloud_run_v2_service" "backend" {
  name                 = var.service_name
  project              = var.project_id
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_ALL"
  invoker_iam_disabled = true

  template {
    service_account = google_service_account.backend.email

    containers {
      image = var.image

      dynamic "env" {
        for_each = var.app_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env_pairs
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      scaling,
      template[0].labels,
      template[0].containers[0].image,
    ]
  }
}

output "service_name" {
  value = google_cloud_run_v2_service.backend.name
}

output "url" {
  value = google_cloud_run_v2_service.backend.uri
}

output "service_account_email" {
  value = google_service_account.backend.email
}
