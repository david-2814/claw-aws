---
name: rds
description: Manage Amazon RDS database instances, clusters, snapshots, and backups for relational databases via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🗄️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon RDS

Use this skill for Relational Database Service operations: managing DB instances and Aurora clusters, creating and restoring snapshots, configuring parameter groups, monitoring performance, and handling maintenance windows.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `rds:*` for full access
- A VPC with a DB subnet group for production deployments

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all DB instances
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier, Engine, EngineVersion, DBInstanceClass, DBInstanceStatus, Endpoint.Address]' \
  --output table

# Describe a specific instance (full details)
aws rds describe-db-instances --db-instance-identifier <db-id>

# Get connection endpoint
aws rds describe-db-instances --db-instance-identifier <db-id> \
  --query 'DBInstances[0].{Endpoint:Endpoint.Address, Port:Endpoint.Port, Status:DBInstanceStatus}'

# List Aurora clusters
aws rds describe-db-clusters \
  --query 'DBClusters[].[DBClusterIdentifier, Engine, EngineVersion, Status, Endpoint]' \
  --output table

# List snapshots for an instance
aws rds describe-db-snapshots --db-instance-identifier <db-id> \
  --query 'DBSnapshots[].[DBSnapshotIdentifier, Status, SnapshotCreateTime, AllocatedStorage]' \
  --output table

# List automated backups
aws rds describe-db-instance-automated-backups --db-instance-identifier <db-id>

# Check pending maintenance
aws rds describe-pending-maintenance-actions \
  --query 'PendingMaintenanceActions[].[ResourceIdentifier, PendingMaintenanceActionDetails[].{Action:Action, AutoAppliedAfterDate:AutoAppliedAfterDate}]'

# Check parameter group settings
aws rds describe-db-parameters --db-parameter-group-name <group-name> \
  --query 'Parameters[?IsModifiable==`true`].[ParameterName, ParameterValue, ApplyMethod]' \
  --output table
```

### Create a DB Instance

⚠️ **Cost note:** RDS pricing varies significantly by instance class and engine. A db.t3.micro (free tier eligible) costs ~$12/month. A db.r6g.large runs ~$175/month. Multi-AZ doubles the instance cost. Always check pricing for the specific configuration.

```bash
# Create a PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier <db-id> \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 16.4 \
  --master-username admin \
  --manage-master-user-password \
  --allocated-storage 20 \
  --storage-type gp3 \
  --vpc-security-group-ids <sg-id> \
  --db-subnet-group-name <subnet-group> \
  --backup-retention-period 7 \
  --storage-encrypted \
  --no-publicly-accessible \
  --tags Key=Project,Value=my-app Key=Environment,Value=dev

# Wait for instance to be available
aws rds wait db-instance-available --db-instance-identifier <db-id>

# Create an Aurora Serverless v2 cluster
aws rds create-db-cluster \
  --db-cluster-identifier <cluster-id> \
  --engine aurora-postgresql \
  --engine-version 16.4 \
  --master-username admin \
  --manage-master-user-password \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=4 \
  --vpc-security-group-ids <sg-id> \
  --db-subnet-group-name <subnet-group> \
  --storage-encrypted
```

### Modify and Maintain

```bash
# Scale instance class (applies during maintenance window by default)
aws rds modify-db-instance \
  --db-instance-identifier <db-id> \
  --db-instance-class db.t3.medium \
  --apply-immediately  # or remove this for next maintenance window

# Increase storage
aws rds modify-db-instance \
  --db-instance-identifier <db-id> \
  --allocated-storage 50

# Create a manual snapshot (before risky changes)
aws rds create-db-snapshot \
  --db-instance-identifier <db-id> \
  --db-snapshot-identifier <db-id>-manual-$(date +%Y%m%d)

# Restore from a snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier <new-db-id> \
  --db-snapshot-identifier <snapshot-id>

# Enable Performance Insights
aws rds modify-db-instance \
  --db-instance-identifier <db-id> \
  --enable-performance-insights \
  --performance-insights-retention-period 7

# Reboot instance (applies pending parameter changes)
aws rds reboot-db-instance --db-instance-identifier <db-id>
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Database deletion is irreversible unless a final snapshot is taken. Always confirm.**

```bash
# Delete an instance WITH a final snapshot (RECOMMENDED)
aws rds delete-db-instance \
  --db-instance-identifier <db-id> \
  --final-db-snapshot-identifier <db-id>-final-$(date +%Y%m%d)

# Delete an instance WITHOUT a final snapshot (DATA PERMANENTLY LOST)
aws rds delete-db-instance \
  --db-instance-identifier <db-id> \
  --skip-final-snapshot \
  --delete-automated-backups

# Delete a snapshot
aws rds delete-db-snapshot --db-snapshot-identifier <snapshot-id>
```

## Safety Rules

1. **NEVER** delete a DB instance without explicit user confirmation and offering a final snapshot.
2. **NEVER** use `--skip-final-snapshot` on production databases unless the user explicitly confirms data loss.
3. **NEVER** make the database publicly accessible (`--publicly-accessible`) unless the user has a clear reason.
4. **NEVER** display or log database master passwords.
5. **ALWAYS** recommend `--manage-master-user-password` (Secrets Manager integration) over plaintext passwords.
6. **ALWAYS** recommend enabling encryption at rest (`--storage-encrypted`).
7. **ALWAYS** take a manual snapshot before major modifications (class change, engine upgrade).
8. **WARN** about Multi-AZ cost implications before enabling.
9. **WARN** about downtime during instance class changes unless Multi-AZ is enabled.

## Best Practices

- Enable encryption at rest for all databases — it's free and can't be added later.
- Use `--manage-master-user-password` to store credentials in Secrets Manager automatically.
- Enable automated backups with at least 7 days retention.
- Enable Performance Insights for query-level monitoring.
- Use Multi-AZ for production workloads (automatic failover).
- Never make RDS instances publicly accessible — use a bastion host or VPN.
- Use parameter groups for engine tuning instead of modifying defaults.

## Common Patterns

### Pattern: Pre-Modification Safety Snapshot

```bash
DB="my-database"
SNAP="${DB}-pre-change-$(date +%Y%m%d-%H%M)"

echo "Creating safety snapshot: $SNAP"
aws rds create-db-snapshot --db-instance-identifier $DB --db-snapshot-identifier $SNAP
aws rds wait db-snapshot-available --db-snapshot-identifier $SNAP
echo "Snapshot ready. Safe to proceed with modifications."
```

### Pattern: Find Oversized Instances (Cost Optimization)

```bash
for db in $(aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text); do
  aws rds describe-db-instances --db-instance-identifier $db \
    --query 'DBInstances[0].[DBInstanceIdentifier, DBInstanceClass, Engine, AllocatedStorage]' \
    --output text
done
```

### Pattern: Check Encryption Status Across All Instances

```bash
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier, StorageEncrypted, Engine]' \
  --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `DBInstanceNotFound` | Instance doesn't exist in this region | Verify the identifier and region |
| `InsufficientDBInstanceCapacity` | Instance class not available in AZ | Try a different AZ or instance class |
| `StorageQuotaExceeded` | Account storage limit reached | Request a limit increase via Service Quotas |
| `InvalidDBInstanceState` | Instance is in a state that doesn't allow the operation | Wait for the instance to be `available` |
| `DBSnapshotAlreadyExists` | Snapshot name taken | Use a unique snapshot identifier |
| Connection refused | Security group not allowing traffic | Check SG inbound rules for the DB port (5432/3306) |
