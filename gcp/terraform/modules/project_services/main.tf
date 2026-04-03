variable "project" {
  type = string
}

variable "services" {
  type = list(string)
}

resource "google_project_service" "enabled" {
  for_each           = toset(var.services)
  project            = var.project
  service            = each.value
  disable_on_destroy = false
}
