variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "repository_id" {
  type = string
}

resource "google_artifact_registry_repository" "backend" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Backend container images"
  format        = "DOCKER"
}

output "repository_id" {
  value = google_artifact_registry_repository.backend.repository_id
}
