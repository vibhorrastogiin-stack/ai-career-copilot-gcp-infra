# AI Career Copilot GCP Infrastructure

Greenfield Google Cloud infrastructure for AI Career Copilot.

This repo is intentionally separate from the AWS CDK repo because the target platform and IaC approach are different enough that a parallel migration track is cleaner than trying to evolve the AWS repo in place.

## Target Stack

- Frontend: Firebase App Hosting
- Backend: Cloud Run
- App state: Firestore
- Object storage: Cloud Storage
- Secrets: Secret Manager
- Images: Artifact Registry
- CI/CD: Cloud Build
- IaC: Terraform

## Scope

Current scope is:

1. Stand up foundational GCP infrastructure for beta.
2. Provide a clean place to iterate on GCP deployment without touching AWS CDK.
3. Document the backend integration changes needed to run on GCP services.

Out of scope for now:

- live data migration from AWS
- production cutover
- CI/CD triggers and deployment automation details beyond the initial scaffold

## Directory Layout

- `gcp/terraform/environments/beta`: beta environment root module
- `gcp/terraform/modules`: reusable Terraform modules
- `BACKEND_GCP_PORTING.md`: application-layer changes required in the backend
- `gcp/terraform/environments/beta/terraform.tfvars.example`: example beta inputs

## Environment Model

GCP projects:

- `ai-career-copilot-beta`
- `ai-career-copilot-prod`

Region:

- `us-west1`

Usage model:

- local MacBook development uses beta GCP resources
- beta testing uses beta GCP resources
- production uses prod GCP resources

This keeps the environment model simple:

- no separate dev GCP project for now
- no AWS data migration path
- no local-only cloud namespace for now

## Immediate Next Steps

1. Create and configure the `ai-career-copilot-beta` GCP project in `us-west1`.
2. Populate Secret Manager with backend secrets.
3. Apply the beta Terraform environment.
4. Build and push the backend image into Artifact Registry.
5. Deploy the frontend to Firebase App Hosting.

## Beta Runtime Shape

The beta Terraform now provisions:

- Artifact Registry repository for the backend image
- Cloud Storage buckets for app content and contact payloads
- Firestore `(default)` database in Native mode
- Secret Manager placeholders for:
  - `jwt-secret`
  - `google-client-id`
  - `google-client-secret`
  - `openai-api-key`
  - `sendgrid-api-key`
- Cloud Run service wired with:
  - `APP_STATE_PROVIDER=gcp`
  - `APP_STORAGE_PROVIDER=gcp`
  - `APP_EMAIL_PROVIDER=sendgrid`
  - GCS bucket names
  - frontend URL
  - Secret Manager-backed env vars for auth, OpenAI, and SendGrid

## Manual Prerequisites

Before deploy, set up these external dependencies:

1. GCP project
- project id: `ai-career-copilot-beta`
- region: `us-west1`
- billing enabled

2. Google OAuth application
- add the backend callback URL:
  - `https://<cloud-run-backend-url>/login/oauth2/code/google`
- add the frontend origin and login flow URLs as needed in the Google OAuth client

3. SendGrid
- create an API key
- verify the sender domain or sender identity for `APP_FROM_EMAIL`

4. DNS / frontend URL
- decide the beta frontend URL before Terraform apply
- example: `https://beta.careermake.ai`

## Deploy Sequence

1. Copy the example tfvars:

```bash
cp gcp/terraform/environments/beta/terraform.tfvars.example gcp/terraform/environments/beta/terraform.tfvars
```

2. Fill in:
- `project_id`
- `backend_image`
- `frontend_url`
- email values if different

3. Apply Terraform:

```bash
cd gcp/terraform/environments/beta
terraform init
terraform apply
```

4. Create secret versions for all required secrets after the secrets exist:

```bash
gcloud secrets versions add jwt-secret --data-file=-
gcloud secrets versions add google-client-id --data-file=-
gcloud secrets versions add google-client-secret --data-file=-
gcloud secrets versions add openai-api-key --data-file=-
gcloud secrets versions add sendgrid-api-key --data-file=-
```

5. Build and push backend image to Artifact Registry.

6. Re-apply Terraform with the final image URL if needed.

7. Add the real Cloud Run backend URL to the Google OAuth client callback list.

8. Smoke test:
- OAuth login
- onboarding completion
- diagnosis generation
- roadmap generation
- contact form
- beta feedback
