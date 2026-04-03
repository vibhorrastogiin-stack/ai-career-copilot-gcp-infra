# Terraform Notes

Use the beta root at:

- `gcp/terraform/environments/beta`

The current Terraform provisions the backend-side beta stack:

- project services
- Firestore
- Cloud Storage
- Pub/Sub contact notifications
- Artifact Registry
- Secret Manager secret placeholders
- Cloud Run backend

It does not yet provision:

- Firebase App Hosting
- custom domains
- CI/CD triggers

## Expected Inputs

See:

- `gcp/terraform/environments/beta/terraform.tfvars.example`

## Important Outputs

After apply, note:

- `backend_url`
- `backend_service_account_email`
- `content_bucket_name`
- `contact_bucket_name`
- `contact_notifications_topic`
- `contact_notifications_subscription`
- `artifact_registry_repository`

The backend service account needs access through Terraform-managed roles already included in the beta stack:

- `roles/datastore.user`
- `roles/storage.objectAdmin`
- `roles/secretmanager.secretAccessor`
