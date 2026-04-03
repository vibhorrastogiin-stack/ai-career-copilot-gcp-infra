# Backend AWS to GCP Mapping

This document maps the current backend's AWS integrations to concrete GCP replacements and identifies the code that needs to change.

## Current Backend Runtime Dependencies

### AWS SDK Clients

Current classes:

- `src/main/java/com/edlabs/copilot/config/AwsConfig.java`
- `src/main/java/com/edlabs/copilot/config/DynamoDbConfig.java`

Current runtime clients:

- `S3Client`
- `SesClient`
- `DynamoDbClient`
- `DynamoDbEnhancedClient`

### AWS-Backed Services and Repositories

#### S3-backed

- `S3ContentService`
- `OnboardingService`
- `DiagnosisService`
- `MockInterviewSessionS3Service`
- `MockInterviewQuestionBankService`
- portions of roadmap/playbook/task content loading
- `ContactService` for contact payload persistence
- `UserDeletionRepository` for deleting S3-backed user artifacts

#### DynamoDB-backed

- `UserStateRepository`
- `RoadmapV2Repository`
- `ActiveSessionRepository`
- `UserDeletionRepository` audit + deletion queries

#### SES-backed

- `ContactService`

## Target GCP Replacements

### 1. S3 -> Cloud Storage

Use Cloud Storage for:

- playbook/task catalog content
- onboarding snapshots
- diagnosis snapshots and version markers
- mock interview session payloads
- question bank objects
- contact JSON payloads

Recommended replacement class:

- `GcsContentService`

This should replace `S3ContentService` as the central object storage abstraction.

### 2. DynamoDB -> Firestore

Use Firestore for:

- user profile
- entitlements
- roadmap plan metadata
- user skill progress
- active mock interview session pointers
- audit logs

Recommended replacement repositories:

- `FirestoreUserStateRepository`
- `FirestoreRoadmapRepository`
- `FirestoreActiveSessionRepository`
- `FirestoreUserDeletionRepository`

### 3. SES -> SendGrid

Use SendGrid for:

- contact notification email
- any future transactional mail

Recommended replacement:

- `EmailSender` interface
- `SendGridEmailSender` implementation

## Class-by-Class Mapping

## Configuration Layer

### Current

- `AwsConfig`
- `DynamoDbConfig`

### Replace With

- `GcpStorageConfig`
- `FirestoreConfig`
- `EmailConfig`

Expected beans:

- `Storage`
- `Firestore`
- `SendGrid client` or thin HTTP sender

## Object Storage Layer

### Current

- `S3ContentService`

Responsibilities:

- read/write msgpack
- read JSON / JSON list
- delete objects
- delete by prefix

### Replace With

- `CloudStorageContentService`

Keep the same functional surface:

- `readMsgpack`
- `readMsgpackList`
- `readJson`
- `readJsonList`
- `writeMsgpack`
- `deleteObject`
- `deleteByPrefix`

That allows most service-layer code to migrate with minimal churn first.

## User State

### Current

- `UserStateRepository`

Current behaviors:

- get/save user profile
- get/save entitlements
- lookup by auth provider/providerId

### Replace With

- `FirestoreUserStateRepository`

Recommended Firestore layout:

- `users/{userId}`
  - profile fields
- `users/{userId}/entitlements/{entitlementId}`

Provider lookup:

- either store reverse lookup in a dedicated collection
- or use a queryable field/index in `users`

Recommended:

- collection: `users`
- fields: `authProvider`, `authProviderId`
- query with composite/indexed fields

## Roadmap State

### Current

- `RoadmapV2Repository`

Current behaviors:

- get/save one user plan
- get/save per-skill progress
- list all skills

### Replace With

- `FirestoreRoadmapRepository`

Recommended structure:

- `users/{userId}/roadmap/current`
- `users/{userId}/skills/{skillId}`

This is a cleaner fit than emulating `pk/sk`.

## Active Mock Interview Session Pointer

### Current

- `ActiveSessionRepository`

### Replace With

- `FirestoreActiveSessionRepository`

Recommended structure:

- `users/{userId}/mock_interview_state/current`

