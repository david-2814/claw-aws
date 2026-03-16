---
name: codedeploy
description: Manage AWS CodeDeploy applications, deployment groups, deployments, and rollbacks via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🚀",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS CodeDeploy

Use this skill for deployment automation: managing applications and deployment groups, triggering and monitoring deployments, configuring rollback and deployment strategies, and managing on-premises instances.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `codedeploy:*` for full access, or scoped policies
- CodeDeploy agent installed on target EC2 instances
- Service role with appropriate permissions for the compute platform (EC2, Lambda, or ECS)

## Common Operations

### List and Inspect (Read-Only)

```bash
# List applications
aws deploy list-applications --output table

# Get application details
aws deploy get-application --application-name <app-name>

# List deployment groups for an application
aws deploy list-deployment-groups --application-name <app-name> --output table

# Get deployment group details
aws deploy get-deployment-group \
  --application-name <app-name> \
  --deployment-group-name <group-name>

# List deployments
aws deploy list-deployments \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --query 'deployments[:10]' --output table

# Get deployment details
aws deploy get-deployment --deployment-id <deployment-id>

# Get deployment target status
aws deploy list-deployment-targets --deployment-id <deployment-id>

# Get target details (instance-level status)
aws deploy get-deployment-target \
  --deployment-id <deployment-id> \
  --target-id <target-id>

# List deployment configs
aws deploy list-deployment-configs --output table

# Get deployment config details
aws deploy get-deployment-config --deployment-config-name <config-name>

# List on-premises instances
aws deploy list-on-premises-instances --output table
```

### Create Applications and Groups

⚠️ **Cost note:** CodeDeploy to EC2/Lambda is free. CodeDeploy to on-premises instances: $0.02 per instance update.

```bash
# Create an application (EC2/On-premises)
aws deploy create-application \
  --application-name <app-name> \
  --compute-platform Server

# Create an application (Lambda)
aws deploy create-application \
  --application-name <app-name> \
  --compute-platform Lambda

# Create an application (ECS)
aws deploy create-application \
  --application-name <app-name> \
  --compute-platform ECS

# Create a deployment group (EC2 with tags)
aws deploy create-deployment-group \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --service-role-arn <role-arn> \
  --ec2-tag-filters Key=Environment,Value=production,Type=KEY_AND_VALUE \
  --deployment-config-name CodeDeployDefault.OneAtATime \
  --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE

# Create a deployment group with Auto Scaling
aws deploy create-deployment-group \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --service-role-arn <role-arn> \
  --auto-scaling-groups <asg-name> \
  --deployment-style deploymentType=IN_PLACE,deploymentOption=WITH_TRAFFIC_CONTROL \
  --load-balancer-info targetGroupInfoList=[{name=<target-group-name>}]

# Create a custom deployment config
aws deploy create-deployment-config \
  --deployment-config-name MyConfig \
  --minimum-healthy-hosts type=FLEET_PERCENT,value=75
```

### Deploy

```bash
# Create a deployment from S3
aws deploy create-deployment \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --s3-location bucket=<bucket>,key=<key>,bundleType=zip

# Create a deployment from GitHub
aws deploy create-deployment \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --github-location repository=<owner/repo>,commitId=<commit-sha>

# Create a deployment with description
aws deploy create-deployment \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --s3-location bucket=<bucket>,key=<key>,bundleType=zip \
  --description "Release v1.2.3" \
  --file-exists-behavior OVERWRITE

# Register a revision
aws deploy register-application-revision \
  --application-name <app-name> \
  --s3-location bucket=<bucket>,key=<key>,bundleType=zip \
  --description "Version 1.2.3"

# Stop a deployment
aws deploy stop-deployment --deployment-id <deployment-id>

# Continue a blue/green deployment (switch traffic)
aws deploy continue-deployment --deployment-id <deployment-id>
```

### Rollback

```bash
# Rollback is automatic if auto-rollback is configured
# Manual rollback: redeploy a previous revision
aws deploy create-deployment \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --revision revisionType=S3,s3Location='{bucket=<bucket>,key=<previous-version-key>,bundleType=zip}' \
  --description "Rollback to previous version"
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a deployment group
aws deploy delete-deployment-group \
  --application-name <app-name> \
  --deployment-group-name <group-name>

# Delete an application (deletes all deployment groups too)
aws deploy delete-application --application-name <app-name>

# Delete a deployment config
aws deploy delete-deployment-config --deployment-config-name <config-name>
```

## Safety Rules

1. **NEVER** delete applications or deployment groups without explicit user confirmation.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** confirm the application, deployment group, and revision before deploying.
4. **ALWAYS** recommend auto-rollback on deployment failure for production groups.
5. **WARN** about in-place vs blue/green deployment impact on running instances.
6. **WARN** that stopping a deployment may leave instances in an inconsistent state.

## Best Practices

- Always enable auto-rollback on deployment failure.
- Use blue/green deployments for zero-downtime production deploys.
- Include a `ValidateService` lifecycle hook to verify the deployment succeeded.
- Use `CodeDeployDefault.OneAtATime` for production; `AllAtOnce` only for dev.
- Tag deployment groups for cost tracking and organization.

## Common Patterns

### Pattern: Monitor a Deployment

```bash
# Watch deployment progress
DEPLOY_ID="<deployment-id>"
while true; do
  STATUS=$(aws deploy get-deployment --deployment-id $DEPLOY_ID \
    --query 'deploymentInfo.status' --output text)
  echo "$(date): $STATUS"
  [ "$STATUS" = "Succeeded" ] || [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Stopped" ] && break
  sleep 10
done

# Get per-instance status
aws deploy list-deployment-targets --deployment-id $DEPLOY_ID \
  --query 'targetIds' --output text | tr '\t' '\n' | while read tid; do
  aws deploy get-deployment-target --deployment-id $DEPLOY_ID --target-id "$tid" \
    --query 'deploymentTarget.instanceTarget.[targetId,status]' --output text
done
```

### Pattern: Blue/Green with ECS

```bash
aws deploy create-deployment \
  --application-name <app-name> \
  --deployment-group-name <group-name> \
  --revision '{"revisionType": "AppSpecContent", "appSpecContent": {"content": "{\"version\": 0.0, \"Resources\": [{\"TargetService\": {\"Type\": \"AWS::ECS::Service\", \"Properties\": {\"TaskDefinition\": \"<task-def-arn>\", \"LoadBalancerInfo\": {\"ContainerName\": \"app\", \"ContainerPort\": 8080}}}}]}"}}'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ApplicationDoesNotExistException` | Application not found | Verify with `list-applications` |
| `DeploymentGroupDoesNotExistException` | Group not found | Check with `list-deployment-groups` |
| Deployment stuck in `InProgress` | Agent not running on instances | Check CodeDeploy agent status on target instances |
| `HEALTH_CONSTRAINTS` failure | Too many instances failed | Check `minimum-healthy-hosts` config; review instance logs |
| Lifecycle event timeout | Script exceeds timeout | Increase timeout in AppSpec or optimize script |
| Agent not found | CodeDeploy agent not installed | Install via `aws ssm send-command` or UserData |
