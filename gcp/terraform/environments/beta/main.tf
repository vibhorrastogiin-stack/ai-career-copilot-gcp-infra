locals {
  stage = "beta"

  required_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
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

  beta_backend_service_name          = "${var.app_name}-${local.stage}-backend"
  prod_backend_service_name          = "${var.app_name}-prod-backend"
  beta_backend_service_account_email = "${replace(local.beta_backend_service_name, "_", "-")}@${var.project_id}.iam.gserviceaccount.com"
  prod_backend_service_account_email = "${replace(local.prod_backend_service_name, "_", "-")}@${var.prod_project_id}.iam.gserviceaccount.com"
  cloud_deploy_runner_account_id     = "cloud-deploy-runner"
  cloud_deploy_runner_email          = "${local.cloud_deploy_runner_account_id}@${var.project_id}.iam.gserviceaccount.com"
  cloud_build_service_account_email  = "${data.google_project.beta.number}-compute@developer.gserviceaccount.com"
  cloud_build_service_account_path   = "projects/${var.project_id}/serviceAccounts/${local.cloud_build_service_account_email}"
  cloud_build_service_agent_email    = "service-${data.google_project.beta.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

data "google_project" "beta" {
  project_id = var.project_id
}

data "google_project" "prod" {
  provider   = google.prod
  project_id = var.prod_project_id
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
  delete_protection_state = "DELETE_PROTECTION_DISABLED"
  deletion_policy         = "DELETE"
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

resource "google_service_account" "cloud_deploy_runner" {
  project      = var.project_id
  account_id   = local.cloud_deploy_runner_account_id
  display_name = "Cloud Deploy runner"
}

resource "google_project_iam_member" "beta_build_service_account_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/clouddeploy.operator",
    "roles/logging.logWriter",
    "roles/storage.admin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.cloud_build_service_account_email}"
}

resource "google_project_iam_member" "beta_cloud_deploy_runner_roles" {
  for_each = toset([
    "roles/artifactregistry.reader",
    "roles/clouddeploy.jobRunner",
    "roles/clouddeploy.operator",
    "roles/run.admin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_deploy_runner.email}"
}

resource "google_project_iam_member" "beta_cloud_run_admin_for_build_service_account" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${local.cloud_build_service_account_email}"
}

resource "google_project_iam_member" "prod_cloud_deploy_runner_run_admin" {
  provider = google.prod
  project  = var.prod_project_id
  role     = "roles/run.admin"
  member   = "serviceAccount:${google_service_account.cloud_deploy_runner.email}"
}

resource "google_project_iam_member" "prod_runtime_artifact_reader_in_beta" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${local.prod_backend_service_account_email}"
}

resource "google_service_account_iam_member" "cloud_build_service_agent_token_creator_on_runner" {
  service_account_id = google_service_account.cloud_deploy_runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.cloud_build_service_agent_email}"
}

resource "google_service_account_iam_member" "runner_act_as_runner" {
  service_account_id = google_service_account.cloud_deploy_runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_deploy_runner.email}"
}

resource "google_service_account_iam_member" "runner_act_as_beta_runtime" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.beta_backend_service_account_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_deploy_runner.email}"
}

resource "google_service_account_iam_member" "runner_act_as_prod_runtime" {
  provider           = google.prod
  service_account_id = "projects/${var.prod_project_id}/serviceAccounts/${local.prod_backend_service_account_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_deploy_runner.email}"
}

resource "google_cloudbuild_trigger" "backend_beta_deploy" {
  project         = var.project_id
  location        = var.region
  name            = "backend-beta-deploy"
  description     = "Deploy backend beta on push"
  filename        = "cloudbuild.deploy.yaml"
  service_account = local.cloud_build_service_account_path

  github {
    owner = var.backend_repo_owner
    name  = var.backend_repo_name

    push {
      branch = var.backend_trigger_branch_regex
    }
  }

  depends_on = [
    module.project_services,
    google_project_iam_member.beta_build_service_account_roles,
  ]
}

resource "google_clouddeploy_target" "beta" {
  project     = var.project_id
  location    = var.region
  name        = "ai-career-copilot-beta"
  description = "Beta Cloud Run target for the backend service."

  run {
    location = "projects/${var.project_id}/locations/${var.region}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.cloud_deploy_runner.email
  }

  depends_on = [
    module.project_services,
    google_project_iam_member.beta_cloud_deploy_runner_roles,
    google_service_account_iam_member.runner_act_as_runner,
    google_service_account_iam_member.runner_act_as_beta_runtime,
  ]
}

resource "google_clouddeploy_target" "prod" {
  project          = var.project_id
  location         = var.region
  name             = "ai-career-copilot-prod"
  description      = "Production Cloud Run target for the backend service."
  require_approval = true

  run {
    location = "projects/${var.prod_project_id}/locations/${var.region}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.cloud_deploy_runner.email
  }

  depends_on = [
    module.project_services,
    google_project_iam_member.prod_cloud_deploy_runner_run_admin,
    google_project_iam_member.prod_runtime_artifact_reader_in_beta,
    google_service_account_iam_member.runner_act_as_runner,
    google_service_account_iam_member.runner_act_as_prod_runtime,
  ]
}

resource "google_clouddeploy_delivery_pipeline" "backend" {
  project     = var.project_id
  location    = var.region
  name        = "ai-career-copilot-backend"
  description = "Promote the backend release from beta to prod on Cloud Run."

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.beta.name
      profiles  = ["beta"]
    }

    stages {
      target_id = google_clouddeploy_target.prod.name
      profiles  = ["prod"]
    }
  }

  depends_on = [
    google_clouddeploy_target.beta,
    google_clouddeploy_target.prod,
  ]
}

resource "google_clouddeploy_automation" "auto_promote_to_prod" {
  project           = var.project_id
  location          = var.region
  delivery_pipeline = google_clouddeploy_delivery_pipeline.backend.name
  name              = "auto-promote-to-prod"
  description       = "Promote a successful beta rollout to prod and wait for prod approval."
  suspended         = false
  service_account   = google_service_account.cloud_deploy_runner.email

  selector {
    targets {
      id = google_clouddeploy_target.beta.name
    }
  }

  rules {
    promote_release_rule {
      id                    = "promote-to-prod"
      destination_target_id = google_clouddeploy_target.prod.name
    }
  }

  depends_on = [
    google_clouddeploy_delivery_pipeline.backend,
    google_service_account_iam_member.runner_act_as_runner,
  ]
}
