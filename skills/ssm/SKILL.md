---
name: ssm
description: Manage AWS Systems Manager parameters, sessions, run commands, patch baselines, and inventory via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔧",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Systems Manager (SSM)

Use this skill for fleet management and operations: storing and retrieving parameters, running remote commands on instances, starting interactive sessions, managing patch baselines, collecting inventory, and automating runbooks.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `ssm:*` for full access, or scoped policies
- SSM Agent installed on target instances (pre-installed on Amazon Linux 2, Ubuntu 20.04+, Windows Server)
- Instance IAM role with `AmazonSSMManagedInstanceCore` policy for managed instances
- Session Manager plugin for interactive sessions: `brew install --cask session-manager-plugin`

## Common Operations

### Parameter Store (Read-Only)

```bash
# List all parameters
aws ssm describe-parameters --output table

# List parameters by path
aws ssm get-parameters-by-path --path /myapp/ --recursive

# Get a parameter value
aws ssm get-parameter --name <parameter-name> --query 'Parameter.Value' --output text

# Get a SecureString parameter (decrypted)
aws ssm get-parameter --name <parameter-name> --with-decryption --query 'Parameter.Value' --output text

# Get parameter history
aws ssm get-parameter-history --name <parameter-name> --output table

# Get multiple parameters
aws ssm get-parameters --names <name1> <name2> <name3> --with-decryption
```

### Parameter Store (Write)

⚠️ **Cost note:** Standard parameters are free (up to 10,000). Advanced parameters: $0.05/month each.

```bash
# Create/update a String parameter
aws ssm put-parameter \
  --name /myapp/config/db-host \
  --value "mydb.cluster-xxx.us-east-1.rds.amazonaws.com" \
  --type String \
  --description "Database hostname"

# Create a SecureString parameter (encrypted with KMS)
aws ssm put-parameter \
  --name /myapp/secrets/db-password \
  --value "<password>" \
  --type SecureString

# Create a SecureString with custom KMS key
aws ssm put-parameter \
  --name /myapp/secrets/api-key \
  --value "<api-key>" \
  --type SecureString \
  --key-id <kms-key-id>

# Create a StringList parameter
aws ssm put-parameter \
  --name /myapp/config/allowed-origins \
  --value "https://example.com,https://app.example.com" \
  --type StringList

# Update with overwrite
aws ssm put-parameter \
  --name /myapp/config/db-host \
  --value "new-host.rds.amazonaws.com" \
  --type String \
  --overwrite

# Add tags to a parameter
aws ssm add-tags-to-resource \
  --resource-type Parameter \
  --resource-id /myapp/config/db-host \
  --tags Key=Environment,Value=production
```

### Managed Instances

```bash
# List managed instances
aws ssm describe-instance-information \
  --query 'InstanceInformationList[*].[InstanceId,PlatformType,PlatformName,AgentVersion,PingStatus]' \
  --output table

# List instances by tag
aws ssm describe-instance-information \
  --filters "Key=tag:Environment,Values=production" \
  --output table

# Get instance association status
aws ssm describe-instance-associations-status \
  --instance-id <instance-id> --output table
```

### Run Command

```bash
# Run a shell command on instances
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=instanceids,Values=<instance-id-1>,<instance-id-2>" \
  --parameters 'commands=["hostname","uptime","df -h"]'

# Run on instances by tag
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Environment,Values=production" \
  --parameters 'commands=["systemctl status myapp"]'

# Run PowerShell on Windows
aws ssm send-command \
  --document-name "AWS-RunPowerShellScript" \
  --targets "Key=instanceids,Values=<instance-id>" \
  --parameters 'commands=["Get-Service | Where-Object {$_.Status -eq \"Running\"}"]'

# Get command output
aws ssm get-command-invocation \
  --command-id <command-id> \
  --instance-id <instance-id> \
  --query '{Status: Status, Output: StandardOutputContent}'

# List recent commands
aws ssm list-commands --max-results 10 --output table
```

