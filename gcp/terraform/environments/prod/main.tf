locals {
  stage = "prod"

  required_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
  ]

  secret_names = [
    "jwt-secret",
    "google-client-id",
    "google-client-secret",
    "openai-api-key",
  ]

  backend_env = {
    SPRING_PROFILES_ACTIVE = local.stage
    FRONTEND_URL           = var.frontend_url
    APP_STATE_PROVIDER     = "gcp"
    APP_STORAGE_PROVIDER   = "gcp"
    APP_CONTENT_BUCKET     = module.storage.content_bucket_name
    APP_CONTACT_BUCKET     = module.storage.contact_bucket_name
    GCP_PROJECT_ID         = var.project_id
    GCP_REGION             = var.region
  }

  backend_secret_env = {
    JWT_SECRET           = "jwt-secret"
    GOOGLE_CLIENT_ID     = "google-client-id"
    GOOGLE_CLIENT_SECRET = "google-client-secret"
    OPENAI_API_KEY       = "openai-api-key"
  }

  backend_service_account_roles = [
    "roles/datastore.user",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectAdmin",
  ]
}

module "project_services" {
  source   = "../../modules/project_services"
  project  = var.project_id
  services = local.required_services
}

module "storage" {
  source           = "../../modules/storage"
  project_id       = var.project_id
  region           = var.region
  app_name         = var.app_name
  stage            = local.stage
  contact_ttl_days = 365
}

module "artifact_registry" {
  source        = "../../modules/artifact_registry"
  project_id    = var.project_id
  region        = var.region
  repository_id = "${var.app_name}-${local.stage}-backend"
}

module "secrets" {
  source       = "../../modules/secrets"
  project_id   = var.project_id
  secret_names = local.secret_names
}

resource "google_firestore_database" "default" {
  project                 = var.project_id
  name                    = "(default)"
  location_id             = var.region
  type                    = "FIRESTORE_NATIVE"
  delete_protection_state = "DELETE_PROTECTION_ENABLED"
  deletion_policy         = "ABANDON"
  concurrency_mode        = "OPTIMISTIC"

  depends_on = [module.project_services]
}

module "backend_run" {
  source                = "../../modules/backend_run"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${var.app_name}-${local.stage}-backend"
  image                 = var.backend_image
  frontend_url          = var.frontend_url
  service_account_roles = local.backend_service_account_roles
  app_env               = local.backend_env
  secret_env            = local.backend_secret_env
  contact_bucket        = module.storage.contact_bucket_name
  content_bucket        = module.storage.content_bucket_name

  depends_on = [
    module.project_services,
    module.storage,
    module.secrets,
    google_firestore_database.default,
  ]
}
