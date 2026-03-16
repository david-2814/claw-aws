---
name: glue
description: Manage AWS Glue databases, tables, crawlers, ETL jobs, and data catalog via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🧪",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Glue

Use this skill for data integration and ETL: managing the Glue Data Catalog (databases, tables), running crawlers, creating and monitoring ETL jobs, managing workflows, and querying schema registries.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `glue:*` for full access, or scoped policies
- Glue service role with access to data sources (S3, RDS, Redshift, etc.)

## Common Operations

### Data Catalog (Read-Only)

```bash
# List databases
aws glue get-databases --query 'DatabaseList[*].[Name,CreateTime]' --output table

# Get database details
aws glue get-database --name <database-name>

# List tables in a database
aws glue get-tables --database-name <database-name> \
  --query 'TableList[*].[Name,StorageDescriptor.Location,UpdateTime]' --output table

# Get table details (schema)
aws glue get-table --database-name <database-name> --name <table-name>

# Get table columns
aws glue get-table --database-name <database-name> --name <table-name> \
  --query 'Table.StorageDescriptor.Columns[*].[Name,Type]' --output table

# List partitions
aws glue get-partitions --database-name <database-name> --table-name <table-name> \
  --query 'Partitions[*].Values' --output table

# Search tables across databases
aws glue search-tables --search-text "<keyword>" --output table
```

### Crawlers

```bash
# List crawlers
aws glue get-crawlers --query 'Crawlers[*].[Name,State,LastCrawl.Status,LastCrawl.StartTime]' --output table

# Get crawler details
aws glue get-crawler --name <crawler-name>

# Create a crawler
aws glue create-crawler \
  --name <crawler-name> \
  --role <glue-role-arn> \
  --database-name <database-name> \
  --targets '{
    "S3Targets": [{"Path": "s3://<bucket>/<prefix>/"}]
  }'

# Create a crawler with schedule
aws glue create-crawler \
  --name <crawler-name> \
  --role <glue-role-arn> \
  --database-name <database-name> \
  --targets '{"S3Targets": [{"Path": "s3://<bucket>/<prefix>/"}]}' \
  --schedule "cron(0 1 * * ? *)" \
  --schema-change-policy '{"UpdateBehavior": "UPDATE_IN_DATABASE", "DeleteBehavior": "LOG"}'

# Start a crawler
aws glue start-crawler --name <crawler-name>

# Stop a crawler
aws glue stop-crawler --name <crawler-name>

# Update a crawler
aws glue update-crawler \
  --name <crawler-name> \
  --targets '{"S3Targets": [{"Path": "s3://<bucket>/new-prefix/"}]}'
```

### ETL Jobs

⚠️ **Cost note:** Glue ETL charges per DPU-hour. Standard: $0.44/DPU-hour. Flex: $0.29/DPU-hour. Minimum 1 minute billing. Crawlers: $0.44/DPU-hour.

```bash
# List jobs
aws glue get-jobs --query 'Jobs[*].[Name,Command.Name,MaxCapacity,LastModifiedOn]' --output table

# Get job details
aws glue get-job --job-name <job-name>

# Create a Spark ETL job
aws glue create-job \
  --name <job-name> \
  --role <glue-role-arn> \
  --command '{
    "Name": "glueetl",
    "ScriptLocation": "s3://<bucket>/scripts/etl_script.py",
    "PythonVersion": "3"
  }' \
  --default-arguments '{
    "--TempDir": "s3://<bucket>/temp/",
    "--job-language": "python",
    "--enable-metrics": "true",
    "--enable-continuous-cloudwatch-log": "true"
  }' \
  --glue-version "4.0" \
  --number-of-workers 2 \
  --worker-type G.1X

# Create a Python shell job (lightweight)
aws glue create-job \
  --name <job-name> \
  --role <glue-role-arn> \
  --command '{"Name": "pythonshell", "ScriptLocation": "s3://<bucket>/scripts/script.py", "PythonVersion": "3.9"}' \
  --max-capacity 0.0625

# Start a job run
aws glue start-job-run --job-name <job-name>

# Start with arguments
aws glue start-job-run \
  --job-name <job-name> \
  --arguments '{"--input_path": "s3://bucket/input/", "--output_path": "s3://bucket/output/"}'

# List job runs
aws glue get-job-runs --job-name <job-name> \
  --query 'JobRuns[*].[Id,JobRunState,StartedOn,CompletedOn,ExecutionTime]' \
  --output table

# Get job run details
aws glue get-job-run --job-name <job-name> --run-id <run-id>

# Stop a job run
aws glue batch-stop-job-run --job-name <job-name> --job-run-ids <run-id>
```

