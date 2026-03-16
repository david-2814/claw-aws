---
name: cdk
description: Manage AWS CDK applications, stacks, synthesis, deployment, and bootstrapping via CDK CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🏗️",
        "requires": { "bins": ["cdk"] },
      },
  }
---

# AWS CDK

Use this skill for infrastructure-as-code with AWS CDK: initializing projects, synthesizing CloudFormation templates, deploying stacks, managing environments, and troubleshooting CDK applications.

## Prerequisites

- AWS CDK CLI installed (`npm install -g aws-cdk`)
- AWS CLI v2 configured with valid credentials
- Node.js (for TypeScript/JavaScript projects) or Python/Java/.NET for other languages
- CDK bootstrap completed for target account/region

## Common Operations

### Inspect and Status (Read-Only)

```bash
# Check CDK version
cdk --version

# List stacks in the CDK app
cdk list

# Synthesize (generate CloudFormation template without deploying)
cdk synth <stack-name>

# Diff — show what would change
cdk diff <stack-name>

# Diff all stacks
cdk diff --all

# Show the CloudFormation template
cdk synth <stack-name> --quiet

# Show CDK context values
cdk context

# Show metadata about the CDK app
cdk metadata <stack-name>

# Doctor — check for potential issues
cdk doctor
```

### Bootstrap

```bash
# Bootstrap the default account/region
cdk bootstrap

# Bootstrap a specific account/region
cdk bootstrap aws://<account-id>/<region>

# Bootstrap with custom qualifier
cdk bootstrap --qualifier <qualifier> aws://<account-id>/<region>

# Bootstrap with custom permissions boundary
cdk bootstrap --custom-permissions-boundary <policy-name>

# Bootstrap with trust for CI/CD account
cdk bootstrap aws://<target-account>/<region> \
  --trust <ci-cd-account-id> \
  --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess
```

### Initialize Projects

```bash
# Create a new CDK app (TypeScript)
cdk init app --language typescript

# Create with Python
cdk init app --language python

# Create a sample app
cdk init sample-app --language typescript

# List available templates
cdk init --list
```

### Deploy

⚠️ **Cost note:** CDK itself is free. Costs come from the AWS resources you deploy. Always `cdk diff` before deploying to understand what resources will be created.

```bash
# Deploy a specific stack
cdk deploy <stack-name>

# Deploy all stacks
cdk deploy --all

# Deploy without approval prompts (CI/CD)
cdk deploy <stack-name> --require-approval never

# Deploy with parameters
cdk deploy <stack-name> --parameters Param1=value1 --parameters Param2=value2

# Deploy with outputs to file
cdk deploy <stack-name> --outputs-file outputs.json

# Deploy specific stacks with dependencies
cdk deploy Stack1 Stack2

# Hot-swap deploy (faster, for development only)
cdk deploy <stack-name> --hotswap

# Watch mode (auto-deploy on file changes)
cdk watch <stack-name>

# Deploy with rollback disabled (for debugging)
cdk deploy <stack-name> --no-rollback

# Deploy with notification ARN
cdk deploy <stack-name> --notification-arns <sns-topic-arn>
```

### Destroy / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Destroy a stack
cdk destroy <stack-name>

# Destroy all stacks
cdk destroy --all

# Destroy without confirmation prompt
cdk destroy <stack-name> --force

# Clear context values
cdk context --clear
```

⚠️ **`cdk destroy` deletes all resources in the stack. Some resources (S3 buckets with data, DynamoDB tables) may have deletion protection or `RemovalPolicy.RETAIN`.**

## Safety Rules

1. **NEVER** run `cdk deploy` without running `cdk diff` first and reviewing changes.
2. **NEVER** destroy stacks without listing resources and confirming with the user.
3. **NEVER** use `--require-approval never` outside of CI/CD pipelines.
4. **NEVER** expose or log AWS credentials, access keys, or secret keys.
5. **ALWAYS** recommend `RemovalPolicy.RETAIN` for stateful resources (databases, S3 buckets).
6. **WARN** that `--hotswap` skips CloudFormation and should never be used in production.

## Best Practices

- Always run `cdk diff` before deploying to review changes.
- Use `RemovalPolicy.RETAIN` for databases, buckets, and any stateful resources.
- Use separate stacks for stateful and stateless resources.
- Pin CDK library versions to avoid unexpected breaking changes.
- Use CDK context (`cdk.json`) for environment-specific configuration.

## Common Patterns

### Pattern: Deploy Pipeline (CI/CD Safe)

```bash
# Full CI/CD deploy flow
cdk synth                           # Synthesize
cdk diff --all 2>&1 | tee diff.txt  # Review changes
cdk deploy --all --require-approval never --ci  # Deploy
```

### Pattern: Multi-Environment Deployment

```bash
# Deploy to dev
cdk deploy --all -c environment=dev

# Deploy to prod (with approval)
cdk deploy --all -c environment=prod --require-approval broadening
```

### Pattern: Migrate from CloudFormation

```bash
# Import existing resources into a CDK stack
cdk import <stack-name>

# Generate L1 constructs from existing CloudFormation template
cdk migrate --from-path template.yaml --stack-name <stack-name> --language typescript
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `CDKToolkit stack not found` | Account/region not bootstrapped | Run `cdk bootstrap aws://<account>/<region>` |
| `--app is required` | Not in a CDK project directory | `cd` to the project root with `cdk.json` |
| `Cannot find module` | Dependencies not installed | Run `npm install` (TS) or `pip install -r requirements.txt` (Python) |
| `CREATE_FAILED` on deploy | Resource creation error | Check CloudFormation events in console for details |
| `UPDATE_ROLLBACK_FAILED` | Stack stuck in failed state | Continue rollback in CloudFormation console |
| `Resource already exists` | Importing or naming conflict | Use `cdk import` or change logical IDs |
| Circular dependency | Stacks reference each other | Break the cycle with `CfnOutput` / `Fn.importValue` or restructure |
