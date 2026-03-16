---
name: athena
description: Query data in S3 using Amazon Athena with SQL, manage workgroups, named queries, and query history via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔎",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon Athena

Use this skill for interactive SQL queries against data in S3: running queries, managing workgroups and named queries, viewing query history, and configuring result locations.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `athena:*`, `s3:*` (for data and results), `glue:*` (for data catalog)
- S3 bucket for query results
- Data cataloged in AWS Glue Data Catalog

## Common Operations

### List and Inspect (Read-Only)

```bash
# List workgroups
aws athena list-work-groups --output table

# Get workgroup details
aws athena get-work-group --work-group <workgroup-name>

# List databases (via Glue catalog)
aws athena list-databases --catalog-name AwsDataCatalog \
  --query 'DatabaseList[*].Name' --output table

# List tables in a database
aws athena list-table-metadata \
  --catalog-name AwsDataCatalog \
  --database-name <database-name> \
  --query 'TableMetadataList[*].[Name,TableType]' --output table

# Get table metadata (columns)
aws athena get-table-metadata \
  --catalog-name AwsDataCatalog \
  --database-name <database-name> \
  --table-name <table-name>

# List named queries (saved queries)
aws athena list-named-queries

# Get a named query
aws athena get-named-query --named-query-id <query-id>

# List recent query executions
aws athena list-query-executions --work-group <workgroup-name> \
  --query 'QueryExecutionIds[:10]' --output text

# Get query execution details
aws athena get-query-execution --query-execution-id <execution-id>

# Batch get query execution details
aws athena batch-get-query-execution \
  --query-execution-ids <id-1> <id-2> <id-3> \
  --query 'QueryExecutions[*].[QueryExecutionId,Query,Status.State,Statistics.DataScannedInBytes]' \
  --output table

# List prepared statements
aws athena list-prepared-statements --work-group <workgroup-name> --output table
```

### Run Queries

⚠️ **Cost note:** Athena charges $5.00 per TB of data scanned. Use partitions, columnar formats (Parquet/ORC), and `LIMIT` to reduce costs. Cancelled queries are charged for data already scanned.

```bash
# Run a query
aws athena start-query-execution \
  --query-string "SELECT * FROM <database>.<table> LIMIT 10" \
  --work-group <workgroup-name> \
  --result-configuration '{"OutputLocation": "s3://<bucket>/athena-results/"}'

# Run a query and wait for results
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT COUNT(*) as total FROM <database>.<table>" \
  --work-group <workgroup-name> \
  --query 'QueryExecutionId' --output text)

# Check query status
aws athena get-query-execution --query-execution-id $QUERY_ID \
  --query 'QueryExecution.Status.[State,StateChangeReason]' --output text

# Get query results (after completion)
aws athena get-query-results --query-execution-id $QUERY_ID --output table

# Get results with max rows
aws athena get-query-results --query-execution-id $QUERY_ID --max-results 50 --output table

# Stop a running query
aws athena stop-query-execution --query-execution-id <execution-id>

# Run a DDL query (CREATE TABLE)
aws athena start-query-execution \
  --query-string "
    CREATE EXTERNAL TABLE <database>.<table> (
      id BIGINT,
      name STRING,
      created_at TIMESTAMP
    )
    STORED AS PARQUET
    LOCATION 's3://<bucket>/<prefix>/'
  " \
  --work-group <workgroup-name>

# Create a named query (saved for reuse)
aws athena create-named-query \
  --name "daily-report" \
  --database <database-name> \
  --query-string "SELECT date, COUNT(*) as events FROM events WHERE date = current_date GROUP BY date" \
  --work-group <workgroup-name> \
  --description "Daily event count report"
```

### Workgroup Management

