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

data "google_project" "current" {
  project_id = var.project_id
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
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

resource "google_pubsub_topic" "contact_notifications" {
  name    = "${var.app_name}-${var.stage}-contact-events"
  project = var.project_id
}

resource "google_pubsub_topic_iam_member" "storage_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.contact_notifications.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

resource "google_storage_notification" "contact_object_finalize" {
  bucket         = google_storage_bucket.contact.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.contact_notifications.id
  event_types    = ["OBJECT_FINALIZE"]

  custom_attributes = {
    bucket = google_storage_bucket.contact.name
    stage  = var.stage
  }

  depends_on = [google_pubsub_topic_iam_member.storage_publisher]
}

resource "google_pubsub_subscription" "contact_notifications" {
  name    = "${var.app_name}-${var.stage}-contact-events-sub"
  project = var.project_id
  topic   = google_pubsub_topic.contact_notifications.name

  ack_deadline_seconds       = 20
  message_retention_duration = "604800s"
}

output "content_bucket_name" {
  value = google_storage_bucket.content.name
}

output "contact_bucket_name" {
  value = google_storage_bucket.contact.name
}

output "contact_notifications_topic" {
  value = google_pubsub_topic.contact_notifications.name
}

output "contact_notifications_subscription" {
  value = google_pubsub_subscription.contact_notifications.name
}
