output "contact_bucket_name" {
  value = module.storage.contact_bucket_name
}

output "content_bucket_name" {
  value = module.storage.content_bucket_name
}

output "contact_notifications_topic" {
  value = module.storage.contact_notifications_topic
}

output "contact_notifications_subscription" {
  value = module.storage.contact_notifications_subscription
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

output "cloud_build_trigger_name" {
  value = google_cloudbuild_trigger.backend_beta_deploy.name
}

output "cloud_deploy_runner_email" {
  value = google_service_account.cloud_deploy_runner.email
}

output "cloud_deploy_pipeline_name" {
  value = google_clouddeploy_delivery_pipeline.backend.name
}
