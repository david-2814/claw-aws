---
name: elb
description: Manage Elastic Load Balancers (ALB, NLB, CLB), target groups, listeners, and health checks via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "⚖️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Elastic Load Balancing

Use this skill for load balancer operations: creating and managing Application Load Balancers (ALB), Network Load Balancers (NLB), and Classic Load Balancers (CLB), configuring target groups, listeners, rules, and monitoring health checks.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `elasticloadbalancing:*` for full access
- VPC with subnets in multiple AZs (recommended)
- For ALB with HTTPS: ACM certificate

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all load balancers (ALB/NLB)
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].[LoadBalancerName,Type,Scheme,State.Code,DNSName]' --output table

# Describe a load balancer
aws elbv2 describe-load-balancers --names <lb-name>

# List target groups
aws elbv2 describe-target-groups \
  --query 'TargetGroups[*].[TargetGroupName,Protocol,Port,TargetType,HealthCheckPath]' --output table

# Check target health
aws elbv2 describe-target-health --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]' --output table

# List listeners
aws elbv2 describe-listeners --load-balancer-arn <lb-arn> \
  --query 'Listeners[*].[Port,Protocol,DefaultActions[0].Type]' --output table

# List listener rules
aws elbv2 describe-rules --listener-arn <listener-arn> \
  --query 'Rules[*].[Priority,Conditions[0].Field,Actions[0].Type,Actions[0].TargetGroupArn]' --output table

# Get load balancer attributes
aws elbv2 describe-load-balancer-attributes --load-balancer-arn <lb-arn> --output table

# Get target group attributes
aws elbv2 describe-target-group-attributes --target-group-arn <tg-arn> --output table

# List tags
aws elbv2 describe-tags --resource-arns <lb-arn>

# List Classic Load Balancers
aws elb describe-load-balancers \
  --query 'LoadBalancerDescriptions[*].[LoadBalancerName,DNSName,Scheme]' --output table

# Check Classic LB instance health
aws elb describe-instance-health --load-balancer-name <clb-name> --output table
```

### Create Load Balancers

⚠️ **Cost note:** ALB: $0.0225/hr + $0.008/LCU-hour (~$16/mo base). NLB: $0.0225/hr + $0.006/NLCU-hour. CLB: $0.025/hr + $0.008/GB data.

```bash
# Create an Application Load Balancer (ALB)
aws elbv2 create-load-balancer \
  --name <lb-name> \
  --type application \
  --scheme internet-facing \
  --subnets <subnet-1> <subnet-2> <subnet-3> \
  --security-groups <sg-id>

# Create a Network Load Balancer (NLB)
aws elbv2 create-load-balancer \
  --name <lb-name> \
  --type network \
  --scheme internet-facing \
  --subnets <subnet-1> <subnet-2>

# Create an internal ALB
aws elbv2 create-load-balancer \
  --name <lb-name> \
  --type application \
  --scheme internal \
  --subnets <subnet-1> <subnet-2> \
  --security-groups <sg-id>

# Create a target group (instances)
aws elbv2 create-target-group \
  --name <tg-name> \
  --protocol HTTP \
  --port 80 \
  --vpc-id <vpc-id> \
  --target-type instance \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# Create a target group (IP targets — for Fargate/containers)
aws elbv2 create-target-group \
  --name <tg-name> \
  --protocol HTTP \
  --port 8080 \
  --vpc-id <vpc-id> \
  --target-type ip \
  --health-check-path /health

# Register targets
aws elbv2 register-targets \
  --target-group-arn <tg-arn> \
  --targets Id=<instance-id-1> Id=<instance-id-2>

# Create an HTTP listener
aws elbv2 create-listener \
  --load-balancer-arn <lb-arn> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<tg-arn>

# Create an HTTPS listener
aws elbv2 create-listener \
  --load-balancer-arn <lb-arn> \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=<acm-cert-arn> \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=<tg-arn>

# Create HTTP to HTTPS redirect
aws elbv2 create-listener \
  --load-balancer-arn <lb-arn> \
  --protocol HTTP \
  --port 80 \
  --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'

