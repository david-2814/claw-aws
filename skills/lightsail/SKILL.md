---
name: lightsail
description: Manage Amazon Lightsail instances, databases, load balancers, domains, and snapshots via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "💡",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon Lightsail

Use this skill for simplified cloud operations: managing Lightsail instances, databases, container services, load balancers, static IPs, domains, and snapshots with predictable monthly pricing.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `lightsail:*` for full access, or scoped policies

## Common Operations

### List and Inspect (Read-Only)

```bash
# List instances
aws lightsail get-instances \
  --query 'instances[*].[name,state.name,blueprintId,bundleId,publicIpAddress]' --output table

# Get instance details
aws lightsail get-instance --instance-name <instance-name>

# Get instance metrics
aws lightsail get-instance-metric-data \
  --instance-name <instance-name> \
  --metric-name CPUUtilization \
  --period 300 \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --statistics Average \
  --unit Percent

# List available blueprints (OS/app images)
aws lightsail get-blueprints \
  --query 'blueprints[?isActive==`true`].[blueprintId,name,type,platform]' --output table

# List available bundles (pricing plans)
aws lightsail get-bundles \
  --query 'bundles[?isActive==`true`].[bundleId,name,price,cpuCount,ramSizeInGb,diskSizeInGb,transferPerMonthInGb]' --output table

# List databases
aws lightsail get-relational-databases \
  --query 'relationalDatabases[*].[name,engine,masterDatabaseName,state]' --output table

# Get database details
aws lightsail get-relational-database --relational-database-name <db-name>

# List load balancers
aws lightsail get-load-balancers \
  --query 'loadBalancers[*].[name,dnsName,state,instancePort]' --output table

# List static IPs
aws lightsail get-static-ips \
  --query 'staticIps[*].[name,ipAddress,isAttached,attachedTo]' --output table

# List snapshots
aws lightsail get-instance-snapshots \
  --query 'instanceSnapshots[*].[name,fromInstanceName,state,createdAt]' --output table

# List disks
aws lightsail get-disks \
  --query 'disks[*].[name,sizeInGb,state,isAttached,attachedTo]' --output table

# List domains
aws lightsail get-domains \
  --query 'domains[*].[name,domainEntries[*].name]' --output table

# List container services
aws lightsail get-container-services \
  --query 'containerServices[*].[containerServiceName,state,power,scale,url]' --output table

# List key pairs
aws lightsail get-key-pairs \
  --query 'keyPairs[*].[name,createdAt,fingerprint]' --output table

# Get active region names
aws lightsail get-regions --include-availability-zones \
  --query 'regions[*].[name,displayName]' --output table
```

### Create Instances

⚠️ **Cost note:** Lightsail has fixed monthly pricing. nano ($3.50/mo), micro ($5/mo), small ($10/mo), medium ($20/mo), large ($40/mo). Includes data transfer allowance.

```bash
# Create an instance (Ubuntu)
aws lightsail create-instances \
  --instance-names <instance-name> \
  --availability-zone <region>a \
  --blueprint-id ubuntu_22_04 \
  --bundle-id nano_3_2

# Create with WordPress blueprint
aws lightsail create-instances \
  --instance-names <instance-name> \
  --availability-zone <region>a \
  --blueprint-id wordpress \
  --bundle-id small_3_0

# Create with key pair
aws lightsail create-instances \
  --instance-names <instance-name> \
  --availability-zone <region>a \
  --blueprint-id amazon_linux_2023 \
  --bundle-id micro_3_0 \
  --key-pair-name <key-pair-name>

# Create with user data
aws lightsail create-instances \
  --instance-names <instance-name> \
  --availability-zone <region>a \
  --blueprint-id ubuntu_22_04 \
  --bundle-id micro_3_0 \
  --user-data "#!/bin/bash
apt-get update && apt-get install -y nginx"

# Allocate and attach a static IP
aws lightsail allocate-static-ip --static-ip-name <ip-name>
aws lightsail attach-static-ip \
  --static-ip-name <ip-name> \
  --instance-name <instance-name>

# Open ports
aws lightsail open-instance-public-ports \
  --instance-name <instance-name> \
  --port-info fromPort=443,toPort=443,protocol=tcp

# Create a key pair
aws lightsail create-key-pair --key-pair-name <key-pair-name>
```

### Databases