### Workflows

```bash
# List workflows
aws glue list-workflows --output table

# Get workflow details
aws glue get-workflow --name <workflow-name>

# Get workflow run status
aws glue get-workflow-runs --name <workflow-name> \
  --query 'Runs[*].[WorkflowRunId,Status,StartedOn,CompletedOn]' --output table

# Start a workflow
aws glue start-workflow-run --name <workflow-name>
```

### Data Catalog Management

```bash
# Create a database
aws glue create-database \
  --database-input '{"Name": "<database-name>", "Description": "My data catalog database"}'

# Create a table manually
aws glue create-table \
  --database-name <database-name> \
  --table-input '{
    "Name": "<table-name>",
    "StorageDescriptor": {
      "Columns": [
        {"Name": "id", "Type": "bigint"},
        {"Name": "name", "Type": "string"},
        {"Name": "created_at", "Type": "timestamp"}
      ],
      "Location": "s3://<bucket>/<prefix>/",
      "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
      "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
      "SerdeInfo": {"SerializationLibrary": "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"}
    }
  }'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a job
aws glue delete-job --job-name <job-name>

# Delete a crawler
aws glue delete-crawler --name <crawler-name>

# Delete a table
aws glue delete-table --database-name <database-name> --name <table-name>

# Delete a database (must delete all tables first)
aws glue delete-database --name <database-name>
```

## Safety Rules

1. **NEVER** delete databases, tables, or jobs without explicit user confirmation.
2. **NEVER** expose or log AWS credentials or connection secrets.
3. **ALWAYS** confirm the database and table names before delete operations.
4. **ALWAYS** warn about ETL job costs before starting runs.
5. **WARN** that deleting a table from the catalog doesn't delete the underlying data.
6. **WARN** about crawler schema change policies — they can modify existing tables.

## Best Practices

- Use Glue 4.0 for the latest Spark engine and features.
- Enable CloudWatch metrics and continuous logging for ETL jobs.
- Use bookmarks for incremental processing of new data.
- Set crawler schema change policy to LOG deletions to prevent accidental column drops.
- Use G.1X workers for memory-intensive jobs, G.2X for compute-intensive.

## Common Patterns

### Pattern: Discover and Query New Data

```bash
# Create a database for the catalog
aws glue create-database --database-input '{"Name": "raw_data"}'

# Create and run a crawler to discover schema
aws glue create-crawler \
  --name discover-data \
  --role <role-arn> \
  --database-name raw_data \
  --targets '{"S3Targets": [{"Path": "s3://my-data-bucket/raw/"}]}'

aws glue start-crawler --name discover-data

# Check status
aws glue get-crawler --name discover-data --query 'Crawler.[Name,State,LastCrawl.Status]'

# See what was discovered
aws glue get-tables --database-name raw_data \
  --query 'TableList[*].[Name,StorageDescriptor.Columns[*].Name]'
```

### Pattern: Monitor Failed Jobs

```bash
# Find failed job runs across all jobs
for job in $(aws glue get-jobs --query 'Jobs[*].Name' --output text); do
  FAILED=$(aws glue get-job-runs --job-name "$job" \
    --query 'JobRuns[?JobRunState==`FAILED`].[Id,ErrorMessage]' --output text 2>/dev/null)
  [ -n "$FAILED" ] && echo "Job: $job" && echo "$FAILED"
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `EntityNotFoundException` | Resource doesn't exist | Verify name with `get-databases`, `get-jobs`, etc. |
| `AccessDeniedException` | IAM role missing permissions | Check Glue service role for S3, CloudWatch, etc. |
| Crawler finds no data | Wrong S3 path or empty prefix | Verify S3 path has data files; check path format |
| ETL job OOM error | Insufficient worker memory | Increase worker type (G.1X → G.2X) or worker count |
| Job timeout | Exceeded default 48-hour timeout | Set `--timeout` parameter; optimize job logic |
| Schema mismatch after crawl | Data format changed | Re-run crawler or manually update table schema |
