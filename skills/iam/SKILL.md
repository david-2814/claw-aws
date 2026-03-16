---
name: iam
description: Audit and manage AWS IAM users, roles, policies, and access controls via AWS CLI. Security-first by default.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔐",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS IAM

Use this skill for Identity and Access Management operations: auditing users and roles, creating and attaching policies, managing access keys, and analyzing permissions. **This skill defaults to read-only auditing.** Write operations require extra caution.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `iam:*` for full access (ideally scoped for production)
- Note: IAM is a **global** service — no region parameter needed

## Common Operations

### Audit and Inspect (Read-Only)

```bash
# Get current caller identity (who am I?)
aws sts get-caller-identity

# List all users
aws iam list-users --query 'Users[].[UserName, CreateDate, PasswordLastUsed]' --output table

# List all roles
aws iam list-roles --query 'Roles[].[RoleName, CreateDate]' --output table

# List policies attached to a user
aws iam list-attached-user-policies --user-name <user>
aws iam list-user-policies --user-name <user>  # inline policies

# List policies attached to a role
aws iam list-attached-role-policies --role-name <role>

# Get a policy's current version document
POLICY_ARN="arn:aws:iam::<account-id>:policy/<policy-name>"
VERSION=$(aws iam get-policy --policy-arn $POLICY_ARN --query 'Policy.DefaultVersionId' --output text)
aws iam get-policy-version --policy-arn $POLICY_ARN --version-id $VERSION \
  --query 'PolicyVersion.Document' --output json

# List access keys for a user
aws iam list-access-keys --user-name <user> \
  --query 'AccessKeyMetadata[].[AccessKeyId, Status, CreateDate]' --output table

# Get last accessed info for a policy
aws iam generate-service-last-accessed-details --arn <policy-arn>
# Then poll:
aws iam get-service-last-accessed-details --job-id <job-id>

# Get account authorization details (comprehensive dump)
aws iam get-account-authorization-details --output json > iam-dump.json

# Get account summary (counts of users, roles, policies, MFA, etc.)
aws iam get-account-summary

# Generate credential report
aws iam generate-credential-report
aws iam get-credential-report --query 'Content' --output text | base64 -d > credentials.csv
```

### Security Audits

```bash
# Find users without MFA
aws iam generate-credential-report > /dev/null 2>&1 && sleep 5
aws iam get-credential-report --query 'Content' --output text | base64 -d | \
  awk -F, 'NR>1 && $4=="true" && $8=="false" {print "NO MFA:", $1}'

# Find old access keys (>90 days)
for user in $(aws iam list-users --query 'Users[].UserName' --output text); do
  aws iam list-access-keys --user-name $user \
    --query "AccessKeyMetadata[?CreateDate<='$(date -u -d '90 days ago' +%Y-%m-%d)'].[\"$user\", AccessKeyId, CreateDate, Status]" \
    --output text
done

# Find policies with wildcard actions (overly permissive)
# Best done by reviewing get-account-authorization-details output

# Check if root account has access keys (should not)
aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent'
```

### Create / Modify (Use With Caution)

⚠️ **IAM changes are global and take effect immediately.** A misconfigured policy can lock you out or expose your account.

```bash
# Create a role for a service
aws iam create-role \
  --role-name my-app-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --description "Execution role for my-app Lambda"

# Attach a managed policy to a role
aws iam attach-role-policy \
  --role-name my-app-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create a scoped custom policy
aws iam create-policy \
  --policy-name my-app-s3-read \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-app-bucket",
        "arn:aws:s3:::my-app-bucket/*"
      ]
    }]
  }'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — IAM deletions can break applications and lock out users. Always confirm.**

```bash
# Detach policy from role
aws iam detach-role-policy --role-name <role> --policy-arn <policy-arn>

# Delete a role (must detach all policies and remove from instance profiles first)
aws iam delete-role --role-name <role>

# Delete a policy (must detach from all entities first)
aws iam delete-policy --policy-arn <policy-arn>

# Deactivate an access key (prefer this over deletion)
aws iam update-access-key --user-name <user> --access-key-id <key-id> --status Inactive

# Delete an access key
aws iam delete-access-key --user-name <user> --access-key-id <key-id>
```

## Safety Rules

1. **NEVER** create IAM policies with `"Action": "*"` or `"Resource": "*"` unless explicitly required and acknowledged.
2. **NEVER** create or display access keys in chat — direct the user to do this themselves.
3. **NEVER** attach `AdministratorAccess` without explicit discussion of the security implications.
4. **ALWAYS** follow least privilege — grant only the permissions needed for the task.
5. **ALWAYS** recommend conditions (e.g., `aws:SourceIp`, `aws:MultiFactorAuthPresent`) on sensitive policies.
6. **ALWAYS** suggest enabling MFA for human users.
7. **PREFER** deactivating access keys over deleting them (easier to recover if a mistake is made).
8. **WARN** that IAM changes are global and immediate — there is no region isolation.

## Best Practices

- Use roles, not long-lived access keys, for applications and services.
- Enable MFA for all human users, especially those with console access.
- Use AWS Organizations SCPs for guardrails across accounts.
- Rotate access keys regularly (every 90 days) and remove unused credentials.
- Use IAM Access Analyzer to identify unintended public or cross-account access.
- Tag IAM resources for auditing and cost attribution.

## Common Patterns

### Pattern: Least-Privilege Role for a Lambda

```bash
# 1. Create the trust policy
aws iam create-role --role-name my-func-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# 2. Attach only what's needed
aws iam put-role-policy --role-name my-func-role --policy-name my-func-perms \
  --policy-document '{
    "Version":"2012-10-17",
    "Statement":[
      {"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"arn:aws:logs:*:*:*"},
      {"Effect":"Allow","Action":["s3:GetObject"],"Resource":"arn:aws:s3:::my-bucket/*"}
    ]
  }'
```

### Pattern: Quick Security Audit

```bash
echo "=== Account Summary ==="
aws iam get-account-summary --output table

echo "=== Root Access Keys (should be 0) ==="
aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent'

echo "=== MFA Status ==="
aws iam get-account-summary --query 'SummaryMap.[MFADevicesInUse, Users]'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `AccessDenied` | Caller lacks IAM permissions | Check the caller's own IAM policy |
| `MalformedPolicyDocument` | JSON syntax error in policy | Validate JSON; check for missing commas or brackets |
| `DeleteConflict` | Entity still has attachments | Detach all policies and remove from groups/profiles first |
| `EntityAlreadyExists` | Name already taken | Use a different name or check for the existing resource |
| `LimitExceeded` | Account hit IAM quotas | Request a limit increase via Service Quotas |
