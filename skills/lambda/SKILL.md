---
name: lambda
description: Manage AWS Lambda functions — deploy, invoke, monitor, and configure serverless functions via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "λ",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Lambda

Use this skill for Lambda operations: creating and deploying functions, invoking them, managing layers and versions, configuring triggers and environment variables, and monitoring execution.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `lambda:*`, plus `iam:PassRole` for execution role assignment
- A Lambda execution role with appropriate policies
- For deployments: a zip file or container image

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all functions
aws lambda list-functions \
  --query 'Functions[].[FunctionName, Runtime, MemorySize, Timeout, LastModified]' \
  --output table

# Get function configuration
aws lambda get-function-configuration --function-name <function-name>

# Get function code location and config
aws lambda get-function --function-name <function-name>

# List versions
aws lambda list-versions-by-function --function-name <function-name>

# List aliases
aws lambda list-aliases --function-name <function-name>

# List event source mappings (SQS, Kinesis, DynamoDB triggers)
aws lambda list-event-source-mappings --function-name <function-name>

# List layers
aws lambda list-layers \
  --query 'Layers[].[LayerName, LatestMatchingVersion.Version]' \
  --output table

# Get recent invocation metrics (last 1 hour)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=<function-name> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Sum
```

### Create a Function

⚠️ **Cost note:** Lambda pricing is per-request ($0.20/1M requests) plus duration (based on memory). A 128MB function running 1M times at 200ms/invocation costs ~$0.63/month. Very cost-effective for bursty workloads.

```bash
# Create from a zip file
zip function.zip index.mjs
aws lambda create-function \
  --function-name my-function \
  --runtime nodejs22.x \
  --role arn:aws:iam::<account-id>:role/<execution-role> \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --timeout 30 \
  --memory-size 256

# Create a basic execution role (if needed)
aws iam create-role \
  --role-name lambda-basic-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'
aws iam attach-role-policy \
  --role-name lambda-basic-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### Deploy / Update Code

```bash
# Update function code from zip
zip function.zip index.mjs
aws lambda update-function-code \
  --function-name <function-name> \
  --zip-file fileb://function.zip

# Update configuration (memory, timeout, env vars)
aws lambda update-function-configuration \
  --function-name <function-name> \
  --memory-size 512 \
  --timeout 60 \
  --environment 'Variables={DB_HOST=mydb.example.com,STAGE=prod}'

# Publish a version (immutable snapshot)
aws lambda publish-version \
  --function-name <function-name> \
  --description "v1.2 - added validation"
```

### Invoke

```bash
# Synchronous invoke
aws lambda invoke \
  --function-name <function-name> \
  --payload '{"key": "value"}' \
  --cli-binary-format raw-in-base64-out \
  output.json && cat output.json

# Async invoke (fire-and-forget)
aws lambda invoke \
  --function-name <function-name> \
  --invocation-type Event \
  --payload '{"key": "value"}' \
  --cli-binary-format raw-in-base64-out \
  /dev/null

# Dry-run (validates permissions without executing)
aws lambda invoke \
  --function-name <function-name> \
  --invocation-type DryRun \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  /dev/null
```

### Logs

```bash
# Tail live logs (requires CloudWatch Logs access)
aws logs tail /aws/lambda/<function-name> --follow --since 5m

# Get recent log streams
aws logs describe-log-streams \
  --log-group-name /aws/lambda/<function-name> \
  --order-by LastEventTime --descending --limit 5

# Get events from a specific stream
aws logs get-log-events \
  --log-group-name /aws/lambda/<function-name> \
  --log-stream-name '<stream-name>' \
  --limit 50
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a function (removes all versions and aliases)
aws lambda delete-function --function-name <function-name>

# Delete a specific version
aws lambda delete-function --function-name <function-name> --qualifier <version>

# Delete an alias
aws lambda delete-alias --function-name <function-name> --name <alias>

# Delete a layer version
aws lambda delete-layer-version --layer-name <layer> --version-number <n>
```

## Safety Rules

1. **NEVER** delete functions without explicit user confirmation.
2. **NEVER** put secrets directly in environment variables — suggest Secrets Manager or Parameter Store.
3. **NEVER** expose function URLs or API Gateway endpoints without authentication.
4. **ALWAYS** confirm the target region and function name before deployments.
5. **ALWAYS** recommend using aliases (dev/staging/prod) for traffic management.
6. **WARN** about cold start implications when changing memory size or runtime.

## Best Practices

- Use Powertools for AWS Lambda for structured logging, tracing, and metrics.
- Set appropriate timeout values — don't leave the default 3s for production.
- Use reserved concurrency to prevent runaway scaling and protect downstream services.
- Use versioning + aliases for safe deployments with instant rollback.
- Keep functions focused — one function per responsibility.
- Use layers for shared dependencies to reduce deployment package size.

## Common Patterns

### Pattern: Quick Deploy and Test

```bash
# Package, deploy, invoke, check logs — one workflow
zip function.zip index.mjs
aws lambda update-function-code --function-name my-func --zip-file fileb://function.zip
aws lambda wait function-updated-v2 --function-name my-func
aws lambda invoke --function-name my-func \
  --payload '{"test": true}' --cli-binary-format raw-in-base64-out /tmp/out.json
cat /tmp/out.json
aws logs tail /aws/lambda/my-func --since 1m
```

### Pattern: Safe Production Deployment (Alias + Version)

```bash
# Deploy new code, publish version, shift alias
aws lambda update-function-code --function-name my-func --zip-file fileb://function.zip
aws lambda wait function-updated-v2 --function-name my-func
VERSION=$(aws lambda publish-version --function-name my-func --query 'Version' --output text)
aws lambda update-alias --function-name my-func --name prod --function-version $VERSION
echo "Deployed version $VERSION to prod alias"
```

### Pattern: Find Functions Not Invoked Recently (Cost Waste)

```bash
for fn in $(aws lambda list-functions --query 'Functions[].FunctionName' --output text); do
  last=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda --metric-name Invocations \
    --dimensions Name=FunctionName,Value=$fn \
    --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 2592000 --statistics Sum \
    --query 'Datapoints[0].Sum' --output text 2>/dev/null)
  [ "$last" = "None" ] || [ "$last" = "0.0" ] && echo "UNUSED: $fn"
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `AccessDeniedException` | Missing IAM permissions | Check caller's policy for `lambda:` actions |
| `ResourceNotFoundException` | Function doesn't exist in this region | Verify function name and region |
| `InvalidParameterValueException` on create | Bad role ARN or runtime | Verify the execution role ARN and that the runtime is supported |
| `TooManyRequestsException` | Concurrency limit hit | Check reserved/unreserved concurrency; request limit increase |
| `Task timed out` | Function exceeded timeout | Increase timeout or optimize function code |
