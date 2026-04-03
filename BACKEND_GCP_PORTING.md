# Backend GCP Porting Notes

The backend is the real migration work. Infra alone is not enough.

## Current AWS Coupling

The backend currently depends on:

- DynamoDB-style repositories with `pk` / `sk` patterns
- S3 content and upload storage
- AWS-oriented configuration and credentials
- SES for email

## Target GCP Replacements

- DynamoDB -> Firestore
- S3 -> Cloud Storage
- Secrets Manager -> Secret Manager
- SES -> SendGrid

## Recommended Porting Order

1. Introduce storage interfaces if any concrete AWS clients still leak into service logic.
2. Replace S3 content service with Cloud Storage implementation.
3. Replace DynamoDB repositories with Firestore repositories.
4. Replace SES email sender with SendGrid sender.
5. Update configuration loading for Secret Manager or environment variables.
6. Deploy backend container to Cloud Run.

## Important Design Rule

Do not reproduce the DynamoDB single-table design literally in Firestore.

Instead, move to aggregate-oriented collections such as:

- `users/{userId}`
- `users/{userId}/onboarding/{version}`
- `users/{userId}/diagnoses/{version}`
- `users/{userId}/roadmaps/{version}`
- `users/{userId}/skills/{skillId}`
- `users/{userId}/audits/{auditId}`

## Beta Deployment Assumption

Because the product is not live yet, this migration can be treated as a greenfield deployment:

- no dual-write
- no AWS-to-GCP sync layer
- no historical data transfer required for launch

## Environment Assumption

- local development uses the beta GCP project directly
- beta and local share the same non-production cloud resources for now
- production will use a separate project: `ai-career-copilot-prod`
