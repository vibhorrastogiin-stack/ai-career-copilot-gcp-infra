variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}

variable "stage" {
  type = string
}

variable "contact_ttl_days" {
  type = number
}

resource "google_storage_bucket" "content" {
  name                        = "${var.app_name}-content-${var.stage}"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_storage_bucket" "contact" {
  name                        = "${var.app_name}-contact-${var.stage}"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle_rule {
    condition {
      age = var.contact_ttl_days
    }

    action {
      type = "Delete"
    }
  }
}

output "content_bucket_name" {
  value = google_storage_bucket.content.name
}

output "contact_bucket_name" {
  value = google_storage_bucket.contact.name
}
