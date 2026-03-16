---
name: cloudformation
description: Manage AWS CloudFormation stacks — deploy, update, monitor, and troubleshoot infrastructure-as-code templates via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🏗️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS CloudFormation

Use this skill for CloudFormation operations: creating and updating stacks, validating templates, monitoring stack events, detecting drift, and troubleshooting failed deployments.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `cloudformation:*` plus permissions for the resources your templates create
- For IAM resource creation: `--capabilities CAPABILITY_IAM` or `CAPABILITY_NAMED_IAM`

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all stacks (excluding deleted)
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE UPDATE_ROLLBACK_COMPLETE \
  --query 'StackSummaries[].[StackName, StackStatus, CreationTime]' \
  --output table

# Describe a stack (full details)
aws cloudformation describe-stacks --stack-name <stack-name>

# Get stack outputs
aws cloudformation describe-stacks --stack-name <stack-name> \
  --query 'Stacks[0].Outputs[].[OutputKey, OutputValue]' --output table

# Get stack parameters
aws cloudformation describe-stacks --stack-name <stack-name> \
  --query 'Stacks[0].Parameters[].[ParameterKey, ParameterValue]' --output table

# List stack resources
aws cloudformation list-stack-resources --stack-name <stack-name> \
  --query 'StackResourceSummaries[].[LogicalResourceId, ResourceType, ResourceStatus]' \
  --output table

# View recent stack events (most recent first)
aws cloudformation describe-stack-events --stack-name <stack-name> \
  --query 'StackEvents[:20].[Timestamp, LogicalResourceId, ResourceStatus, ResourceStatusReason]' \
  --output table

# Validate a template
aws cloudformation validate-template --template-body file://template.yaml

# Estimate cost (via template URL only)
aws cloudformation estimate-template-cost --template-body file://template.yaml

# Detect drift
aws cloudformation detect-stack-drift --stack-name <stack-name>
# Check drift status
aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id <id>
# View drifted resources
aws cloudformation describe-stack-resource-drifts --stack-name <stack-name> \
  --stack-resource-drift-status-filters MODIFIED DELETED
```

### Create a Stack

⚠️ **Cost note:** CloudFormation itself is free, but you pay for the AWS resources it creates. Always review the template to understand what resources will be provisioned.

```bash
# Create a stack from a local template
aws cloudformation create-stack \
  --stack-name <stack-name> \
  --template-body file://template.yaml \
  --parameters ParameterKey=Env,ParameterValue=dev \
  --capabilities CAPABILITY_IAM \
  --tags Key=Project,Value=my-app Key=Environment,Value=dev

# Wait for creation to complete
aws cloudformation wait stack-create-complete --stack-name <stack-name>

# Create from an S3-hosted template
aws cloudformation create-stack \
  --stack-name <stack-name> \
  --template-url https://s3.amazonaws.com/<bucket>/<template>.yaml \
  --capabilities CAPABILITY_IAM

# Create with a change set first (safer — preview before executing)
aws cloudformation create-change-set \
  --stack-name <stack-name> \
  --change-set-name initial-deploy \
  --change-set-type CREATE \
  --template-body file://template.yaml \
  --capabilities CAPABILITY_IAM

# Review the change set
aws cloudformation describe-change-set \
  --stack-name <stack-name> \
  --change-set-name initial-deploy

# Execute it
aws cloudformation execute-change-set \
  --stack-name <stack-name> \
  --change-set-name initial-deploy
```

### Update a Stack

```bash
# Update with change set (RECOMMENDED — always preview changes)
aws cloudformation create-change-set \
  --stack-name <stack-name> \
  --change-set-name update-$(date +%s) \
  --template-body file://template.yaml \
  --parameters ParameterKey=Env,ParameterValue=prod \
  --capabilities CAPABILITY_IAM

# Review changes before executing
aws cloudformation describe-change-set \
  --stack-name <stack-name> \
  --change-set-name <change-set-name> \
  --query 'Changes[].ResourceChange.[Action, LogicalResourceId, ResourceType, Replacement]' \
  --output table

# Execute after review
aws cloudformation execute-change-set \
  --stack-name <stack-name> \
  --change-set-name <change-set-name>

