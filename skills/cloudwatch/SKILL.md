---
name: cloudwatch
description: Monitor AWS resources with CloudWatch — query logs, metrics, and alarms, create dashboards, and set up alerting via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📊",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon CloudWatch

Use this skill for observability operations: tailing and querying logs, checking metrics, managing alarms, and creating dashboards.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `cloudwatch:*`, `logs:*` for full access
- Resources must be emitting logs/metrics (most AWS services do by default)

## Common Operations

### Logs

```bash
# List log groups
aws logs describe-log-groups \
  --query 'logGroups[].[logGroupName, storedBytes, retentionInDays]' \
  --output table

# Tail logs in real-time (most useful for debugging)
aws logs tail <log-group-name> --follow --since 10m

# Tail with a filter
aws logs tail <log-group-name> --follow --since 5m --filter-pattern "ERROR"

# Search logs with filter pattern
aws logs filter-log-events \
  --log-group-name <log-group-name> \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --query 'events[].[timestamp, message]' \
  --output text

# Run a Logs Insights query
aws logs start-query \
  --log-group-name <log-group-name> \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50'

# Get query results (use the queryId from start-query)
aws logs get-query-results --query-id <query-id>

# List recent log streams
aws logs describe-log-streams \
  --log-group-name <log-group-name> \
  --order-by LastEventTime --descending --limit 5

# Set retention (save cost on old logs)
aws logs put-retention-policy \
  --log-group-name <log-group-name> \
  --retention-in-days 30
```

### Metrics

```bash
# List available metrics for a namespace
aws cloudwatch list-metrics --namespace AWS/EC2

# List metrics for a specific instance
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --dimensions Name=InstanceId,Value=<instance-id>

# Get CPU utilization for an EC2 instance (last 1 hour, 5-min intervals)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum \
  --output table

# Get Lambda invocation errors (last 24 hours)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=<function-name> \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --output table

# Get RDS connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=<db-id> \
  --start-time $(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum \
  --output table

# Get S3 bucket size
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=<bucket> Name=StorageType,Value=StandardStorage \
  --start-time $(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average
```

### Alarms

```bash
# List all alarms
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[].[AlarmName, StateValue, MetricName, Namespace]' \
  --output table

# List alarms in ALARM state
aws cloudwatch describe-alarms --state-value ALARM \
  --query 'MetricAlarms[].[AlarmName, StateReason]' --output table

# Get alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name <alarm-name> \
  --history-item-type StateUpdate \
  --max-items 10

# Create a CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name high-cpu-<instance-id> \
  --alarm-description "CPU > 80% for 5 minutes" \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --statistic Average \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions <sns-topic-arn>

# Create a Lambda error alarm
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-errors-<function-name> \
  --alarm-description "Lambda errors > 5 in 5 minutes" \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=<function-name> \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions <sns-topic-arn>

# Temporarily suppress an alarm
aws cloudwatch set-alarm-state \
  --alarm-name <alarm-name> \
  --state-value OK \
  --state-reason "Manual reset during maintenance"
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete an alarm
aws cloudwatch delete-alarms --alarm-names <alarm-name>

# Delete a log group (ALL logs permanently lost)
aws logs delete-log-group --log-group-name <log-group-name>
```

## Safety Rules

1. **NEVER** delete log groups without explicit user confirmation — log data is irrecoverable.
2. **NEVER** disable or delete alarms on production resources without understanding why they're firing.
3. **ALWAYS** confirm the log group name before running destructive log operations.
4. **ALWAYS** include `--treat-missing-data notBreaching` on alarms unless the user specifically wants alerts on missing data.
5. **PREFER** Logs Insights queries over `filter-log-events` for complex searches — they're faster and more capable.
6. **WARN** about log storage costs when retention is set to unlimited.

## Best Practices

- Set retention policies on all log groups — unlimited retention accumulates cost silently.
- Use metric math and anomaly detection alarms instead of static thresholds where possible.
- Use Logs Insights for ad-hoc queries — it's faster and supports aggregation.
- Create alarms for the "golden signals": latency, traffic, errors, saturation.
- Use composite alarms to reduce alert noise by combining multiple conditions.
- Export logs to S3 for long-term retention at lower cost.

## Common Patterns

### Pattern: Quick Health Check for an Application

```bash
FUNC="my-function"
echo "=== Recent Errors ==="
aws logs tail /aws/lambda/$FUNC --since 30m --filter-pattern "ERROR"

echo "=== Invocation Metrics (last hour) ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda --metric-name Invocations \
  --dimensions Name=FunctionName,Value=$FUNC \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Sum --output table

echo "=== Error Count ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda --metric-name Errors \
  --dimensions Name=FunctionName,Value=$FUNC \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Sum --output table
```

### Pattern: Find Log Groups Without Retention (Cost Risk)

```bash
aws logs describe-log-groups \
  --query 'logGroups[?!retentionInDays].[logGroupName, storedBytes]' \
  --output table
```

### Pattern: Top Errors in Last Hour (Logs Insights)

```bash
QUERY_ID=$(aws logs start-query \
  --log-group-name <log-group-name> \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'filter @message like /ERROR/ | stats count(*) as errorCount by @message | sort errorCount desc | limit 10' \
  --query 'queryId' --output text)

sleep 5
aws logs get-query-results --query-id $QUERY_ID
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFoundException` | Log group doesn't exist | Check the log group name and region |
| `LimitExceededException` | Too many concurrent Insights queries | Wait and retry — limit is 30 concurrent queries |
| No data points returned | Wrong time range or dimensions | Verify the namespace, metric name, and dimension values |
| Alarm stuck in `INSUFFICIENT_DATA` | Metric not being emitted | Check that the resource exists and is active |
| `ThrottlingException` | Too many API calls | Add delays between calls or reduce polling frequency |
