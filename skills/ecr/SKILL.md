---
name: ecr
description: Manage Amazon ECR repositories, container images, lifecycle policies, and image scanning via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📦",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon ECR

Use this skill for container registry operations: creating and managing repositories, pushing and pulling images, configuring lifecycle policies, managing image scanning, and cross-account image sharing.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `ecr:*` for full access, or scoped policies
- Docker CLI installed for push/pull operations

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all repositories
aws ecr describe-repositories \
  --query 'repositories[].{Name:repositoryName,URI:repositoryUri,Created:createdAt,ScanOnPush:imageScanningConfiguration.scanOnPush}' \
  --output table

# List images in a repository
aws ecr describe-images \
  --repository-name <repo-name> \
  --query 'imageDetails[].{Tags:imageTags[0],Digest:imageDigest,Size:imageSizeInBytes,Pushed:imagePushedAt}' \
  --output table

# List images sorted by push date (most recent first)
aws ecr describe-images \
  --repository-name <repo-name> \
  --query 'sort_by(imageDetails, &imagePushedAt)[-10:].[imageTags[0], imagePushedAt, imageSizeInBytes]' \
  --output table

# Get repository policy
aws ecr get-repository-policy --repository-name <repo-name>

# Get lifecycle policy
aws ecr get-lifecycle-policy --repository-name <repo-name>

# Get image scan findings
aws ecr describe-image-scan-findings \
  --repository-name <repo-name> \
  --image-id imageTag=<tag> \
  --query 'imageScanFindings.findingSeverityCounts'

# Get ECR login password (for Docker auth)
aws ecr get-login-password --region <region>
```

### Push and Pull Images

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Tag and push an image
docker tag <local-image>:<tag> <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:<tag>
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:<tag>

# Pull an image
docker pull <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:<tag>
```

### Create / Update

⚠️ **Cost note:** $0.10/GB/month for storage. Data transfer out varies by region. No charge for data transfer within the same region to ECS/EKS.

```bash
# Create a repository
aws ecr create-repository \
  --repository-name <repo-name> \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Create with KMS encryption
aws ecr create-repository \
  --repository-name <repo-name> \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=KMS

# Create with image tag immutability (recommended for production)
aws ecr create-repository \
  --repository-name <repo-name> \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true

# Set a lifecycle policy (auto-clean old images)
aws ecr put-lifecycle-policy \
  --repository-name <repo-name> \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Keep only 20 most recent images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": {"type": "expire"}
    }]
  }'

# Set a lifecycle policy to expire untagged images after 1 day
aws ecr put-lifecycle-policy \
  --repository-name <repo-name> \
  --lifecycle-policy-text '{
    "rules": [{
      "rulePriority": 1,
      "description": "Remove untagged images after 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {"type": "expire"}
    }]
  }'

# Set repository policy (cross-account pull)
aws ecr set-repository-policy \
  --repository-name <repo-name> \
  --policy-text '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "AllowCrossAccountPull",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::<other-account-id>:root"},
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }]
  }'

# Tag a repository
aws ecr tag-resource \
  --resource-arn <repo-arn> \
  --tags Key=Environment,Value=production
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a specific image
aws ecr batch-delete-image \
  --repository-name <repo-name> \
  --image-ids imageTag=<tag>

# Delete an image by digest
aws ecr batch-delete-image \
  --repository-name <repo-name> \
  --image-ids imageDigest=<digest>

# Delete a repository (must be empty or use --force)
aws ecr delete-repository --repository-name <repo-name>

# Force delete a repository and ALL its images
aws ecr delete-repository --repository-name <repo-name> --force
```

## Safety Rules

1. **NEVER** delete a repository with `--force` without explicit user confirmation and listing images first.
2. **NEVER** expose or log AWS credentials, ECR login passwords, or image contents.
3. **ALWAYS** recommend image tag immutability for production repositories.
4. **ALWAYS** recommend scan-on-push for vulnerability detection.
5. **ALWAYS** recommend lifecycle policies to control storage costs.
6. **WARN** that ECR login tokens expire after 12 hours.

## Best Practices

- Enable scan-on-push and review findings before deploying images.
- Use image tag immutability in production to prevent tag overwrites.
- Set lifecycle policies to automatically clean up old/untagged images.
- Use KMS encryption for images containing sensitive content.
- Use repository policies for cross-account access instead of sharing credentials.

## Common Patterns

### Pattern: CI/CD Push Flow

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
REPO="myapp"
TAG=$(git rev-parse --short HEAD)

# Login
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# Build, tag, push
docker build -t $REPO:$TAG .
docker tag $REPO:$TAG $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG

# Also tag as latest
docker tag $REPO:$TAG $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
```

### Pattern: Find Vulnerable Images

```bash
# List all images with critical/high vulnerabilities
aws ecr describe-image-scan-findings \
  --repository-name <repo-name> \
  --image-id imageTag=latest \
  --query 'imageScanFindings.findings[?severity==`CRITICAL` || severity==`HIGH`].[name,severity,uri]' \
  --output table
```

### Pattern: Clean Up Untagged Images

```bash
# Find and delete all untagged images
UNTAGGED=$(aws ecr describe-images --repository-name <repo-name> \
  --query 'imageDetails[?!imageTags].imageDigest' --output text)

for DIGEST in $UNTAGGED; do
  aws ecr batch-delete-image --repository-name <repo-name> \
    --image-ids imageDigest=$DIGEST
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `RepositoryNotFoundException` | Repository doesn't exist in this region | Verify with `describe-repositories` and check region |
| `no basic auth credentials` | Docker not authenticated to ECR | Run `aws ecr get-login-password | docker login ...` |
| `denied: Your authorization token has expired` | ECR token expired (12hr limit) | Re-authenticate with `get-login-password` |
| `RepositoryNotEmptyException` | Deleting a repo that has images | Use `--force` flag or delete images first |
| `ImageTagAlreadyExistsException` | Tag immutability is on | Use a new tag or set mutability to MUTABLE |
| `LimitExceededException` | Too many repositories (default 10,000) | Request a limit increase or clean up unused repos |
