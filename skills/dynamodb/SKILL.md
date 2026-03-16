---
name: dynamodb
description: Manage Amazon DynamoDB tables, items, indexes, and backups for NoSQL database operations via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "⚡",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon DynamoDB

Use this skill for DynamoDB operations: creating and managing tables, querying and scanning data, managing indexes, configuring capacity and auto-scaling, and handling backups.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `dynamodb:*` for full access
- For streams: `dynamodb:*Stream*` permissions

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all tables
aws dynamodb list-tables --output table

# Describe a table (schema, capacity, indexes, size)
aws dynamodb describe-table --table-name <table-name>

# Get table key schema and indexes
aws dynamodb describe-table --table-name <table-name> \
  --query 'Table.{Keys:KeySchema, GSIs:GlobalSecondaryIndexes[].{Name:IndexName, Keys:KeySchema, Status:IndexStatus}, Items:ItemCount, Size:TableSizeBytes}'

# Get table capacity mode and throughput
aws dynamodb describe-table --table-name <table-name> \
  --query 'Table.{Mode:BillingModeSummary.BillingMode, Read:ProvisionedThroughput.ReadCapacityUnits, Write:ProvisionedThroughput.WriteCapacityUnits}'

# List backups
aws dynamodb list-backups --table-name <table-name> \
  --query 'BackupSummaries[].[BackupName, BackupStatus, BackupCreationDateTime]' --output table

# Describe continuous backups (PITR)
aws dynamodb describe-continuous-backups --table-name <table-name>
```

### Query and Scan

```bash
# Get a single item by key
aws dynamodb get-item \
  --table-name <table-name> \
  --key '{"pk": {"S": "<partition-key-value>"}, "sk": {"S": "<sort-key-value>"}}'

# Query by partition key
aws dynamodb query \
  --table-name <table-name> \
  --key-condition-expression "pk = :pk" \
  --expression-attribute-values '{":pk": {"S": "<value>"}}' \
  --output json

# Query with sort key condition
aws dynamodb query \
  --table-name <table-name> \
  --key-condition-expression "pk = :pk AND begins_with(sk, :prefix)" \
  --expression-attribute-values '{":pk": {"S": "<value>"}, ":prefix": {"S": "<prefix>"}}'

# Query a GSI
aws dynamodb query \
  --table-name <table-name> \
  --index-name <gsi-name> \
  --key-condition-expression "gsiPk = :val" \
  --expression-attribute-values '{":val": {"S": "<value>"}}'

# Scan (use sparingly — reads entire table)
aws dynamodb scan --table-name <table-name> --max-items 10

# Scan with filter
aws dynamodb scan \
  --table-name <table-name> \
  --filter-expression "attribute_exists(email)" \
  --max-items 20

# Count items (scan without returning data)
aws dynamodb scan --table-name <table-name> --select COUNT
```

### Write Operations

```bash
# Put an item
aws dynamodb put-item \
  --table-name <table-name> \
  --item '{
    "pk": {"S": "user#123"},
    "sk": {"S": "profile"},
    "name": {"S": "Jane Doe"},
    "email": {"S": "jane@example.com"},
    "created": {"S": "2026-01-15T00:00:00Z"}
  }'

# Update an item
aws dynamodb update-item \
  --table-name <table-name> \
  --key '{"pk": {"S": "user#123"}, "sk": {"S": "profile"}}' \
  --update-expression "SET #n = :name, updatedAt = :ts" \
  --expression-attribute-names '{"#n": "name"}' \
  --expression-attribute-values '{":name": {"S": "Jane Smith"}, ":ts": {"S": "2026-03-15T00:00:00Z"}}'

# Conditional put (only if item doesn't exist)
aws dynamodb put-item \
  --table-name <table-name> \
  --item '{"pk": {"S": "user#123"}, "sk": {"S": "profile"}}' \
  --condition-expression "attribute_not_exists(pk)"

# Batch write (up to 25 items)
aws dynamodb batch-write-item --request-items file://batch-write.json
```

### Create a Table

⚠️ **Cost note:** On-demand mode charges per request (~$1.25/million writes, ~$0.25/million reads). Provisioned mode charges per RCU/WCU per hour. For unpredictable workloads, start with on-demand.

```bash
# Create a table (on-demand mode)
aws dynamodb create-table \
  --table-name <table-name> \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=my-app

# Wait for table to be active
aws dynamodb wait table-exists --table-name <table-name>

# Enable PITR (Point-in-Time Recovery)
aws dynamodb update-continuous-backups \
  --table-name <table-name> \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

# Enable TTL
aws dynamodb update-time-to-live \
  --table-name <table-name> \
  --time-to-live-specification Enabled=true,AttributeName=ttl
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete an item
aws dynamodb delete-item \
  --table-name <table-name> \
  --key '{"pk": {"S": "<value>"}, "sk": {"S": "<value>"}}'

# Delete a table (ALL DATA PERMANENTLY LOST)
aws dynamodb delete-table --table-name <table-name>
```

## Safety Rules

1. **NEVER** delete a table without explicit user confirmation — all data is permanently lost.
2. **NEVER** run unfiltered `scan` on large production tables — it consumes all capacity and can cause throttling.
3. **ALWAYS** confirm the table name and region before write operations.
4. **ALWAYS** use `--max-items` or `--limit` when scanning to avoid runaway reads.
5. **ALWAYS** recommend enabling PITR on tables with important data.
6. **PREFER** `query` over `scan` — queries are targeted and efficient; scans read everything.
7. **WARN** about capacity consumption when running large queries or scans.

## Best Practices

- Design keys for your access patterns first — DynamoDB is query-driven, not schema-driven.
- Enable Point-in-Time Recovery (PITR) on all production tables.
- Use on-demand capacity for unpredictable workloads; provisioned with auto-scaling for steady traffic.
- Use GSIs sparingly — each GSI doubles write costs for the projected attributes.
- Use TTL to automatically expire stale data and save storage costs.
- Use single-table design patterns where appropriate to minimize the number of tables.

## Common Patterns

### Pattern: Create a Production-Ready Table

```bash
TABLE="my-app-data"
aws dynamodb create-table \
  --table-name $TABLE \
  --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=my-app Key=Environment,Value=prod
aws dynamodb wait table-exists --table-name $TABLE
aws dynamodb update-continuous-backups --table-name $TABLE \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
echo "Table $TABLE created with PITR enabled."
```

### Pattern: Export Table to S3 (For Analysis)

```bash
aws dynamodb export-table-to-point-in-time \
  --table-arn arn:aws:dynamodb:<region>:<account-id>:table/<table-name> \
  --s3-bucket <export-bucket> \
  --s3-prefix exports/ \
  --export-format DYNAMODB_JSON
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ProvisionedThroughputExceededException` | Exceeded table/index capacity | Switch to on-demand, enable auto-scaling, or raise provisioned capacity |
| `ValidationException` | Key schema mismatch or bad expression | Check that key attributes match the table definition |
| `ResourceNotFoundException` | Table doesn't exist | Verify table name and region |
| `ConditionalCheckFailedException` | Condition expression evaluated to false | Expected in conditional writes — handle in application logic |
| `ItemCollectionSizeLimitExceededException` | Partition exceeds 10GB (with LSI) | Redesign partition key to distribute data more evenly |
