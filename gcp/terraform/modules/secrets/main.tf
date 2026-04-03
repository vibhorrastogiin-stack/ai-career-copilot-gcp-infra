variable "project_id" {
  type = string
}

variable "secret_names" {
  type = list(string)
}

resource "google_secret_manager_secret" "secret" {
  for_each  = toset(var.secret_names)
  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }
}

output "secret_ids" {
  value = { for k, v in google_secret_manager_secret.secret : k => v.id }
}
