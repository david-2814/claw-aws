---
name: sam
description: Build, test, and deploy serverless applications with AWS SAM CLI (Lambda, API Gateway, DynamoDB, Step Functions).
metadata:
  {
    "openclaw":
      {
        "emoji": "🐿️",
        "requires": { "bins": ["sam"] },
      },
  }
---

# AWS SAM (Serverless Application Model)

Use this skill for serverless development: initializing SAM projects, building and packaging functions, local testing and debugging, deploying serverless stacks, and managing serverless APIs.

## Prerequisites

- AWS SAM CLI installed (`brew install aws-sam-cli` or pip)
- AWS CLI v2 configured with valid credentials
- Docker (for local invoke/testing)
- Language runtime matching your function (Python, Node.js, Go, Java, etc.)

## Common Operations

### Inspect and Status (Read-Only)

```bash
# Check SAM CLI version
sam --version

# Validate a SAM template
sam validate

# Validate with lint rules
sam validate --lint

# List stack resources (after deployment)
sam list resources --stack-name <stack-name>

# List stack endpoints
sam list endpoints --stack-name <stack-name>

# List stack outputs
sam list stack-outputs --stack-name <stack-name>
```

### Initialize Projects

```bash
# Interactive init (walks through options)
sam init

# Quick init with specific runtime
sam init --runtime python3.12 --app-template hello-world --name my-app

# Init from a starter template
sam init --location gh:aws/aws-sam-cli-app-templates

# Init with a specific package type
sam init --runtime nodejs20.x --package-type Zip --name my-node-app
sam init --runtime python3.12 --package-type Image --name my-container-app
```

### Build

```bash
# Build all functions
sam build

# Build with a specific container (consistent builds)
sam build --use-container

# Build a specific function
sam build <FunctionLogicalId>

# Build with custom manifest
sam build --manifest requirements.txt

# Parallel build (faster for multi-function apps)
sam build --parallel
```

### Local Development and Testing

```bash
# Invoke a function locally
sam local invoke <FunctionLogicalId>

# Invoke with an event
sam local invoke <FunctionLogicalId> --event events/event.json

# Invoke with environment variables
sam local invoke <FunctionLogicalId> --env-vars env.json

# Start a local API Gateway
sam local start-api

# Start local API on a specific port
sam local start-api --port 3000

# Start Lambda emulator
sam local start-lambda

# Generate a sample event
sam local generate-event s3 put
sam local generate-event apigateway aws-proxy
sam local generate-event sqs receive-message

# Tail logs from deployed function
sam logs --name <FunctionLogicalId> --stack-name <stack-name> --tail
```

### Deploy

⚠️ **Cost note:** SAM is free — costs come from the AWS resources deployed (Lambda, API Gateway, DynamoDB, etc.). Lambda free tier: 1M requests + 400K GB-seconds/month.

```bash
# Guided deploy (interactive — first time)
sam deploy --guided

# Deploy with saved config
sam deploy

# Deploy with specific parameters
sam deploy --parameter-overrides Environment=prod ApiKey=<key>

# Deploy without confirmation
sam deploy --no-confirm-changeset

# Deploy to a specific region
sam deploy --region <region>

# Deploy with specific S3 bucket for artifacts
sam deploy --s3-bucket <bucket-name> --s3-prefix <prefix>

# Package (upload artifacts without deploying)
sam package --output-template-file packaged.yaml --s3-bucket <bucket>
```

### Sync (Accelerated Development)

```bash
# Sync code changes without full deploy (dev only)
sam sync --stack-name <stack-name>

# Watch mode — auto-sync on file changes
sam sync --stack-name <stack-name> --watch

# Sync only code (skip infra changes)
sam sync --stack-name <stack-name> --code
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a deployed stack
sam delete --stack-name <stack-name>

# Delete without confirmation
sam delete --stack-name <stack-name> --no-prompts
```

## Safety Rules

1. **NEVER** deploy without reviewing the changeset (avoid `--no-confirm-changeset` in production).
2. **NEVER** expose or log AWS credentials, API keys, or secret keys.
3. **ALWAYS** use `sam validate --lint` before deploying.
4. **ALWAYS** test locally with `sam local invoke` before deploying to production.
5. **WARN** about Lambda cold starts and timeout configurations.
6. **WARN** that `sam sync` bypasses CloudFormation and is for development only.

## Best Practices

- Use `sam build --use-container` for consistent builds across environments.
- Define DLQs for async Lambda invocations.
- Use Layers for shared code and large dependencies.
- Set appropriate memory (128-10240 MB) and timeout (max 900s) for each function.
- Use `sam pipeline init` and `sam pipeline bootstrap` for CI/CD pipelines.

## Common Patterns

### Pattern: Local API Development

```bash
# Build and start local API
sam build && sam local start-api --warm-containers EAGER

# Test with curl
curl http://localhost:3000/hello
```

### Pattern: Debug with Events

```bash
# Generate a test event
sam local generate-event s3 put --bucket my-bucket --key test.txt > events/s3-put.json

# Invoke with the event
sam local invoke ProcessS3Event --event events/s3-put.json
```

### Pattern: CI/CD Pipeline Deploy

```bash
sam build
sam deploy \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --stack-name my-app-prod \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides Environment=prod
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Error: Template file not found` | Not in project root | `cd` to directory with `template.yaml` |
| `Build Failed` | Dependency installation error | Check runtime version; try `--use-container` |
| `Docker not found` | Docker not running | Start Docker Desktop; needed for `local invoke` and `--use-container` |
| `CREATE_FAILED` on deploy | Resource creation error | Check CloudFormation events; common: IAM permissions, naming conflicts |
| `No changes to deploy` | Template unchanged | Use `--no-fail-on-empty-changeset` to suppress |
| Local invoke timeout | Function exceeds default 3s timeout | Increase `Timeout` in template.yaml |
| `Unable to import module` | Missing dependency in package | Ensure `requirements.txt` / `package.json` is complete; rebuild |
