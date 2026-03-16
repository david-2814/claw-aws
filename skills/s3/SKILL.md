---
name: s3
description: Manage Amazon S3 buckets, objects, lifecycle policies, and access controls via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🪣",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon S3

Use this skill for any S3 operations: creating and managing buckets, uploading and downloading objects, configuring lifecycle rules, managing access policies, and analyzing storage usage.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `s3:*` for full access, or scoped policies for specific operations
- For cross-account access: appropriate bucket policies or IAM roles

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all buckets
aws s3 ls

# List objects in a bucket (with human-readable sizes)
aws s3 ls s3://<bucket-name>/ --human-readable --summarize

# List objects recursively
aws s3 ls s3://<bucket-name>/ --recursive --human-readable --summarize

# Get bucket location/region
aws s3api get-bucket-location --bucket <bucket-name>

# Check bucket versioning status
aws s3api get-bucket-versioning --bucket <bucket-name>

# Get bucket encryption configuration
aws s3api get-bucket-encryption --bucket <bucket-name>

# Get bucket policy
aws s3api get-bucket-policy --bucket <bucket-name> --output text | jq .

# Check public access block settings
aws s3api get-public-access-block --bucket <bucket-name>

# Get lifecycle configuration
aws s3api get-bucket-lifecycle-configuration --bucket <bucket-name>
```

### Upload and Download

```bash
# Upload a single file
aws s3 cp <local-file> s3://<bucket-name>/<key>

# Download a single file
aws s3 cp s3://<bucket-name>/<key> <local-path>

# Sync a local directory to S3
aws s3 sync <local-dir> s3://<bucket-name>/<prefix>/ --exclude "*.tmp"

# Sync S3 to local (download)
aws s3 sync s3://<bucket-name>/<prefix>/ <local-dir>

# Generate a presigned URL (default 1 hour)
aws s3 presign s3://<bucket-name>/<key> --expires-in 3600
```

### Create Bucket

⚠️ **Cost note:** S3 charges for storage, requests, and data transfer. Standard storage is ~$0.023/GB/month in us-east-1.

```bash
# Create a bucket (us-east-1 does not need LocationConstraint)
aws s3 mb s3://<bucket-name>

# Create a bucket in a specific region
aws s3api create-bucket \
  --bucket <bucket-name> \
  --region <region> \
  --create-bucket-configuration LocationConstraint=<region>

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket <bucket-name> \
  --versioning-configuration Status=Enabled

# Enable default encryption (recommended)
aws s3api put-bucket-encryption \
  --bucket <bucket-name> \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Block all public access (recommended)
aws s3api put-public-access-block \
  --bucket <bucket-name> \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a single object
aws s3 rm s3://<bucket-name>/<key>

# Delete all objects in a prefix (DANGEROUS)
aws s3 rm s3://<bucket-name>/<prefix>/ --recursive

# Empty and delete a bucket (VERY DANGEROUS — irreversible)
aws s3 rb s3://<bucket-name> --force
```

## Safety Rules

1. **NEVER** execute `s3 rm --recursive` or `s3 rb --force` without explicit user confirmation and repeating the bucket name back.
2. **NEVER** remove public access blocks without explaining the security implications.
3. **NEVER** expose or log AWS credentials, access keys, or secret keys.
4. **ALWAYS** confirm the target bucket and region before write operations.
5. **ALWAYS** recommend enabling versioning, encryption, and public access blocks on new buckets.
6. **WARN** before syncing with `--delete` flag, as it removes files at the destination.

## Best Practices

- Enable versioning on all buckets to protect against accidental deletes.
- Enable default encryption (SSE-S3 or SSE-KMS) on all buckets.
- Block public access unless explicitly required (and even then, prefer CloudFront).
- Use lifecycle rules to transition infrequently accessed data to S3-IA or Glacier.
- Use S3 Inventory and Storage Lens for visibility into large buckets.

## Common Patterns

### Pattern: Create a Production-Ready Bucket

```bash
BUCKET="my-app-data-$(date +%s)"
REGION="us-east-1"

# Create
aws s3api create-bucket --bucket $BUCKET --region $REGION

# Harden
aws s3api put-bucket-versioning --bucket $BUCKET \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket $BUCKET \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Pattern: Find Large Objects

```bash
aws s3api list-objects-v2 \
  --bucket <bucket-name> \
  --query 'sort_by(Contents, &Size)[-10:].[Key, Size]' \
  --output table
```

### Pattern: Cross-Account Copy

```bash
# Requires appropriate bucket policy or IAM role on both sides
aws s3 sync s3://<source-bucket>/ s3://<dest-bucket>/ \
  --source-region <src-region> \
  --region <dest-region>
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `AccessDenied` | Missing IAM permissions | Check IAM policy for required `s3:` actions |
| `BucketAlreadyExists` | Bucket name taken globally | S3 bucket names are globally unique — choose another name |
| `NoSuchBucket` | Bucket doesn't exist or wrong region | Verify bucket name and region with `aws s3api get-bucket-location` |
| `AllAccessDisabled` | Public access block is on | Check `get-public-access-block` — this is usually intentional |
