---
name: codebuild
description: Manage AWS CodeBuild projects, start and monitor builds, view logs, and configure build environments via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🏗️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS CodeBuild

Use this skill for build operations: creating and managing build projects, starting and monitoring builds, viewing build logs, managing build environments, and configuring build caches.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `codebuild:*`, `logs:GetLogEvents` for full access
- CodeBuild service role with access to source repos, S3 artifacts, and other needed services

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all build projects
aws codebuild list-projects --output table

# Get project details
aws codebuild batch-get-projects --names <project-name>

# List builds for a project (recent first)
aws codebuild list-builds-for-project --project-name <project-name> --sort-order DESCENDING

# Get build details
aws codebuild batch-get-builds --ids <build-id>

# Get build details (summary)
aws codebuild batch-get-builds --ids <build-id> \
  --query 'builds[*].[id,buildStatus,startTime,endTime,sourceVersion,phases[-1].phaseType]' \
  --output table

# List all builds (across projects)
aws codebuild list-builds --sort-order DESCENDING

# List available curated environments
aws codebuild list-curated-environment-images

# List report groups
aws codebuild list-report-groups --output table

# List shared projects
aws codebuild list-shared-projects --output table

# View build logs (via CloudWatch)
BUILD=$(aws codebuild batch-get-builds --ids <build-id> \
  --query 'builds[0].logs.{group:groupName,stream:streamName}' --output json)
aws logs get-log-events \
  --log-group-name $(echo $BUILD | jq -r '.group') \
  --log-stream-name $(echo $BUILD | jq -r '.stream') \
  --query 'events[*].message' --output text
```

### Start and Control Builds

```bash
# Start a build
aws codebuild start-build --project-name <project-name>

# Start a build with source version (branch, tag, commit)
aws codebuild start-build \
  --project-name <project-name> \
  --source-version "refs/heads/feature-branch"

# Start with environment variable overrides
aws codebuild start-build \
  --project-name <project-name> \
  --environment-variables-override '[
    {"name": "ENV", "value": "staging", "type": "PLAINTEXT"},
    {"name": "API_KEY", "value": "/myapp/api-key", "type": "PARAMETER_STORE"}
  ]'

# Start with buildspec override
aws codebuild start-build \
  --project-name <project-name> \
  --buildspec-override "version: 0.2\nphases:\n  build:\n    commands:\n      - echo test"

# Start a batch build
aws codebuild start-build-batch --project-name <project-name>

# Stop a build
aws codebuild stop-build --id <build-id>

# Retry a build
aws codebuild retry-build --id <build-id>
```

### Create and Update Projects

⚠️ **Cost note:** CodeBuild charges per build minute. general1.small (3 GB, 2 vCPU): $0.005/min. general1.medium: $0.01/min. general1.large: $0.02/min. Free tier: 100 build minutes/month.

```bash
# Create a project
aws codebuild create-project \
  --name <project-name> \
  --source '{
    "type": "GITHUB",
    "location": "https://github.com/<owner>/<repo>.git",
    "buildspec": "buildspec.yml"
  }' \
  --artifacts '{"type": "NO_ARTIFACTS"}' \
  --environment '{
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:5.0",
    "computeType": "BUILD_GENERAL1_SMALL"
  }' \
  --service-role <role-arn>

# Update project environment
aws codebuild update-project \
  --name <project-name> \
  --environment '{
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:5.0",
    "computeType": "BUILD_GENERAL1_MEDIUM",
    "privilegedMode": true
  }'

# Update project source (change branch)
aws codebuild update-project \
  --name <project-name> \
  --source-version "main"

# Add S3 cache
aws codebuild update-project \
  --name <project-name> \
  --cache '{"type": "S3", "location": "<bucket>/<prefix>"}'

# Create a webhook (auto-build on push)
aws codebuild create-webhook \
  --project-name <project-name> \
  --filter-groups '[[{"type": "EVENT", "pattern": "PUSH"}, {"type": "HEAD_REF", "pattern": "^refs/heads/main$"}]]'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a project
aws codebuild delete-project --name <project-name>

# Delete a webhook
aws codebuild delete-webhook --project-name <project-name>

# Delete a report group
aws codebuild delete-report-group --arn <report-group-arn> --delete-reports
```

## Safety Rules

1. **NEVER** delete projects without explicit user confirmation.
2. **NEVER** expose or log AWS credentials, secrets, or environment variable values of type SECRETS_MANAGER.
3. **ALWAYS** confirm the project name before starting builds.
4. **ALWAYS** use PARAMETER_STORE or SECRETS_MANAGER type for sensitive environment variables.
5. **WARN** about cost implications for large compute types and long-running builds.
6. **WARN** that `privilegedMode: true` gives Docker-level access — only enable for container builds.

## Best Practices

- Use the latest curated images for up-to-date build tools.
- Use S3 or local caching to speed up builds.
- Store secrets in Parameter Store or Secrets Manager, never in buildspec.
- Use `privilegedMode` only when building Docker images.
- Set `buildTimeoutInMinutes` to prevent runaway builds (default is 60 min).

## Common Patterns

### Pattern: Check Build Failure

```bash
# Get the latest build
LATEST=$(aws codebuild list-builds-for-project \
  --project-name <project-name> \
  --sort-order DESCENDING \
  --query 'ids[0]' --output text)

# Get failure details
aws codebuild batch-get-builds --ids $LATEST \
  --query 'builds[0].phases[?phaseStatus==`FAILED`].[phaseType,contexts[0].message]' \
  --output table
```

### Pattern: Build and Push Docker Image

```bash
# Create project with privileged mode and ECR push
aws codebuild create-project \
  --name docker-build \
  --source '{"type": "GITHUB", "location": "https://github.com/owner/repo.git"}' \
  --artifacts '{"type": "NO_ARTIFACTS"}' \
  --environment '{
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:5.0",
    "computeType": "BUILD_GENERAL1_MEDIUM",
    "privilegedMode": true,
    "environmentVariables": [
      {"name": "ECR_REPO", "value": "<account-id>.dkr.ecr.<region>.amazonaws.com/<repo>"}
    ]
  }' \
  --service-role <role-arn>
```

### Pattern: Monitor Active Builds

```bash
# List in-progress builds
aws codebuild list-builds --sort-order DESCENDING \
  --query 'ids[:5]' --output text | tr '\t' '\n' | while read id; do
  aws codebuild batch-get-builds --ids "$id" \
    --query 'builds[?buildStatus==`IN_PROGRESS`].[id,projectName,startTime,currentPhase]' \
    --output table 2>/dev/null
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFoundException` | Project doesn't exist | Verify name with `list-projects` |
| `DOWNLOAD_SOURCE` phase failed | Source repo access issue | Check source credentials and repo URL |
| `BUILD` phase failed | Build command error | Check buildspec.yml and build logs |
| `PROVISIONING` phase slow | Container startup delay | Normal for first build; subsequent are faster with cache |
| `AccessDeniedException` | Service role missing permissions | Add required policies to the CodeBuild service role |
| Build timeout | Build exceeds `timeoutInMinutes` | Increase timeout or optimize build steps |
| Docker build fails | `privilegedMode` not enabled | Set `privilegedMode: true` in environment config |
