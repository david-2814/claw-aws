---
name: elasticache
description: Manage Amazon ElastiCache clusters, replication groups, users, and snapshots for Redis and Memcached via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "⚡",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon ElastiCache

Use this skill for in-memory caching and data store operations: creating and managing Redis and Memcached clusters, configuring replication groups, managing snapshots, scaling, and monitoring cache performance.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `elasticache:*` for full access, or scoped policies
- VPC with appropriate subnets and security groups (ElastiCache runs inside a VPC)
- `redis-cli` or `memcached` client for testing connectivity

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all cache clusters
aws elasticache describe-cache-clusters --output table

# List clusters with detailed node info
aws elasticache describe-cache-clusters --show-cache-node-info \
  --query 'CacheClusters[*].[CacheClusterId,Engine,EngineVersion,CacheNodeType,NumCacheNodes,CacheClusterStatus]' \
  --output table

# Describe a specific cluster
aws elasticache describe-cache-clusters --cache-cluster-id <cluster-id> --show-cache-node-info

# List replication groups (Redis with replicas)
aws elasticache describe-replication-groups --output table

# Describe a replication group
aws elasticache describe-replication-groups --replication-group-id <group-id>

# List cache subnet groups
aws elasticache describe-cache-subnet-groups --output table

# List parameter groups
aws elasticache describe-cache-parameter-groups --output table

# List cache engine versions
aws elasticache describe-cache-engine-versions --engine redis --output table

# List snapshots
aws elasticache describe-snapshots --output table

# List users (Redis AUTH)
aws elasticache describe-users --output table

# List user groups
aws elasticache describe-user-groups --output table

# List reserved cache nodes
aws elasticache describe-reserved-cache-nodes --output table

# List events
aws elasticache describe-events --duration 1440 --output table
```

### Create Clusters

⚠️ **Cost note:** ElastiCache pricing depends on node type. cache.t3.micro starts at ~$0.017/hr (~$12/month). Production nodes (cache.r6g.large) are ~$0.18/hr (~$130/month). Data transfer charges apply.

```bash
# Create a single-node Redis cluster (dev/test)
aws elasticache create-cache-cluster \
  --cache-cluster-id <cluster-id> \
  --engine redis \
  --cache-node-type cache.t3.micro \
  --num-cache-nodes 1 \
  --cache-subnet-group-name <subnet-group> \
  --security-group-ids <sg-id>

# Create a Memcached cluster
aws elasticache create-cache-cluster \
  --cache-cluster-id <cluster-id> \
  --engine memcached \
  --cache-node-type cache.t3.micro \
  --num-cache-nodes 2 \
  --cache-subnet-group-name <subnet-group> \
  --security-group-ids <sg-id>

# Create a Redis replication group (cluster mode disabled)
aws elasticache create-replication-group \
  --replication-group-id <group-id> \
  --replication-group-description "Production Redis" \
  --engine redis \
  --cache-node-type cache.r6g.large \
  --num-cache-clusters 3 \
  --automatic-failover-enabled \
  --multi-az-enabled \
  --cache-subnet-group-name <subnet-group> \
  --security-group-ids <sg-id> \
  --at-rest-encryption-enabled \
  --transit-encryption-enabled

# Create a Redis cluster (cluster mode enabled — sharded)
aws elasticache create-replication-group \
  --replication-group-id <group-id> \
  --replication-group-description "Sharded Redis" \
  --engine redis \
  --cache-node-type cache.r6g.large \
  --num-node-groups 3 \
  --replicas-per-node-group 2 \
  --automatic-failover-enabled \
  --cache-subnet-group-name <subnet-group> \
  --security-group-ids <sg-id> \
  --at-rest-encryption-enabled \
  --transit-encryption-enabled

# Create a cache subnet group
aws elasticache create-cache-subnet-group \
  --cache-subnet-group-name <group-name> \
  --cache-subnet-group-description "ElastiCache subnets" \
  --subnet-ids <subnet-1> <subnet-2> <subnet-3>
```

### Modify and Scale

```bash
# Scale vertically (change node type) — requires replication group
aws elasticache modify-replication-group \
  --replication-group-id <group-id> \
  --cache-node-type cache.r6g.xlarge \
  --apply-immediately

# Add a read replica
aws elasticache increase-replica-count \
  --replication-group-id <group-id> \
  --new-replica-count 3 \
  --apply-immediately

