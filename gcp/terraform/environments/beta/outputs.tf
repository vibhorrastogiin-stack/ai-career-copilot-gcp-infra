output "contact_bucket_name" {
  value = module.storage.contact_bucket_name
}

output "content_bucket_name" {
  value = module.storage.content_bucket_name
}

output "artifact_registry_repository" {
  value = module.artifact_registry.repository_id
}

output "backend_service_name" {
  value = module.backend_run.service_name
}

output "backend_url" {
  value = module.backend_run.url
}

output "backend_service_account_email" {
  value = module.backend_run.service_account_email
}
