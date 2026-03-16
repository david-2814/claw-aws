---
name: autoscaling
description: Manage EC2 Auto Scaling groups, launch templates, scaling policies, and scheduled actions via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📈",
        "requires": { "bins": ["aws"] },
      },
  }
---

# EC2 Auto Scaling

Use this skill for auto scaling operations: managing Auto Scaling groups, launch templates, scaling policies, scheduled actions, instance refresh, and warm pools.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `autoscaling:*`, `ec2:*` (for launch templates)
- VPC subnets and security groups configured
- AMI or launch template for instances

## Common Operations

### List and Inspect (Read-Only)

```bash
# List Auto Scaling groups
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,MinSize,MaxSize,DesiredCapacity,length(Instances)]' --output table

# Describe a specific group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <asg-name>

# List instances in a group
aws autoscaling describe-auto-scaling-instances \
  --query 'AutoScalingInstances[?AutoScalingGroupName==`<asg-name>`].[InstanceId,LifecycleState,HealthStatus,AvailabilityZone]' --output table

# List scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name <asg-name> \
  --max-items 10 \
  --query 'Activities[*].[StartTime,StatusCode,Description]' --output table

# List scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name <asg-name> \
  --query 'ScalingPolicies[*].[PolicyName,PolicyType,TargetTrackingConfiguration.TargetValue]' --output table

# List scheduled actions
aws autoscaling describe-scheduled-actions \
  --auto-scaling-group-name <asg-name> --output table

# List launch templates
aws ec2 describe-launch-templates \
  --query 'LaunchTemplates[*].[LaunchTemplateName,LaunchTemplateId,DefaultVersionNumber,LatestVersionNumber]' --output table

# Describe a launch template version
aws ec2 describe-launch-template-versions \
  --launch-template-name <template-name> \
  --versions '$Latest'

# List lifecycle hooks
aws autoscaling describe-lifecycle-hooks \
  --auto-scaling-group-name <asg-name> --output table

# Describe warm pool
aws autoscaling describe-warm-pool \
  --auto-scaling-group-name <asg-name>

# List notification configurations
aws autoscaling describe-notification-configurations \
  --auto-scaling-group-names <asg-name> --output table
```

### Create and Configure

⚠️ **Cost note:** Auto Scaling itself is free. You pay for EC2 instances launched. Use spot instances with mixed instance policies to save 60-90%.

```bash
# Create a launch template
aws ec2 create-launch-template \
  --launch-template-name <template-name> \
  --launch-template-data '{
    "ImageId": "<ami-id>",
    "InstanceType": "t3.medium",
    "KeyName": "<key-pair>",
    "SecurityGroupIds": ["<sg-id>"],
    "UserData": "'$(echo -n '#!/bin/bash\nyum update -y' | base64)'"
  }'

# Create new launch template version
aws ec2 create-launch-template-version \
  --launch-template-name <template-name> \
  --source-version 1 \
  --launch-template-data '{"ImageId": "<new-ami-id>"}'

# Set default version
aws ec2 modify-launch-template \
  --launch-template-name <template-name> \
  --default-version <version-number>

# Create an Auto Scaling group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --launch-template LaunchTemplateName=<template-name>,Version='$Latest' \
  --min-size 1 \
  --max-size 5 \
  --desired-capacity 2 \
  --vpc-zone-identifier "<subnet-1>,<subnet-2>,<subnet-3>" \
  --target-group-arns <tg-arn> \
  --health-check-type ELB \
  --health-check-grace-period 300 \
  --tags Key=Name,Value=web-server,PropagateAtLaunch=true Key=Environment,Value=production,PropagateAtLaunch=true

# Create with mixed instances (spot + on-demand)
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --mixed-instances-policy '{
    "LaunchTemplate": {
      "LaunchTemplateSpecification": {"LaunchTemplateName": "<template-name>", "Version": "$Latest"},
      "Overrides": [
        {"InstanceType": "t3.medium"},
        {"InstanceType": "t3a.medium"},
        {"InstanceType": "t3.large"}
      ]
    },
    "InstancesDistribution": {
      "OnDemandBaseCapacity": 1,
      "OnDemandPercentageAboveBaseCapacity": 25,
      "SpotAllocationStrategy": "capacity-optimized"
    }
  }' \
  --min-size 2 --max-size 10 --desired-capacity 4 \
  --vpc-zone-identifier "<subnet-1>,<subnet-2>"
```

### Scaling Policies