# Wait for update
aws cloudformation wait stack-update-complete --stack-name <stack-name>

# Direct update (skips change set — use only for non-production)
aws cloudformation update-stack \
  --stack-name <stack-name> \
  --template-body file://template.yaml \
  --capabilities CAPABILITY_IAM
```

### Rollback and Recovery

```bash
# Cancel an in-progress update
aws cloudformation cancel-update-stack --stack-name <stack-name>

# Continue rolling back a failed update (skip stuck resources)
aws cloudformation continue-update-rollback \
  --stack-name <stack-name> \
  --resources-to-skip <logical-resource-id>
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Deleting a stack deletes ALL resources it manages. Always confirm with the user.**

```bash
# Delete a stack (removes all managed resources)
aws cloudformation delete-stack --stack-name <stack-name>

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name <stack-name>

# Delete a stack with retained resources (skip certain resources)
aws cloudformation delete-stack \
  --stack-name <stack-name> \
  --retain-resources <logical-resource-id-1> <logical-resource-id-2>
```

## Safety Rules

1. **NEVER** delete a stack without explicit user confirmation and listing the resources it manages.
2. **NEVER** execute a direct `update-stack` on production — always use change sets.
3. **ALWAYS** review change sets before executing, especially for `Replacement: True` changes.
4. **ALWAYS** include `--capabilities CAPABILITY_IAM` or `CAPABILITY_NAMED_IAM` when templates create IAM resources.
5. **ALWAYS** recommend enabling termination protection on production stacks.
6. **WARN** when a change set shows resource replacements — these cause downtime.
7. **PREFER** change sets over direct create/update for all environments.

## Best Practices

- Use change sets for every update — never blindly update production stacks.
- Enable termination protection: `aws cloudformation update-termination-protection --enable-termination-protection --stack-name <name>`.
- Enable stack drift detection on a schedule to catch manual changes.
- Use `DeletionPolicy: Retain` on stateful resources (databases, S3 buckets) to prevent accidental data loss.
- Use nested stacks or stack sets for large, multi-account deployments.
- Store templates in S3 with versioning for auditability.

## Common Patterns

### Pattern: Safe Deploy with Change Set Review

```bash
STACK="my-app-stack"
CHANGESET="update-$(date +%s)"

# Create change set
aws cloudformation create-change-set \
  --stack-name $STACK \
  --change-set-name $CHANGESET \
  --template-body file://template.yaml \
  --capabilities CAPABILITY_IAM

aws cloudformation wait change-set-create-complete \
  --stack-name $STACK --change-set-name $CHANGESET

# Show what will change
echo "=== Proposed Changes ==="
aws cloudformation describe-change-set \
  --stack-name $STACK --change-set-name $CHANGESET \
  --query 'Changes[].ResourceChange.[Action, LogicalResourceId, ResourceType, Replacement]' \
  --output table

echo "Review the changes above. Execute with:"
echo "aws cloudformation execute-change-set --stack-name $STACK --change-set-name $CHANGESET"
```

### Pattern: Tail Stack Events During Deployment

```bash
# Watch events in real-time during create/update
watch -n 5 "aws cloudformation describe-stack-events \
  --stack-name <stack-name> \
  --query 'StackEvents[:10].[Timestamp, LogicalResourceId, ResourceStatus, ResourceStatusReason]' \
  --output table"
```

### Pattern: Find Failed Resources in a Stuck Stack

```bash
aws cloudformation describe-stack-events --stack-name <stack-name> \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId, ResourceStatusReason]' \
  --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `InsufficientCapabilitiesException` | Template creates IAM resources | Add `--capabilities CAPABILITY_IAM` or `CAPABILITY_NAMED_IAM` |
| `ROLLBACK_COMPLETE` state | Stack creation failed and rolled back | Check events for the root cause, then delete and recreate |
| `UPDATE_ROLLBACK_FAILED` | Rollback itself failed | Use `continue-update-rollback` with `--resources-to-skip` |
| `ValidationError: No updates` | Change set found no differences | Template matches current state — nothing to update |
| `TemplateValidationError` | Invalid template syntax or references | Run `validate-template` and fix the reported issues |
| `AlreadyExistsException` | Stack name already taken | Use a different name or delete the existing stack |
