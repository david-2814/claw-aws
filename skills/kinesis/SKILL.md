---
name: kinesis
description: Manage Amazon Kinesis data streams, shards, consumers, and records via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🌊",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon Kinesis Data Streams

Use this skill for real-time data streaming: creating and managing data streams, putting and getting records, managing shards and consumers, and monitoring stream performance.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `kinesis:*` for full access, or scoped policies

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all streams
aws kinesis list-streams --output table

# Describe a stream
aws kinesis describe-stream-summary --stream-name <stream-name>

# Describe with full shard details
aws kinesis describe-stream --stream-name <stream-name>

# List shards
aws kinesis list-shards --stream-name <stream-name> --output table

# List stream consumers (enhanced fan-out)
aws kinesis list-stream-consumers --stream-arn <stream-arn> --output table

# Describe a consumer
aws kinesis describe-stream-consumer \
  --stream-arn <stream-arn> \
  --consumer-name <consumer-name>

# Get shard iterator (for reading records)
aws kinesis get-shard-iterator \
  --stream-name <stream-name> \
  --shard-id <shard-id> \
  --shard-iterator-type LATEST

# Get records from a shard
ITER=$(aws kinesis get-shard-iterator \
  --stream-name <stream-name> \
  --shard-id shardId-000000000000 \
  --shard-iterator-type TRIM_HORIZON \
  --query 'ShardIterator' --output text)
aws kinesis get-records --shard-iterator "$ITER" --limit 10

# List tags for a stream
aws kinesis list-tags-for-stream --stream-name <stream-name>
```

### Create and Configure

⚠️ **Cost note:** Kinesis charges per shard-hour ($0.015/hr ≈ $11/month per shard) plus $0.014 per million PUT payload units. On-demand mode charges $0.08 per GB written and $0.04 per GB read.

```bash
# Create a stream (provisioned mode)
aws kinesis create-stream \
  --stream-name <stream-name> \
  --shard-count 1

# Create a stream (on-demand mode)
aws kinesis create-stream \
  --stream-name <stream-name> \
  --stream-mode-details StreamMode=ON_DEMAND

# Update retention period (default 24h, max 8760h/365 days)
aws kinesis increase-stream-retention-period \
  --stream-name <stream-name> \
  --retention-period-hours 168

aws kinesis decrease-stream-retention-period \
  --stream-name <stream-name> \
  --retention-period-hours 24

# Switch between provisioned and on-demand
aws kinesis update-stream-mode \
  --stream-arn <stream-arn> \
  --stream-mode-details StreamMode=ON_DEMAND

# Register an enhanced fan-out consumer
aws kinesis register-stream-consumer \
  --stream-arn <stream-arn> \
  --consumer-name <consumer-name>

# Tag a stream
aws kinesis add-tags-to-stream \
  --stream-name <stream-name> \
  --tags Environment=production,Team=data

# Enable server-side encryption
aws kinesis start-stream-encryption \
  --stream-name <stream-name> \
  --encryption-type KMS \
  --key-id alias/aws/kinesis
```

### Put Records

```bash
# Put a single record
aws kinesis put-record \
  --stream-name <stream-name> \
  --partition-key <key> \
  --data "$(echo -n '{"event":"click","user":"123"}' | base64)"

# Put a record (CLI handles base64 automatically with fileb://)
echo -n '{"event":"click","user":"123"}' > /tmp/record.json
aws kinesis put-record \
  --stream-name <stream-name> \
  --partition-key user-123 \
  --data fileb:///tmp/record.json

# Put multiple records (batch — up to 500)
aws kinesis put-records \
  --stream-name <stream-name> \
  --records '[
    {"Data": "eyJldmVudCI6ImNsaWNrIn0=", "PartitionKey": "user-1"},
    {"Data": "eyJldmVudCI6InZpZXcifQ==", "PartitionKey": "user-2"}
  ]'
```

### Shard Management (Provisioned Mode)

```bash
# Scale up — split a shard
aws kinesis split-shard \
  --stream-name <stream-name> \
  --shard-to-split <shard-id> \
  --new-starting-hash-key <midpoint-hash>

# Scale down — merge two adjacent shards
aws kinesis merge-shards \
  --stream-name <stream-name> \
  --shard-to-merge <shard-id-1> \
  --adjacent-shard-to-merge <shard-id-2>

# Update shard count (easier than manual split/merge)
aws kinesis update-shard-count \
  --stream-name <stream-name> \
  --target-shard-count <count> \
  --scaling-type UNIFORM_SCALING
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a stream (IRREVERSIBLE — all data lost)
aws kinesis delete-stream --stream-name <stream-name>

# Deregister an enhanced fan-out consumer
aws kinesis deregister-stream-consumer \
  --stream-arn <stream-arn> \
  --consumer-name <consumer-name>

# Disable encryption
aws kinesis stop-stream-encryption \
  --stream-name <stream-name> \
  --encryption-type KMS \
  --key-id alias/aws/kinesis
```

## Safety Rules

1. **NEVER** delete a stream without explicit user confirmation — all data is lost immediately.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** confirm the target stream and region before write operations.
4. **ALWAYS** warn about data retention — records are deleted after the retention period.
5. **WARN** about cost differences between provisioned and on-demand modes.
6. **WARN** that shard splits/merges cause temporary increased costs during resharding.

## Best Practices

- Use on-demand mode for unpredictable workloads; provisioned for steady throughput.
- Enable server-side encryption with KMS for sensitive data.
- Use enhanced fan-out for low-latency, dedicated-throughput consumers.
- Design partition keys for even shard distribution to avoid hot shards.
- Monitor `WriteProvisionedThroughputExceeded` and `ReadProvisionedThroughputExceeded` metrics.

## Common Patterns

### Pattern: Read Latest Records from a Stream

```bash
# Get shard list
SHARD=$(aws kinesis list-shards --stream-name <stream-name> \
  --query 'Shards[0].ShardId' --output text)

# Get iterator for latest
ITER=$(aws kinesis get-shard-iterator \
  --stream-name <stream-name> \
  --shard-id $SHARD \
  --shard-iterator-type LATEST \
  --query 'ShardIterator' --output text)

# Read records (returns after 0-10 records or wait)
aws kinesis get-records --shard-iterator "$ITER" \
  --query 'Records[*].Data' --output text | while read data; do
  echo "$data" | base64 --decode
  echo
done
```

### Pattern: Monitor Stream Health

```bash
# Check incoming record rate
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis \
  --metric-name IncomingRecords \
  --dimensions Name=StreamName,Value=<stream-name> \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Sum --output table
```

### Pattern: Resize Stream Quickly

```bash
# Double the shard count
CURRENT=$(aws kinesis describe-stream-summary \
  --stream-name <stream-name> \
  --query 'StreamDescriptionSummary.OpenShardCount' --output text)

aws kinesis update-shard-count \
  --stream-name <stream-name> \
  --target-shard-count $((CURRENT * 2)) \
  --scaling-type UNIFORM_SCALING
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFoundException` | Stream doesn't exist | Verify stream name and region |
| `ProvisionedThroughputExceededException` | Exceeded shard write/read limits | Add shards or switch to on-demand mode |
| `KMSAccessDeniedException` | Missing KMS permissions | Add `kms:GenerateDataKey` and `kms:Decrypt` to IAM policy |
| `ExpiredIteratorException` | Shard iterator expired (5-min TTL) | Get a new iterator and retry |
| `ValidationException` on shard count | Target count exceeds limit | Default limit is 500 shards; request increase |
| Records out of order | Multiple shards with different partition keys | Use same partition key for ordered records |
