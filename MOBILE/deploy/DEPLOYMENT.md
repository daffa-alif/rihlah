# RIHLAH MVP Deployment Guide

## Architecture

```
                    ┌──────────────────────────┐
                    │   Firebase Hosting        │
                    │   (Admin Web Console)     │
                    └──────────────────────────┘
                              │
     ┌────────────────────────┼──────────────────────────┐
     │                        │                          │
     ▼                        ▼                          ▼
┌──────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ Firebase │   │  Cloud Run API        │   │  Cloud Run Matcher   │
│ Auth     │   │  (asia-southeast2)    │   │  (asia-southeast2)   │
│ RTDB     │   │  NestJS, port 8080    │   │  port 8081           │
│ Firestore│   └──────────┬───────────┘   └──────────┬───────────┘
│ Storage  │              │                          │
│ FCM      │     ┌────────┴──────────┐     ┌─────────┴──────────┐
└──────────┘     │  Cloud SQL        │     │  Memorystore       │
                 │  PostgreSQL 15    │     │  Redis 7           │
                 │  + PostGIS 3.4    │     │                    │
                 └───────────────────┘     └────────────────────┘
```

## Prerequisites

1. **GCP project** with billing enabled
2. **Firebase project** linked to the same GCP project
3. **gcloud CLI** installed and configured
4. **Firebase CLI** installed (`npm i -g firebase-tools`)
5. **Docker** installed (for local testing)
6. Domain: `rihlah.id` (or `rihlah.web.app` for Firebase Hosting)

## Step 1: Provision Database

```bash
# Cloud SQL PostgreSQL 15 + PostGIS
gcloud sql instances create rihlah-db \
  --region=asia-southeast2 \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --storage-size=10GB

# Enable PostGIS extension
gcloud sql databases create rihlah --instance=rihlah-db

# Create user
gcloud sql users create rihlah \
  --instance=rihlah-db \
  --password=<secure-password>

# Get connection name for Secret Manager
gcloud sql instances describe rihlah-db --format='value(connectionName)'
```

## Step 2: Provision Redis

```bash
gcloud redis instances create rihlah-redis \
  --region=asia-southeast2 \
  --tier=basic \
  --size=1
```

## Step 3: Configure Secrets

```bash
# Store all secrets in Secret Manager
echo -n "postgresql://rihlah:<password>@localhost:5432/rihlah?host=/cloudsql/<connection-name>" | \
  gcloud secrets create DATABASE_URL --data-file=-

echo -n "<redis-ip>:6379" | \
  gcloud secrets create REDIS_URL --data-file=-

# Generate encryption key
openssl rand -hex 32 | gcloud secrets create ENCRYPTION_KEY --data-file=-

# Midtrans keys
echo -n "Mid-server-..." | gcloud secrets create MIDTRANS_SERVER_KEY --data-file=-
echo -n "Mid-client-..." | gcloud secrets create MIDTRANS_CLIENT_KEY --data-file=-

# Grant Cloud Run service account access
gcloud secrets add-iam-policy-binding DATABASE_URL \
  --member="serviceAccount:rihlah-api@<project>.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
# ... repeat for all secrets
```

## Step 4: Run Database Migrations

```bash
cd backend
DATABASE_URL="<from-secret-manager>" npx prisma migrate deploy
DATABASE_URL="<from-secret-manager>" npx prisma db seed
```

## Step 5: Deploy Backend

```bash
# Build and deploy API
gcloud builds submit backend/ --tag gcr.io/<project>/rihlah-api
gcloud run deploy rihlah-api \
  --image gcr.io/<project>/rihlah-api \
  --region asia-southeast2 \
  --platform managed \
  --allow-unauthenticated \
  --set-cloudsql-instances=<connection-name> \
  --vpc-connector=rihlah-vpc \
  --set-secrets=DATABASE_URL=DATABASE_URL:latest,REDIS_URL=REDIS_URL:latest,ENCRYPTION_KEY=ENCRYPTION_KEY:latest,MIDTRANS_SERVER_KEY=MIDTRANS_SERVER_KEY:latest,MIDTRANS_CLIENT_KEY=MIDTRANS_CLIENT_KEY:latest,TWILIO_ACCOUNT_SID=TWILIO_ACCOUNT_SID:latest,TWILIO_AUTH_TOKEN=TWILIO_AUTH_TOKEN:latest

# Deploy matching worker
gcloud builds submit backend/ --tag gcr.io/<project>/rihlah-matching-worker
gcloud run deploy rihlah-matching-worker \
  --image gcr.io/<project>/rihlah-matching-worker \
  --region asia-southeast2 \
  --platform managed \
  --set-cloudsql-instances=<connection-name> \
  --vpc-connector=rihlah-vpc \
  --set-secrets=DATABASE_URL=DATABASE_URL:latest,REDIS_URL=REDIS_URL:latest
```

## Step 6: Deploy Firebase

```bash
# Cloud Function
cd functions
npm ci && npm run build
firebase deploy --only functions

# Firestore + RTDB rules
firebase deploy --only firestore:rules
firebase deploy --only database:rules

# Admin console (Flutter Web)
cd ..
flutter build web -t lib/main_admin.dart
firebase deploy --only hosting
```

## Step 7: Deploy Flutter App

```bash
# Build Android APK
flutter build apk --release \
  --dart-define=USE_API=true \
  --dart-define=API_BASE_URL=https://rihlah-api-xxxxx-as.a.run.app/api/v1

# Sign the APK (configure in android/app/build.gradle first)
# Upload to Play Console internal testing track
```

## Step 8: Verify

```bash
# Health check
curl https://rihlah-api-xxxxx-as.a.run.app/api/v1/health

# Test auth flow
# 1. Install APK on test phone
# 2. Sign in with Firebase Phone Auth
# 3. Create a booking
# 4. Verify Firestore has trip doc
# 5. Accept from driver phone
# 6. Complete trip
# 7. Verify payment webhook
```

## Rollback

```bash
# Rollback Cloud Run to previous revision
gcloud run revisions list --service=rihlah-api --region=asia-southeast2
gcloud run services update-traffic rihlah-api \
  --to-revisions=<previous-revision>=100 \
  --region=asia-southeast2

# Rollback database migration
cd backend
DATABASE_URL="..." npx prisma migrate resolve --rolled-back <migration-name>
```
