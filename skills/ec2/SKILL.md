---
name: ec2
description: Manage Amazon EC2 instances, AMIs, security groups, and key pairs via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🖥️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon EC2

Use this skill for EC2 operations: launching and managing instances, working with AMIs, configuring security groups, managing key pairs, and monitoring instance health.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `ec2:*` for full access, or scoped policies
- A VPC and subnet (default VPC works for quick tests)
- An EC2 key pair if SSH access is needed

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all instances with key details
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].[InstanceId, State.Name, InstanceType, PublicIpAddress, Tags[?Key==`Name`].Value | [0]]' \
  --output table

# List running instances only
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId, InstanceType, PublicIpAddress, LaunchTime]' \
  --output table

# Describe a specific instance
aws ec2 describe-instances --instance-ids <instance-id>

# List security groups
aws ec2 describe-security-groups \
  --query 'SecurityGroups[].[GroupId, GroupName, Description]' \
  --output table

# List key pairs
aws ec2 describe-key-pairs --query 'KeyPairs[].[KeyName, KeyPairId]' --output table

# List AMIs owned by you
aws ec2 describe-images --owners self \
  --query 'Images[].[ImageId, Name, CreationDate]' --output table

# Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id>
```

### Launch an Instance

⚠️ **Cost note:** EC2 charges per second (minimum 60s) based on instance type. A t3.medium in us-east-1 is ~$0.0416/hr (~$30/month). Always stop or terminate instances when done.

```bash
# Launch an instance
aws ec2 run-instances \
  --image-id <ami-id> \
  --instance-type t3.micro \
  --key-name <key-pair-name> \
  --security-group-ids <sg-id> \
  --subnet-id <subnet-id> \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=my-instance}]' \
  --count 1

# Find latest Amazon Linux 2023 AMI
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId, Name]' \
  --output text

# Find latest Ubuntu 24.04 AMI
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId, Name]' \
  --output text
```

### Instance Lifecycle

```bash
# Stop an instance (EBS-backed only — you still pay for EBS)
aws ec2 stop-instances --instance-ids <instance-id>

# Start a stopped instance
aws ec2 start-instances --instance-ids <instance-id>

# Reboot an instance
aws ec2 reboot-instances --instance-ids <instance-id>
```

### Security Groups

```bash
# Create a security group
aws ec2 create-security-group \
  --group-name my-sg \
  --description "My security group" \
  --vpc-id <vpc-id>

# Allow SSH from a specific IP
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp --port 22 \
  --cidr <your-ip>/32

# ⚠️ NEVER use 0.0.0.0/0 for SSH — always restrict to known IPs
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Terminate an instance (IRREVERSIBLE — all instance store data lost)
aws ec2 terminate-instances --instance-ids <instance-id>

# Delete a security group
aws ec2 delete-security-group --group-id <sg-id>

# Deregister an AMI
aws ec2 deregister-image --image-id <ami-id>

# Delete a snapshot
aws ec2 delete-snapshot --snapshot-id <snap-id>
```

## Safety Rules

1. **NEVER** terminate instances without explicit user confirmation and repeating the instance ID.
2. **NEVER** open security group ingress to `0.0.0.0/0` on SSH (port 22) or RDP (port 3389).
3. **NEVER** expose or log key pair private keys, credentials, or user data secrets.
4. **ALWAYS** confirm the target region before launching or terminating.
5. **ALWAYS** recommend tagging instances with at least a `Name` tag.
6. **ALWAYS** suggest enabling termination protection for production instances.
7. **WARN** about ongoing costs for running instances, EBS volumes, and Elastic IPs.

## Best Practices

- Use the latest generation instance types (t3/t4g over t2) for better price/performance.
- Enable termination protection on production instances: `--disable-api-termination`.
- Use IMDSv2 (Instance Metadata Service v2) for security: `--metadata-options HttpTokens=required`.
- Prefer IAM roles over access keys for applications running on EC2.
- Use placement groups for performance-sensitive workloads.
- Tag everything — at minimum: Name, Environment, Owner, Project.

## Common Patterns

### Pattern: Launch a Hardened Instance

```bash
AMI_ID=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name <key-name> \
  --security-group-ids <sg-id> \
  --subnet-id <subnet-id> \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
  --disable-api-termination \
  --tag-specifications \
    'ResourceType=instance,Tags=[{Key=Name,Value=my-app},{Key=Environment,Value=dev}]'
```

### Pattern: Find Unattached EBS Volumes (Cost Waste)

```bash
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].[VolumeId, Size, CreateTime]' \
  --output table
```

### Pattern: List Instances by Tag

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=production" \
  --query 'Reservations[].Instances[].[InstanceId, InstanceType, State.Name]' \
  --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `UnauthorizedOperation` | Missing IAM permissions | Add required `ec2:` actions to IAM policy |
| `InsufficientInstanceCapacity` | AZ out of capacity for type | Try a different AZ or instance type |
| `InvalidKeyPair.NotFound` | Key pair not in this region | Key pairs are region-specific — create or import one |
| `VPCResourceNotSpecified` | No default VPC and no subnet given | Specify `--subnet-id` explicitly |