This is a tiny document and a good Firestore fit.

## Onboarding Snapshot

### Current

- `OnboardingService`
- stores onboarding snapshot in S3 via `S3ContentService`

### Recommendation

Keep this in object storage initially.

Reason:

- it is already blob-like
- keeping it in Cloud Storage reduces the number of moving parts in the first pass

Potential later move to Firestore is possible, but not necessary for beta launch.

## Diagnosis

### Current

- `DiagnosisService`
- stores diagnosis snapshots and latest-version marker in S3

### Recommendation

Keep diagnosis snapshots in Cloud Storage for first migration pass.

Reason:

- versioned document/blob pattern already exists
- current service logic is simple to port if object storage semantics stay the same

Later, you may move diagnosis metadata to Firestore if querying becomes more important.

## Mock Interview Session Payloads

### Current

- `MockInterviewSessionS3Service`
- stores session payloads in S3
- lists session IDs by S3 prefix and object last-modified

### Recommendation

Keep full session payloads in Cloud Storage for first pass.

Add Firestore metadata only if needed later for richer querying.

Direct GCS mapping:

- `users/{userId}/mock-interview/{sessionId}.msgpack`

Behavior to reimplement:

- list by prefix
- sort by update time
- read payload by object key

## Contact Submissions

### Current

- `ContactService`
- save JSON to S3
- send notification through SES

### Replace With

- save JSON to Cloud Storage
- send notification with SendGrid

This is straightforward and should be one of the first migrations.

## User Deletion / Reset

### Current

- `UserDeletionRepository`
- deletes DynamoDB items by `pk/sk`
- deletes diagnosis/onboarding blobs in S3
- stores audit logs in DynamoDB

### Replace With

- `FirestoreUserDeletionRepository`
- `CloudStorageContentService` for blob deletion

This will require a more explicit delete strategy because Firestore is not organized around a single-table `pk/sk` sweep.

Recommended structure will make deletion simpler:

- delete `users/{userId}` root doc
- delete subcollections:
  - entitlements
  - roadmap
  - skills
  - audits
  - mock_interview_state
- delete GCS prefixes:
  - onboarding
  - diagnosis
  - mock interview payloads

## Recommended Migration Order

### Slice 1: Configuration and Object Storage

Implement:

- GCP config classes
- `CloudStorageContentService`

Then port:

- `OnboardingService`
- `DiagnosisService`
- `MockInterviewSessionS3Service`
- `MockInterviewQuestionBankService`
- playbook/task content reads

This gets a large part of the backend off AWS without touching the hardest repository logic first.

### Slice 2: Contact Flow

Implement:

- `EmailSender`
- `SendGridEmailSender`

Then port:

- `ContactService`

This is isolated and low risk.

### Slice 3: Firestore User and Roadmap State

Implement:

- `FirestoreUserStateRepository`
- `FirestoreRoadmapRepository`
- `FirestoreActiveSessionRepository`

Then port:

- auth/user services
- roadmap services
- home controller dependency path
- mock interview active-session path

### Slice 4: Deletion and Reset

Port:

- `UserDeletionRepository`
- reset/delete workflows

This should come after the new storage model is stable.

## Recommended First Implementation Slice

Start with:

1. `CloudStorageContentService`
2. `ContactService` -> GCS + SendGrid
3. `OnboardingService`
4. `DiagnosisService`

Reason:

- highest leverage
- lowest schema redesign pressure
- immediately reduces AWS lock-in significantly

## Code-Level Architectural Recommendation

Before porting repository-by-repository, introduce interfaces where needed.

Suggested interfaces:

- `ContentStore`
- `UserStateStore`
- `RoadmapStateStore`
- `ActiveSessionStore`
- `AuditLogStore`
- `EmailSender`

Then wire GCP implementations behind those interfaces.

This keeps the service layer stable and makes the migration testable.

## Conclusion

The backend migration is not "replace AWS SDK imports."

The practical path is:

- first replace S3-style content access with Cloud Storage
- then replace DynamoDB repositories with Firestore-native repositories
- then finalize deletion/reset and operational flows

That sequence minimizes risk while keeping the codebase coherent.
