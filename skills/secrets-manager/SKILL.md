---
name: secrets-manager
description: Manage AWS Secrets Manager secrets, rotation, versioning, and cross-account sharing via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔐",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Secrets Manager

Use this skill for secrets management: creating and retrieving secrets, configuring automatic rotation, managing secret versions, cross-account access, and auditing secret usage.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `secretsmanager:*` for full access, or scoped policies
- For rotation: Lambda function with appropriate permissions

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all secrets
aws secretsmanager list-secrets \
  --query 'SecretList[].{Name:Name,ARN:ARN,LastChanged:LastChangedDate,Rotation:RotationEnabled}' \
  --output table

# List secrets with a name filter
aws secretsmanager list-secrets \
  --filters Key=name,Values=<prefix>

# Describe a secret (metadata, no value)
aws secretsmanager describe-secret --secret-id <secret-name-or-arn>

# Get the current secret value
aws secretsmanager get-secret-value --secret-id <secret-name-or-arn> \
  --query 'SecretString' --output text

# Get a specific version
aws secretsmanager get-secret-value \
  --secret-id <secret-name-or-arn> \
  --version-stage AWSPREVIOUS

# Get secret value by version ID
aws secretsmanager get-secret-value \
  --secret-id <secret-name-or-arn> \
  --version-id <version-id>

# Get the resource policy
aws secretsmanager get-resource-policy --secret-id <secret-name-or-arn>

# List secret version IDs
aws secretsmanager list-secret-version-ids --secret-id <secret-name-or-arn> \
  --query 'Versions[].{VersionId:VersionId,Stages:VersionStages,Created:CreatedDate}' \
  --output table
```

⚠️ **CRITICAL: Never display secret values in chat or logs. Always ask the user how they want the value delivered (e.g., piped to a file, set as env var).**

### Create / Update

⚠️ **Cost note:** $0.40/secret/month + $0.05 per 10,000 API calls.

```bash
# Create a secret (string)
aws secretsmanager create-secret \
  --name <secret-name> \
  --description "<description>" \
  --secret-string '<secret-value>'

# Create a secret (JSON key-value pairs — common for DB credentials)
aws secretsmanager create-secret \
  --name <secret-name> \
  --secret-string '{
    "username": "<user>",
    "password": "<pass>",
    "host": "<hostname>",
    "port": 5432,
    "dbname": "<database>"
  }'

# Create a secret from a file
aws secretsmanager create-secret \
  --name <secret-name> \
  --secret-binary fileb://<path-to-file>

# Update a secret value
aws secretsmanager update-secret \
  --secret-id <secret-name-or-arn> \
  --secret-string '<new-value>'

# Put a new version (with staging label)
aws secretsmanager put-secret-value \
  --secret-id <secret-name-or-arn> \
  --secret-string '<value>' \
  --version-stages AWSCURRENT

# Tag a secret
aws secretsmanager tag-resource \
  --secret-id <secret-name-or-arn> \
  --tags Key=Environment,Value=production Key=Team,Value=backend

# Add a resource policy (cross-account access)
aws secretsmanager put-resource-policy \
  --secret-id <secret-name-or-arn> \
  --resource-policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::<account-id>:root"},
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*"
    }]
  }'
```

### Rotation

```bash
# Enable rotation with a Lambda function
aws secretsmanager rotate-secret \
  --secret-id <secret-name-or-arn> \
  --rotation-lambda-arn <lambda-arn> \
  --rotation-rules '{"AutomaticallyAfterDays": 30}'

# Trigger immediate rotation
aws secretsmanager rotate-secret --secret-id <secret-name-or-arn>

# Cancel rotation
aws secretsmanager cancel-rotate-secret --secret-id <secret-name-or-arn>
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Schedule deletion (default 30-day recovery window)
aws secretsmanager delete-secret \
  --secret-id <secret-name-or-arn> \
  --recovery-window-in-days 30

# Force delete immediately (NO RECOVERY)
aws secretsmanager delete-secret \
  --secret-id <secret-name-or-arn> \
  --force-delete-without-recovery

# Restore a secret scheduled for deletion
aws secretsmanager restore-secret --secret-id <secret-name-or-arn>
```

⚠️ **Prefer `--recovery-window-in-days 30` over `--force-delete-without-recovery`. The recovery window allows restoring accidentally deleted secrets.**

## Safety Rules

1. **NEVER** display secret values directly in chat responses or logs.
2. **NEVER** use `--force-delete-without-recovery` without explicit user confirmation and explaining the risk.
3. **NEVER** expose or log AWS credentials, access keys, or secret keys.
4. **ALWAYS** use the recovery window (minimum 7 days) when deleting secrets.
5. **ALWAYS** recommend encryption with a customer-managed KMS key for sensitive secrets.
6. **RECOMMEND** piping secret values to files or env vars rather than displaying them.

## Best Practices

- Use automatic rotation for database credentials (30-day cycles minimum).
- Use customer-managed KMS keys for secrets requiring audit trails.
- Use resource policies for cross-account access instead of sharing credentials.
- Tag secrets with environment, team, and application for governance.
- Monitor secret access with CloudTrail and set up alerts for unusual patterns.

## Common Patterns

### Pattern: Store and Retrieve DB Credentials

```bash
# Store
aws secretsmanager create-secret \
  --name prod/myapp/db \
  --secret-string '{"username":"admin","password":"s3cur3P@ss","host":"mydb.cluster-xxx.us-east-1.rds.amazonaws.com","port":5432,"dbname":"myapp"}'

# Retrieve and use in a script
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id prod/myapp/db --query SecretString --output text)
DB_HOST=$(echo $DB_SECRET | jq -r '.host')
DB_USER=$(echo $DB_SECRET | jq -r '.username')
DB_PASS=$(echo $DB_SECRET | jq -r '.password')
```

### Pattern: Rotate and Verify

```bash
# Trigger rotation
aws secretsmanager rotate-secret --secret-id <secret-name>

# Check rotation status
aws secretsmanager describe-secret --secret-id <secret-name> \
  --query '{LastRotated:LastRotatedDate,NextRotation:NextRotationDate,Status:RotationEnabled}'

# Verify both AWSCURRENT and AWSPREVIOUS exist
aws secretsmanager list-secret-version-ids --secret-id <secret-name> \
  --query 'Versions[?VersionStages]'
```

### Pattern: Bulk Export Secret Names (Not Values)

```bash
aws secretsmanager list-secrets \
  --query 'SecretList[].{Name:Name,Description:Description,LastChanged:LastChangedDate}' \
  --output json > secrets-inventory.json
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFoundException` | Secret doesn't exist or was deleted | Check with `list-secrets`; may be pending deletion (use `restore-secret`) |
| `DecryptionFailure` | KMS key access denied | Verify IAM policy includes `kms:Decrypt` for the secret's KMS key |
| `ResourceExistsException` | Secret name already taken | Use a different name or update the existing secret |
| `InvalidRequestException` on delete | Secret is scheduled for deletion | Restore first with `restore-secret`, then modify or re-delete |
| Rotation fails | Lambda function error or permissions | Check Lambda logs in CloudWatch; verify Lambda has `secretsmanager:*` and network access |
| `PreconditionNotMetException` | Version staging conflict | Another rotation may be in progress; wait and retry |