# Add a path-based routing rule
aws elbv2 create-rule \
  --listener-arn <listener-arn> \
  --priority 10 \
  --conditions '[{"Field": "path-pattern", "Values": ["/api/*"]}]' \
  --actions '[{"Type": "forward", "TargetGroupArn": "<api-tg-arn>"}]'

# Add host-based routing rule
aws elbv2 create-rule \
  --listener-arn <listener-arn> \
  --priority 20 \
  --conditions '[{"Field": "host-header", "Values": ["api.example.com"]}]' \
  --actions '[{"Type": "forward", "TargetGroupArn": "<api-tg-arn>"}]'
```

### Modify

```bash
# Enable access logs
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn <lb-arn> \
  --attributes Key=access_logs.s3.enabled,Value=true Key=access_logs.s3.bucket,Value=<bucket> Key=access_logs.s3.prefix,Value=alb-logs

# Enable deletion protection
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn <lb-arn> \
  --attributes Key=deletion_protection.enabled,Value=true

# Enable stickiness
aws elbv2 modify-target-group-attributes \
  --target-group-arn <tg-arn> \
  --attributes Key=stickiness.enabled,Value=true Key=stickiness.type,Value=lb_cookie Key=stickiness.lb_cookie.duration_seconds,Value=3600

# Deregister a target
aws elbv2 deregister-targets \
  --target-group-arn <tg-arn> \
  --targets Id=<instance-id>
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a listener
aws elbv2 delete-listener --listener-arn <listener-arn>

# Delete a rule
aws elbv2 delete-rule --rule-arn <rule-arn>

# Delete a target group (must have no targets)
aws elbv2 delete-target-group --target-group-arn <tg-arn>

# Delete a load balancer
aws elbv2 delete-load-balancer --load-balancer-arn <lb-arn>
```

## Safety Rules

1. **NEVER** delete load balancers or target groups without explicit user confirmation.
2. **NEVER** expose or log AWS credentials or certificate private keys.
3. **ALWAYS** check target health before making changes to target groups.
4. **ALWAYS** enable deletion protection on production load balancers.
5. **WARN** before deregistering the last healthy target — causes downtime.
6. **WARN** about cost implications of cross-AZ data transfer.

## Best Practices

- Use ALB for HTTP/HTTPS; NLB for TCP/UDP/TLS and extreme performance.
- Enable access logs for security auditing and troubleshooting.
- Use HTTPS listeners with modern TLS policies (TLS 1.3).
- Enable deletion protection on production load balancers.
- Configure health checks to use a dedicated `/health` endpoint.

## Common Patterns

### Pattern: Blue/Green Deployment via Target Group Swap

```bash
# Create new target group with new version
aws elbv2 create-target-group --name app-v2 --protocol HTTP --port 80 --vpc-id <vpc-id>
aws elbv2 register-targets --target-group-arn <new-tg-arn> --targets Id=<new-instance>

# Verify health
aws elbv2 describe-target-health --target-group-arn <new-tg-arn>

# Swap the listener's default action
aws elbv2 modify-listener \
  --listener-arn <listener-arn> \
  --default-actions Type=forward,TargetGroupArn=<new-tg-arn>
```

### Pattern: Find Unhealthy Targets

```bash
for tg in $(aws elbv2 describe-target-groups --query 'TargetGroups[*].TargetGroupArn' --output text); do
  UNHEALTHY=$(aws elbv2 describe-target-health --target-group-arn "$tg" \
    --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output text)
  [ -n "$UNHEALTHY" ] && echo "TG: $tg" && echo "$UNHEALTHY"
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| All targets unhealthy | Health check failing | Verify health check path, port, and security group |
| `LoadBalancerNotFound` | Wrong name or region | Verify with `describe-load-balancers` |
| 502 Bad Gateway | Target not responding or crashed | Check target application and health check |
| 503 Service Unavailable | No healthy targets | Register healthy targets or fix failing ones |
| `OperationNotPermitted` | Deletion protection enabled | Disable deletion protection first |
| Certificate error on HTTPS | Wrong or expired ACM cert | Verify cert with `aws acm describe-certificate` |
