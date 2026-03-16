---
name: ecs
description: Manage Amazon ECS clusters, services, tasks, and task definitions for container orchestration via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🐳",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon ECS

Use this skill for Elastic Container Service operations: managing clusters, deploying services, running tasks, updating task definitions, and troubleshooting container workloads (both Fargate and EC2 launch types).

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `ecs:*`, `ecr:*` for container images, `iam:PassRole` for task/execution roles
- For Fargate: a VPC with subnets and security groups
- For EC2 launch type: EC2 instances registered to the cluster

## Common Operations

### List and Inspect (Read-Only)

```bash
# List clusters
aws ecs list-clusters --query 'clusterArns[]' --output table

# Describe a cluster (capacity, running tasks, services)
aws ecs describe-clusters --clusters <cluster-name> \
  --include STATISTICS ATTACHMENTS \
  --query 'clusters[].[clusterName, status, runningTasksCount, activeServicesCount, registeredContainerInstancesCount]' \
  --output table

# List services in a cluster
aws ecs list-services --cluster <cluster-name> \
  --query 'serviceArns[]' --output table

# Describe a service
aws ecs describe-services --cluster <cluster-name> --services <service-name> \
  --query 'services[].[serviceName, status, desiredCount, runningCount, launchType, taskDefinition]' \
  --output table

# List running tasks
aws ecs list-tasks --cluster <cluster-name> --service-name <service-name> \
  --desired-status RUNNING

# Describe tasks (get IPs, container status, health)
TASK_ARNS=$(aws ecs list-tasks --cluster <cluster-name> --service-name <service-name> --query 'taskArns' --output json)
aws ecs describe-tasks --cluster <cluster-name> --tasks $TASK_ARNS \
  --query 'tasks[].[taskArn, lastStatus, healthStatus, containers[0].networkInterfaces[0].privateIpv4Address]' \
  --output table

# List task definition families
aws ecs list-task-definition-families --status ACTIVE

# Describe latest task definition
aws ecs describe-task-definition --task-definition <family-name> \
  --query 'taskDefinition.[family, revision, cpu, memory, containerDefinitions[].{name:name, image:image, cpu:cpu, memory:memory}]'

# View service events (deployment history, errors)
aws ecs describe-services --cluster <cluster-name> --services <service-name> \
  --query 'services[0].events[:10].[createdAt, message]' --output table
```

### Deploy / Update a Service

⚠️ **Cost note:** Fargate pricing is based on vCPU and memory per second. A task with 0.25 vCPU / 0.5 GB runs ~$9/month. EC2 launch type charges for the underlying instances.

```bash
# Register a new task definition revision
aws ecs register-task-definition --cli-input-json file://task-def.json

# Update a service to use the new task definition
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --task-definition <family>:<revision> \
  --force-new-deployment

# Wait for the service to stabilize
aws ecs wait services-stable --cluster <cluster-name> --services <service-name>

# Scale a service
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --desired-count 3

# Force a new deployment (redeploy same task def, pulls latest image)
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --force-new-deployment
```

### Run One-Off Tasks

```bash
# Run a one-off task (e.g., migration, batch job)
aws ecs run-task \
  --cluster <cluster-name> \
  --task-definition <family>:<revision> \
  --launch-type FARGATE \
  --network-configuration 'awsvpcConfiguration={subnets=[<subnet-id>],securityGroups=[<sg-id>],assignPublicIp=ENABLED}' \
  --overrides '{"containerOverrides":[{"name":"<container-name>","command":["python","migrate.py"]}]}'

# Execute a command in a running container (ECS Exec)
aws ecs execute-command \
  --cluster <cluster-name> \
  --task <task-id> \
  --container <container-name> \
  --interactive \
  --command "/bin/sh"
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Scale service to zero (stops all tasks)
aws ecs update-service --cluster <cluster-name> --service <service-name> --desired-count 0

# Delete a service (must scale to 0 first)
aws ecs delete-service --cluster <cluster-name> --service <service-name>

# Force delete a service (scales down and deletes)
aws ecs delete-service --cluster <cluster-name> --service <service-name> --force

# Delete a cluster (must have no services or tasks)
aws ecs delete-cluster --cluster <cluster-name>

# Stop a specific task
aws ecs stop-task --cluster <cluster-name> --task <task-id> --reason "Manual stop"

# Deregister a task definition (marks inactive, doesn't delete)
aws ecs deregister-task-definition --task-definition <family>:<revision>
```

## Safety Rules

1. **NEVER** force-delete a production service without explicit user confirmation.
2. **NEVER** scale a production service to zero without confirming intent.
3. **ALWAYS** confirm the cluster and service name before deployments.
4. **ALWAYS** wait for `services-stable` after updates to verify healthy deployment.
5. **ALWAYS** check service events after deployment for errors.
6. **PREFER** rolling updates over stop-then-start for zero-downtime deployments.
7. **WARN** about Fargate cost before launching tasks with large CPU/memory configurations.

## Best Practices

- Use Fargate for most workloads — it eliminates cluster capacity management.
- Enable ECS Exec for debugging (requires SSM agent in the task).
- Use circuit breaker deployment configuration to auto-rollback failed deployments.
- Set health check grace periods to avoid premature task killing during startup.
- Use capacity providers for automatic scaling of EC2 launch type clusters.
- Store container images in ECR (same region) to minimize pull times and data transfer costs.

## Common Patterns

### Pattern: Deploy and Verify

```bash
CLUSTER="my-cluster"
SERVICE="my-service"
FAMILY="my-task"

# Get current revision
CURRENT=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE \
  --query 'services[0].taskDefinition' --output text)
echo "Current: $CURRENT"

# Deploy new revision
LATEST=$(aws ecs describe-task-definition --task-definition $FAMILY \
  --query 'taskDefinition.taskDefinitionArn' --output text)
aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $LATEST

# Monitor
aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE
echo "Deployment complete."
aws ecs describe-services --cluster $CLUSTER --services $SERVICE \
  --query 'services[0].events[:5].[createdAt, message]' --output table
```

### Pattern: Troubleshoot Failing Deployments

```bash
# Check service events for errors
aws ecs describe-services --cluster <cluster-name> --services <service-name> \
  --query 'services[0].events[:15].[createdAt, message]' --output table

# Check stopped tasks for exit codes and reasons
STOPPED=$(aws ecs list-tasks --cluster <cluster-name> --service-name <service-name> --desired-status STOPPED --query 'taskArns[:5]' --output json)
aws ecs describe-tasks --cluster <cluster-name> --tasks $STOPPED \
  --query 'tasks[].{task:taskArn, reason:stoppedReason, containers:containers[].{name:name, exitCode:exitCode, reason:reason}}' --output json
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `service ... is unable to consistently start tasks` | Container crashing or health check failing | Check stopped task exit codes and CloudWatch logs |
| `CannotPullContainerError` | Image not found or auth failure | Verify image URI and ECR/Docker Hub credentials |
| `ResourceNotFoundException` | Cluster or service doesn't exist | Check cluster name and region |
| Tasks stuck in `PROVISIONING` | No capacity (Fargate) or no instances (EC2) | Check capacity providers; for EC2, verify instance count |
| `ECS Exec` not working | SSM agent not configured | Enable `executeCommandConfiguration` on the service and add SSM permissions to task role |