```bash
# Create a managed database
aws lightsail create-relational-database \
  --relational-database-name <db-name> \
  --relational-database-blueprint-id mysql_8_0 \
  --relational-database-bundle-id micro_2_0 \
  --master-database-name mydb \
  --master-username admin \
  --availability-zone <region>a

# Create a database snapshot
aws lightsail create-relational-database-snapshot \
  --relational-database-name <db-name> \
  --relational-database-snapshot-name <snapshot-name>

# Get database credentials
aws lightsail get-relational-database-master-user-password \
  --relational-database-name <db-name>
```

### Snapshots and Backups

```bash
# Create an instance snapshot
aws lightsail create-instance-snapshot \
  --instance-name <instance-name> \
  --instance-snapshot-name <snapshot-name>

# Create instance from snapshot
aws lightsail create-instances-from-snapshot \
  --instance-names <new-instance-name> \
  --availability-zone <region>a \
  --instance-snapshot-name <snapshot-name> \
  --bundle-id small_3_0

# Enable automatic snapshots
aws lightsail enable-add-on \
  --resource-name <instance-name> \
  --add-on-request addOnType=AutoSnapshot,autoSnapshotAddOnRequest={snapshotTimeOfDay=06:00}
```

### Instance Control

```bash
# Stop an instance
aws lightsail stop-instance --instance-name <instance-name>

# Start an instance
aws lightsail start-instance --instance-name <instance-name>

# Reboot an instance
aws lightsail reboot-instance --instance-name <instance-name>
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete an instance
aws lightsail delete-instance --instance-name <instance-name>

# Delete an instance and its snapshots
aws lightsail delete-instance --instance-name <instance-name> --force-delete-add-ons

# Delete a database
aws lightsail delete-relational-database --relational-database-name <db-name>

# Delete with final snapshot
aws lightsail delete-relational-database \
  --relational-database-name <db-name> \
  --final-relational-database-snapshot-name <final-snapshot>

# Delete a snapshot
aws lightsail delete-instance-snapshot --instance-snapshot-name <snapshot-name>

# Release a static IP
aws lightsail release-static-ip --static-ip-name <ip-name>
```

## Safety Rules

1. **NEVER** delete instances or databases without explicit user confirmation.
2. **NEVER** expose or log database passwords, key pairs, or AWS credentials.
3. **ALWAYS** recommend creating a snapshot before deleting instances.
4. **ALWAYS** confirm the instance name and region before destructive operations.
5. **WARN** that releasing a static IP makes it permanently unavailable.
6. **WARN** about data transfer overage charges beyond the monthly allowance.

## Best Practices

- Use static IPs for production instances (IPs change on stop/start otherwise).
- Enable automatic snapshots for all production instances.
- Use the smallest bundle that meets your needs — you can always upgrade.
- Use Lightsail databases for managed PostgreSQL/MySQL instead of self-managing.
- Consider migrating to EC2/RDS if you outgrow Lightsail's feature set.

## Common Patterns

### Pattern: Quick Web Server Setup

```bash
# Create instance, static IP, and open ports
aws lightsail create-instances \
  --instance-names web-server \
  --availability-zone us-east-1a \
  --blueprint-id ubuntu_22_04 \
  --bundle-id micro_3_0

aws lightsail allocate-static-ip --static-ip-name web-server-ip
aws lightsail attach-static-ip --static-ip-name web-server-ip --instance-name web-server
aws lightsail open-instance-public-ports \
  --instance-name web-server \
  --port-info fromPort=80,toPort=80,protocol=tcp
aws lightsail open-instance-public-ports \
  --instance-name web-server \
  --port-info fromPort=443,toPort=443,protocol=tcp
```

### Pattern: SSH into Instance

```bash
# Download key pair and connect
aws lightsail download-default-key-pair \
  --query 'privateKeyBase64' --output text | base64 -d > lightsail-key.pem
chmod 600 lightsail-key.pem

IP=$(aws lightsail get-instance --instance-name <instance-name> \
  --query 'instance.publicIpAddress' --output text)
ssh -i lightsail-key.pem ubuntu@$IP
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NotFoundException` | Instance or resource doesn't exist | Verify name with `get-instances` |
| `InvalidInputException` | Invalid blueprint or bundle ID | Check available options with `get-blueprints`/`get-bundles` |
| Can't connect via SSH | Port 22 not open or key mismatch | Check `get-instance-port-states`; verify key pair |
| `OperationFailureException` | Resource in invalid state | Wait for pending operations to complete |
| Static IP not working | Not attached to instance | Check with `get-static-ips`; re-attach if needed |
| Database connection refused | Public mode not enabled or SG issue | Enable public mode or connect from Lightsail instances |
