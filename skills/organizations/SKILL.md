---
name: organizations
description: Manage AWS Organizations accounts, OUs, SCPs, and delegated administration via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🏛️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Organizations

Use this skill for multi-account management: viewing organization structure, managing organizational units (OUs), creating and managing accounts, applying service control policies (SCPs), and configuring delegated administration.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- Must be run from the **management account** (or delegated admin for some operations)
- IAM permissions: `organizations:*` for full access

## Common Operations

### List and Inspect (Read-Only)

```bash
# Describe the organization
aws organizations describe-organization

# List all accounts
aws organizations list-accounts \
  --query 'Accounts[*].[Id,Name,Email,Status,JoinedTimestamp]' --output table

# Describe an account
aws organizations describe-account --account-id <account-id>

# List roots
aws organizations list-roots \
  --query 'Roots[*].[Id,Name,PolicyTypes[*].Type]' --output table

# List organizational units under a parent
aws organizations list-organizational-units-for-parent --parent-id <root-or-ou-id> \
  --query 'OrganizationalUnits[*].[Id,Name]' --output table

# List accounts in an OU
aws organizations list-accounts-for-parent --parent-id <ou-id> \
  --query 'Accounts[*].[Id,Name,Status]' --output table

# List children (OUs + accounts) under a parent
aws organizations list-children --parent-id <parent-id> --child-type ACCOUNT --output table
aws organizations list-children --parent-id <parent-id> --child-type ORGANIZATIONAL_UNIT --output table

# Describe an OU
aws organizations describe-organizational-unit --organizational-unit-id <ou-id>

# List policies
aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[*].[Id,Name,Type,AwsManaged]' --output table

# Describe a policy
aws organizations describe-policy --policy-id <policy-id>

# List policies attached to a target
aws organizations list-policies-for-target --target-id <ou-or-account-id> --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[*].[Id,Name]' --output table

# List targets for a policy
aws organizations list-targets-for-policy --policy-id <policy-id> \
  --query 'Targets[*].[TargetId,Name,Type]' --output table

# List enabled AWS service access
aws organizations list-aws-service-access-for-organization \
  --query 'EnabledServicePrincipals[*].[ServicePrincipal,DateEnabled]' --output table

# List delegated administrators
aws organizations list-delegated-administrators --output table

# List handshakes
aws organizations list-handshakes-for-organization --output table
```

### Manage OUs and Accounts

⚠️ **Cost note:** AWS Organizations itself is free. Costs come from resources in member accounts.

```bash
# Create an OU
aws organizations create-organizational-unit \
  --parent-id <root-or-ou-id> \
  --name <ou-name>

# Create a new account
aws organizations create-account \
  --email <unique-email@example.com> \
  --account-name <account-name>

# Check account creation status
aws organizations describe-create-account-status --create-account-request-id <request-id>

# Move an account to a different OU
aws organizations move-account \
  --account-id <account-id> \
  --source-parent-id <source-ou-id> \
  --destination-parent-id <dest-ou-id>

# Rename an OU
aws organizations update-organizational-unit \
  --organizational-unit-id <ou-id> \
  --name <new-name>

# Invite an existing account
aws organizations invite-account-to-organization \
  --target '{"Id": "<account-id>", "Type": "ACCOUNT"}' \
  --notes "Join our organization"

# Enable a policy type (e.g., SCPs)
aws organizations enable-policy-type \
  --root-id <root-id> \
  --policy-type SERVICE_CONTROL_POLICY

# Enable an AWS service integration
aws organizations enable-aws-service-access \
  --service-principal <service>.amazonaws.com
```

### Service Control Policies (SCPs)

```bash
# Create an SCP
aws organizations create-policy \
  --name <policy-name> \
  --description "Deny specific actions" \
  --type SERVICE_CONTROL_POLICY \
  --content '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "DenyLargeInstances",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "ForAnyValue:StringNotLike": {
          "ec2:InstanceType": ["t3.*", "t3a.*", "m5.large", "m5.xlarge"]
        }
      }
    }]
  }'

# Attach an SCP to an OU
aws organizations attach-policy \
  --policy-id <policy-id> \
  --target-id <ou-id>

# Attach an SCP to an account
aws organizations attach-policy \
  --policy-id <policy-id> \
  --target-id <account-id>

# Detach an SCP
aws organizations detach-policy \
  --policy-id <policy-id> \
  --target-id <target-id>

# Update an SCP
aws organizations update-policy \
  --policy-id <policy-id> \
  --content file://updated-policy.json
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Remove an account from the organization
aws organizations remove-account-from-organization --account-id <account-id>

# Delete an OU (must be empty)
aws organizations delete-organizational-unit --organizational-unit-id <ou-id>

# Delete a policy (must be detached from all targets)
aws organizations delete-policy --policy-id <policy-id>

# Close an account
aws organizations close-account --account-id <account-id>
```

## Safety Rules

1. **NEVER** remove accounts or close accounts without explicit user confirmation.
2. **NEVER** detach the FullAWSAccess SCP from the root without understanding the impact.
3. **NEVER** expose or log AWS credentials or account emails publicly.
4. **ALWAYS** test SCPs on a non-production OU first.
5. **WARN** that overly restrictive SCPs can lock out all users including root.
6. **WARN** that closing an account is irreversible after the 90-day grace period.

## Best Practices

- Use a multi-OU structure: Security, Workloads (Prod/Dev/Staging), Sandbox, Infrastructure.
- Apply SCPs at the OU level, not individual accounts.
- Always keep a "break glass" account outside restrictive SCPs.
- Use AWS Control Tower for standardized multi-account setup.
- Enable CloudTrail organization trail for centralized audit.

## Common Patterns

### Pattern: View Organization Tree

```bash
ROOT=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
echo "Root: $ROOT"

# List OUs
aws organizations list-organizational-units-for-parent --parent-id $ROOT \
  --query 'OrganizationalUnits[*].[Id,Name]' --output text | while read ou_id ou_name; do
  echo "  OU: $ou_name ($ou_id)"
  aws organizations list-accounts-for-parent --parent-id "$ou_id" \
    --query 'Accounts[*].[Id,Name]' --output text | while read acc_id acc_name; do
    echo "    Account: $acc_name ($acc_id)"
  done
done
```

### Pattern: Deny Region Usage via SCP

```bash
aws organizations create-policy \
  --name DenyOutsideRegions \
  --type SERVICE_CONTROL_POLICY \
  --content '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "DenyNonApprovedRegions",
      "Effect": "Deny",
      "NotAction": ["iam:*", "organizations:*", "sts:*", "support:*"],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {"aws:RequestedRegion": ["us-east-1", "us-west-2", "eu-west-1"]}
      }
    }]
  }' \
  --description "Restrict to approved regions only"
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `AccessDeniedException` | Not running from management account | Run from the management (payer) account |
| `PolicyTypeNotEnabledException` | SCP not enabled on root | Enable with `enable-policy-type` |
| `OrganizationalUnitNotEmptyException` | OU has children or accounts | Move all accounts/OUs out first |
| `AccountAlreadyRegisteredException` | Account already delegated admin | Check with `list-delegated-administrators` |
| `HandshakeConstraintViolationException` | Account can't be invited | Check for existing organization membership |
| `ConstraintViolationException` on SCP detach | Can't remove last SCP from target | At least one SCP must remain attached |