```bash
# Create a workgroup
aws athena create-work-group \
  --name <workgroup-name> \
  --configuration '{
    "ResultConfiguration": {
      "OutputLocation": "s3://<bucket>/athena-results/",
      "EncryptionConfiguration": {"EncryptionOption": "SSE_S3"}
    },
    "EnforceWorkGroupConfiguration": true,
    "PublishCloudWatchMetricsEnabled": true,
    "BytesScannedCutoffPerQuery": 1073741824
  }' \
  --description "Team workgroup with 1GB scan limit"

# Update workgroup (add scan limit)
aws athena update-work-group \
  --work-group <workgroup-name> \
  --configuration-updates '{
    "BytesScannedCutoffPerQuery": 10737418240
  }'

# Create a prepared statement
aws athena create-prepared-statement \
  --statement-name get-user \
  --work-group <workgroup-name> \
  --query-statement "SELECT * FROM users WHERE user_id = ?"
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a named query
aws athena delete-named-query --named-query-id <query-id>

# Delete a workgroup (must be empty)
aws athena delete-work-group --work-group <workgroup-name>

# Force delete a workgroup (removes all saved queries)
aws athena delete-work-group --work-group <workgroup-name> --recursive-delete-option
```

## Safety Rules

1. **NEVER** run queries without considering data scan costs — always estimate first.
2. **NEVER** expose or log AWS credentials.
3. **ALWAYS** use `LIMIT` for exploratory queries to control cost.
4. **ALWAYS** confirm the database and table before running queries.
5. **WARN** about scan costs before running queries on large unpartitioned tables.
6. **WARN** that `DROP TABLE` in Athena drops the Glue catalog entry, not the S3 data.

## Best Practices

- Use Parquet or ORC formats to reduce data scanned (columnar → only read needed columns).
- Partition data by common query dimensions (date, region, etc.).
- Set `BytesScannedCutoffPerQuery` on workgroups to prevent accidental expensive queries.
- Use workgroups to isolate teams and control costs.
- Enable CloudWatch metrics on workgroups for query monitoring.

## Common Patterns

### Pattern: Run Query and Get Results

```bash
# One-shot: submit, wait, fetch
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT * FROM logs.access_logs WHERE date = '2024-01-15' LIMIT 100" \
  --work-group primary \
  --query 'QueryExecutionId' --output text)

# Poll until complete
while true; do
  STATE=$(aws athena get-query-execution --query-execution-id $QUERY_ID \
    --query 'QueryExecution.Status.State' --output text)
  echo "State: $STATE"
  [ "$STATE" = "SUCCEEDED" ] || [ "$STATE" = "FAILED" ] || [ "$STATE" = "CANCELLED" ] && break
  sleep 2
done

# Fetch results
aws athena get-query-results --query-execution-id $QUERY_ID --output table
```

### Pattern: Estimate Query Cost

```bash
# Check table size first
aws s3 ls s3://<bucket>/<prefix>/ --recursive --summarize | tail -2

# Or check data scanned from a previous similar query
aws athena get-query-execution --query-execution-id <previous-id> \
  --query 'QueryExecution.Statistics.DataScannedInBytes' --output text
# Cost ≈ bytes / 1TB × $5.00
```

### Pattern: Create Partitioned Table

```bash
aws athena start-query-execution \
  --query-string "
    CREATE EXTERNAL TABLE logs.access_logs (
      request_id STRING,
      method STRING,
      path STRING,
      status INT,
      response_time DOUBLE
    )
    PARTITIONED BY (date STRING)
    STORED AS PARQUET
    LOCATION 's3://my-logs/access/'
  " \
  --work-group primary

# Load partitions
aws athena start-query-execution \
  --query-string "MSCK REPAIR TABLE logs.access_logs" \
  --work-group primary
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `FAILED: SYNTAX_ERROR` | SQL syntax error | Check query syntax; Athena uses Trino/Presto SQL |
| `FAILED: HIVE_METASTORE_ERROR` | Table or database not found | Verify with `list-databases` / `list-table-metadata` |
| `FAILED: PERMISSION_DENIED` | Missing S3 or Glue permissions | Check IAM policy for data source and results bucket |
| `QueryExhaustedScanLimit` | Exceeded workgroup scan limit | Increase `BytesScannedCutoffPerQuery` or optimize query |
| Empty results on partitioned table | Partitions not loaded | Run `MSCK REPAIR TABLE` or `ALTER TABLE ADD PARTITION` |
| Slow query performance | Full table scan | Add partitions; use columnar format; use `WHERE` on partition columns |