```bash
# Target tracking policy (recommended)
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name <asg-name> \
  --policy-name cpu-target-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {"PredefinedMetricType": "ASGAverageCPUUtilization"},
    "TargetValue": 50.0
  }'

# Target tracking on ALB request count
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name <asg-name> \
  --policy-name alb-request-tracking \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "<alb-arn-suffix>/<tg-arn-suffix>"
    },
    "TargetValue": 1000.0
  }'

# Step scaling policy
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name <asg-name> \
  --policy-name scale-out \
  --policy-type StepScaling \
  --adjustment-type ChangeInCapacity \
  --step-adjustments '[
    {"MetricIntervalLowerBound": 0, "MetricIntervalUpperBound": 20, "ScalingAdjustment": 1},
    {"MetricIntervalLowerBound": 20, "ScalingAdjustment": 2}
  ]'

# Scheduled action
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name <asg-name> \
  --scheduled-action-name scale-up-morning \
  --recurrence "0 8 * * MON-FRI" \
  --min-size 4 --max-size 10 --desired-capacity 6

aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name <asg-name> \
  --scheduled-action-name scale-down-evening \
  --recurrence "0 20 * * MON-FRI" \
  --min-size 1 --max-size 5 --desired-capacity 2

# Predictive scaling
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name <asg-name> \
  --policy-name predictive \
  --policy-type PredictiveScaling \
  --predictive-scaling-configuration '{
    "MetricSpecifications": [{
      "TargetValue": 50.0,
      "PredefinedMetricPairSpecification": {"PredefinedMetricType": "ASGCPUUtilization"}
    }],
    "Mode": "ForecastAndScale"
  }'
```

### Instance Management

```bash
# Set desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <asg-name> \
  --desired-capacity <count>

# Update min/max
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --min-size <min> --max-size <max>

# Start an instance refresh (rolling update)
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name <asg-name> \
  --preferences '{"MinHealthyPercentage": 90, "InstanceWarmup": 300}'

# Check instance refresh status
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name <asg-name> \
  --query 'InstanceRefreshes[0].[Status,PercentageComplete,StatusReason]' --output table

# Cancel instance refresh
aws autoscaling cancel-instance-refresh --auto-scaling-group-name <asg-name>

# Detach instances (keep running outside ASG)
aws autoscaling detach-instances \
  --auto-scaling-group-name <asg-name> \
  --instance-ids <instance-id> \
  --should-decrement-desired-capacity

# Set instance protection
aws autoscaling set-instance-protection \
  --auto-scaling-group-name <asg-name> \
  --instance-ids <instance-id> \
  --protected-from-scale-in
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete an ASG (terminates all instances)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --force-delete

# Delete without force (must set desired to 0 and wait first)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --min-size 0 --desired-capacity 0
# Wait for instances to terminate, then:
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name <asg-name>

# Delete a scaling policy
aws autoscaling delete-policy \
  --auto-scaling-group-name <asg-name> \
  --policy-name <policy-name>

# Delete a launch template
aws ec2 delete-launch-template --launch-template-name <template-name>
```

## Safety Rules

1. **NEVER** force-delete an ASG without explicit user confirmation — terminates all instances.
2. **NEVER** expose or log AWS credentials or user data secrets.
3. **ALWAYS** confirm the ASG name and desired capacity before changes.
4. **ALWAYS** use instance refresh for rolling updates instead of manual replacement.
5. **WARN** about setting desired capacity to 0 — terminates all instances.
6. **WARN** about cost of scaling out, especially with large instance types.

## Best Practices

- Use target tracking scaling as the primary policy (simpler, more responsive).
- Use mixed instance policies with spot for cost savings.
- Set health check type to ELB when using a load balancer.
- Use instance refresh for AMI updates instead of manual replacement.
- Set appropriate health check grace period for application startup time.

## Common Patterns

### Pattern: Rolling AMI Update

```bash
# Create new launch template version with new AMI
aws ec2 create-launch-template-version \
  --launch-template-name <template-name> \
  --source-version '$Latest' \
  --launch-template-data '{"ImageId": "<new-ami-id>"}'

# Start instance refresh
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name <asg-name> \
  --preferences '{"MinHealthyPercentage": 90, "InstanceWarmup": 300}'

# Monitor progress
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name <asg-name> \
  --query 'InstanceRefreshes[0].[Status,PercentageComplete]' --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| Instances not launching | Launch template or AMI issue | Check scaling activities for error details |
| `ValidationError` | Invalid parameter combination | Verify subnet IDs, SG IDs, and launch template |
| Instances stuck in `Pending` | Insufficient capacity in AZ | Add more AZs or use mixed instance types |
| Health check failures | App not ready within grace period | Increase `health-check-grace-period` |
| Instance refresh stuck | Instances failing health checks | Check app health; cancel refresh if needed |
| Scale-in too aggressive | Cooldown too short | Increase cooldown or use scale-in protection |