### Session Manager

```bash
# Start an interactive session
aws ssm start-session --target <instance-id>

# Start a port-forwarding session
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3306"],"localPortNumber":["3306"]}'

# Start SSH over Session Manager
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartSSHSession \
  --parameters '{"portNumber":["22"]}'

# List active sessions
aws ssm describe-sessions --state Active --output table

# Terminate a session
aws ssm terminate-session --session-id <session-id>
```

### Patch Manager

```bash
# List patch baselines
aws ssm describe-patch-baselines --output table

# Get default patch baseline for an OS
aws ssm get-default-patch-baseline --operating-system AMAZON_LINUX_2

# Describe patch group state
aws ssm describe-patch-group-state --patch-group <group-name>

# Check instance patch compliance
aws ssm describe-instance-patch-states \
  --instance-ids <instance-id> --output table

# Scan for missing patches (dry run)
aws ssm send-command \
  --document-name "AWS-RunPatchBaseline" \
  --targets "Key=instanceids,Values=<instance-id>" \
  --parameters '{"Operation":["Scan"]}'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a parameter
aws ssm delete-parameter --name <parameter-name>

# Delete multiple parameters
aws ssm delete-parameters --names <name1> <name2>

# Deregister a managed instance
aws ssm deregister-managed-instance --instance-id <instance-id>
```

## Safety Rules

1. **NEVER** delete parameters without explicit user confirmation.
2. **NEVER** expose or log SecureString parameter values, AWS credentials, or secret keys.
3. **ALWAYS** use `--with-decryption` only when the user explicitly needs the value.
4. **ALWAYS** confirm target instances before running commands.
5. **ALWAYS** prefer `Scan` over `Install` for patch operations until the user confirms.
6. **WARN** that Run Command executes with the instance's IAM role — respect least privilege.
7. **WARN** about the blast radius when targeting by tag (may hit many instances).

## Best Practices

- Use Parameter Store hierarchies (`/app/env/key`) for organized configuration.
- Use SecureString for all sensitive values — never store secrets as plain String.
- Use Session Manager instead of SSH for instance access (no open ports needed).
- Tag parameters and use resource policies for access control.
- Enable CloudTrail logging for parameter access auditing.

## Common Patterns

### Pattern: Application Configuration Hierarchy

```bash
# Set up structured config
aws ssm put-parameter --name /myapp/prod/db/host --value "prod-db.example.com" --type String
aws ssm put-parameter --name /myapp/prod/db/port --value "5432" --type String
aws ssm put-parameter --name /myapp/prod/db/password --value "<pass>" --type SecureString

# Retrieve all config for an environment
aws ssm get-parameters-by-path --path /myapp/prod/ --recursive --with-decryption
```

### Pattern: Remote Diagnostics

```bash
# Run diagnostics across a fleet
CMD_ID=$(aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Role,Values=webserver" \
  --parameters 'commands=["df -h","free -m","top -bn1 | head -20"]' \
  --query 'Command.CommandId' --output text)

# Check status
aws ssm list-command-invocations --command-id $CMD_ID --output table
```

### Pattern: Secure Bastion via Session Manager

```bash
# Port-forward to an RDS database through an instance
aws ssm start-session \
  --target <bastion-instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["mydb.cluster-xxx.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5432"]}'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ParameterNotFound` | Parameter doesn't exist | Check path/name; parameter names are case-sensitive |
| `AccessDeniedException` | Missing IAM permissions | Check policy for `ssm:GetParameter`, `ssm:PutParameter`, etc. |
| Instance not in `describe-instance-information` | SSM Agent not running or no IAM role | Verify SSM Agent status and instance profile |
| `TargetNotConnected` | Instance offline or agent stopped | Check instance state and SSM Agent service |
| Session Manager plugin error | Plugin not installed | Install with `brew install --cask session-manager-plugin` |
| Run Command timeout | Command took too long | Increase `--timeout-seconds`; default is 3600 |
