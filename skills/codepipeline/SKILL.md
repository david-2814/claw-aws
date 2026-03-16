---
name: codepipeline
description: Manage AWS CodePipeline pipelines, stages, actions, executions, and approvals via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔄",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS CodePipeline

Use this skill for CI/CD pipeline operations: creating and managing pipelines, viewing execution history, approving manual stages, retrying failed actions, and managing pipeline webhooks.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `codepipeline:*` for full access, or scoped policies
- Service role for CodePipeline with access to source, build, and deploy services

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all pipelines
aws codepipeline list-pipelines --output table

# Get pipeline details (structure)
aws codepipeline get-pipeline --name <pipeline-name>

# Get pipeline state (current status of all stages)
aws codepipeline get-pipeline-state --name <pipeline-name>

# List pipeline executions
aws codepipeline list-pipeline-executions --pipeline-name <pipeline-name> \
  --query 'pipelineExecutionSummaries[*].[pipelineExecutionId,status,startTime,trigger.triggerType]' \
  --output table

# Get details of a specific execution
aws codepipeline get-pipeline-execution \
  --pipeline-name <pipeline-name> \
  --pipeline-execution-id <execution-id>

# List action executions (detailed step-by-step)
aws codepipeline list-action-executions \
  --pipeline-name <pipeline-name> \
  --query 'actionExecutionDetails[*].[stageName,actionName,status,startTime]' \
  --output table

# List webhooks
aws codepipeline list-webhooks --output table

# List tags
aws codepipeline list-tags-for-resource --resource-arn <pipeline-arn>
```

### Execute and Control

```bash
# Start a pipeline execution manually
aws codepipeline start-pipeline-execution --name <pipeline-name>

# Retry a failed stage
aws codepipeline retry-stage-execution \
  --pipeline-name <pipeline-name> \
  --stage-name <stage-name> \
  --pipeline-execution-id <execution-id> \
  --retry-mode FAILED_ACTIONS

# Stop a pipeline execution
aws codepipeline stop-pipeline-execution \
  --pipeline-name <pipeline-name> \
  --pipeline-execution-id <execution-id> \
  --abandon \
  --reason "Stopped by operator"

# Approve a manual approval action
aws codepipeline put-approval-result \
  --pipeline-name <pipeline-name> \
  --stage-name <stage-name> \
  --action-name <action-name> \
  --result "summary=Approved by admin,status=Approved" \
  --token <approval-token>

# Reject a manual approval
aws codepipeline put-approval-result \
  --pipeline-name <pipeline-name> \
  --stage-name <stage-name> \
  --action-name <action-name> \
  --result "summary=Rejected: failing tests,status=Rejected" \
  --token <approval-token>

# Disable a stage transition
aws codepipeline disable-stage-transition \
  --pipeline-name <pipeline-name> \
  --stage-name <stage-name> \
  --transition-type Inbound \
  --reason "Maintenance window"

# Enable a stage transition
aws codepipeline enable-stage-transition \
  --pipeline-name <pipeline-name> \
  --stage-name <stage-name> \
  --transition-type Inbound
```

### Create and Update

⚠️ **Cost note:** CodePipeline charges $1.00 per active pipeline per month. V2 type pipelines charge per action execution ($0.002 per action). First pipeline free.

```bash
# Create a pipeline from JSON definition
aws codepipeline create-pipeline --cli-input-json file://pipeline.json

# Update a pipeline
aws codepipeline update-pipeline --cli-input-json file://pipeline.json

# Tag a pipeline
aws codepipeline tag-resource \
  --resource-arn <pipeline-arn> \
  --tags key=Environment,value=production
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a pipeline
aws codepipeline delete-pipeline --name <pipeline-name>

# Delete a webhook
aws codepipeline delete-webhook --name <webhook-name>
```

## Safety Rules

1. **NEVER** delete a pipeline without explicit user confirmation.
2. **NEVER** expose or log AWS credentials, tokens, or secret keys.
3. **ALWAYS** confirm the pipeline name before triggering execution.
4. **ALWAYS** check pipeline state before retrying or stopping executions.
5. **WARN** before approving manual approval actions — this triggers downstream deployment.
6. **WARN** about the impact of disabling stage transitions on active executions.

## Best Practices

- Use manual approval stages before production deployments.
- Use V2 type pipelines for per-action pricing and advanced features.
- Enable CloudTrail for pipeline audit logging.
- Use pipeline variables and parameter overrides for environment-specific config.
- Store pipeline definitions in source control for version tracking.

## Common Patterns

### Pattern: Check Why a Pipeline Failed

```bash
# Get current state
aws codepipeline get-pipeline-state --name <pipeline-name> \
  --query 'stageStates[?latestExecution.status==`Failed`].[stageName,latestExecution.status,actionStates[?latestExecution.status==`Failed`].[actionName,latestExecution.errorDetails.message]]'

# Get detailed action execution
aws codepipeline list-action-executions --pipeline-name <pipeline-name> \
  --filter pipelineExecutionId=<execution-id> \
  --query 'actionExecutionDetails[?status==`Failed`].[stageName,actionName,output.executionResult.externalExecutionSummary]' \
  --output table
```

### Pattern: Promote Through Environments

```bash
# Approve staging → production transition
TOKEN=$(aws codepipeline get-pipeline-state --name <pipeline-name> \
  --query 'stageStates[?stageName==`Approval`].actionStates[0].latestExecution.token' \
  --output text)

aws codepipeline put-approval-result \
  --pipeline-name <pipeline-name> \
  --stage-name Approval \
  --action-name ManualApproval \
  --result "summary=Tests passed - promoting to prod,status=Approved" \
  --token "$TOKEN"
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `PipelineNotFoundException` | Pipeline doesn't exist | Verify name with `list-pipelines` |
| Stage stuck in `InProgress` | Action hanging or timeout | Check action provider (CodeBuild, Lambda, etc.) logs |
| `InvalidApprovalToken` | Token expired or already used | Get fresh token from `get-pipeline-state` |
| `StageNotRetryable` | Stage succeeded or not yet failed | Only failed stages can be retried |
| Source action failed | Repo/branch not found or auth issue | Check source connection and branch name |
| `ActionTypeNotFoundException` | Invalid action provider | Check supported action types for pipeline version |