# Scale out shards (cluster mode enabled)
aws elasticache modify-replication-group-shard-configuration \
  --replication-group-id <group-id> \
  --node-group-count 4 \
  --apply-immediately

# Modify cluster parameters
aws elasticache modify-cache-cluster \
  --cache-cluster-id <cluster-id> \
  --cache-parameter-group-name <param-group> \
  --apply-immediately
```

### Snapshots

```bash
# Create a manual snapshot
aws elasticache create-snapshot \
  --replication-group-id <group-id> \
  --snapshot-name <snapshot-name>

# Copy a snapshot
aws elasticache copy-snapshot \
  --source-snapshot-name <source-snap> \
  --target-snapshot-name <target-snap>

# Export snapshot to S3
aws elasticache copy-snapshot \
  --source-snapshot-name <snapshot-name> \
  --target-snapshot-name <export-name> \
  --target-bucket <s3-bucket>
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a cache cluster
aws elasticache delete-cache-cluster --cache-cluster-id <cluster-id>

# Delete with final snapshot
aws elasticache delete-cache-cluster \
  --cache-cluster-id <cluster-id> \
  --final-snapshot-identifier <snapshot-name>

# Delete a replication group
aws elasticache delete-replication-group --replication-group-id <group-id>

# Delete a replication group with snapshot
aws elasticache delete-replication-group \
  --replication-group-id <group-id> \
  --final-snapshot-identifier <snapshot-name>

# Delete a snapshot
aws elasticache delete-snapshot --snapshot-name <snapshot-name>
```

## Safety Rules

1. **NEVER** delete clusters or replication groups without explicit user confirmation.
2. **NEVER** expose or log AWS credentials, Redis AUTH tokens, or passwords.
3. **ALWAYS** recommend creating a final snapshot before deleting clusters.
4. **ALWAYS** confirm the target cluster/region before write operations.
5. **WARN** about cost implications for larger node types and multi-AZ configurations.
6. **WARN** that `--apply-immediately` causes brief downtime for some modifications.

## Best Practices

- Use replication groups with Multi-AZ and automatic failover for production.
- Enable at-rest encryption and in-transit encryption for sensitive data.
- Use Redis AUTH (user groups) to control access.
- Monitor with CloudWatch: `CPUUtilization`, `EngineCPUUtilization`, `CurrConnections`, `Evictions`.
- Use reserved nodes for predictable workloads to save 30-60%.

## Common Patterns

### Pattern: Production-Ready Redis Setup

```bash
# Create subnet group
aws elasticache create-cache-subnet-group \
  --cache-subnet-group-name prod-redis-subnets \
  --cache-subnet-group-description "Production Redis" \
  --subnet-ids subnet-aaa subnet-bbb subnet-ccc

# Create replication group with encryption and failover
aws elasticache create-replication-group \
  --replication-group-id prod-redis \
  --replication-group-description "Production Redis with HA" \
  --engine redis \
  --engine-version 7.0 \
  --cache-node-type cache.r6g.large \
  --num-cache-clusters 3 \
  --automatic-failover-enabled \
  --multi-az-enabled \
  --at-rest-encryption-enabled \
  --transit-encryption-enabled \
  --cache-subnet-group-name prod-redis-subnets \
  --security-group-ids sg-xxx \
  --snapshot-retention-limit 7
```

### Pattern: Test Connectivity

```bash
# Get the endpoint
ENDPOINT=$(aws elasticache describe-replication-groups \
  --replication-group-id <group-id> \
  --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' \
  --output text)

echo "Endpoint: $ENDPOINT"
# Then: redis-cli -h $ENDPOINT -p 6379
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `CacheClusterNotFound` | Cluster doesn't exist | Verify name/region with `describe-cache-clusters` |
| Connection timeout | Security group blocks access | Ensure SG allows port 6379 (Redis) or 11211 (Memcached) |
| `InsufficientCacheClusterCapacity` | Node type unavailable in AZ | Try a different node type or AZ |
| `ReplicationGroupNotFoundFault` | Replication group doesn't exist | Verify with `describe-replication-groups` |
| `InvalidParameterCombination` | Conflicting cluster-mode settings | Cluster mode enabled requires `--num-node-groups` instead of `--num-cache-clusters` |
| Evictions increasing | Memory pressure | Scale up node type or add shards |
