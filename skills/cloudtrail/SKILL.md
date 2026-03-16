---
name: cloudtrail
description: Manage AWS CloudTrail trails, event history, insights, and log analysis via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📜",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS CloudTrail

Use this skill for audit and compliance: viewing API event history, managing trails, querying CloudTrail Lake, analyzing security events, and configuring insights for anomaly detection.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `cloudtrail:*` for full access, or scoped policies
- S3 bucket for trail log delivery

## Common Operations

### Event History (Read-Only)

```bash
# Look up recent events (last 90 days, management events)
aws cloudtrail lookup-events \
  --max-results 20 \
  --query 'Events[*].[EventTime,EventName,Username,EventSource]' --output table

# Look up events by user
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<username> \
  --max-results 20 \
  --query 'Events[*].[EventTime,EventName,EventSource]' --output table

# Look up events by event name
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances \
  --max-results 10

# Look up events by resource
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<resource-id> \
  --max-results 10

# Look up events by source
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=s3.amazonaws.com \
  --start-time $(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Look up events by access key
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<access-key-id>

# Filter for read-only or write-only events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ReadOnly,AttributeValue=false \
  --max-results 20 \
  --query 'Events[*].[EventTime,EventName,Username]' --output table
```

### Trails (Read-Only)

```bash
# List trails
aws cloudtrail describe-trails \
  --query 'trailList[*].[Name,S3BucketName,IsMultiRegionTrail,IsOrganizationTrail,HasInsightSelectors]' \
  --output table

# Get trail status
aws cloudtrail get-trail-status --name <trail-name>

# Get trail details
aws cloudtrail get-trail --name <trail-name>

# Get event selectors
aws cloudtrail get-event-selectors --trail-name <trail-name>

# Get insight selectors
aws cloudtrail get-insight-selectors --trail-name <trail-name>

# List CloudTrail Lake event data stores
aws cloudtrail list-event-data-stores \
  --query 'EventDataStores[*].[Name,EventDataStoreArn,Status]' --output table

# List channels
aws cloudtrail list-channels --output table
```

### Create and Configure

⚠️ **Cost note:** First trail delivering management events is free. Additional trails: $2.00 per 100,000 management events. Data events: $0.10 per 100,000 events. CloudTrail Lake: $2.50/GB ingested, $0.005/GB scanned.

```bash
# Create a multi-region trail
aws cloudtrail create-trail \
  --name <trail-name> \
  --s3-bucket-name <bucket-name> \
  --is-multi-region-trail \
  --enable-log-file-validation

# Start logging
aws cloudtrail start-logging --name <trail-name>

# Enable data events for all S3 buckets
aws cloudtrail put-event-selectors \
  --trail-name <trail-name> \
  --event-selectors '[{
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [{"Type": "AWS::S3::Object", "Values": ["arn:aws:s3"]}]
  }]'

# Enable data events for specific Lambda functions
aws cloudtrail put-event-selectors \
  --trail-name <trail-name> \
  --event-selectors '[{
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [{"Type": "AWS::Lambda::Function", "Values": ["arn:aws:lambda:<region>:<account>:function:<function-name>"]}]
  }]'

# Enable advanced event selectors (more granular)
aws cloudtrail put-event-selectors \
  --trail-name <trail-name> \
  --advanced-event-selectors '[{
    "Name": "S3PutOnly",
    "FieldSelectors": [
      {"Field": "eventCategory", "Equals": ["Data"]},
      {"Field": "resources.type", "Equals": ["AWS::S3::Object"]},
      {"Field": "readOnly", "Equals": ["false"]}
    ]
  }]'

# Enable CloudTrail Insights
aws cloudtrail put-insight-selectors \
  --trail-name <trail-name> \
  --insight-selectors '[
    {"InsightType": "ApiCallRateInsight"},
    {"InsightType": "ApiErrorRateInsight"}
  ]'

# Send logs to CloudWatch
aws cloudtrail update-trail \
  --name <trail-name> \
  --cloud-watch-logs-log-group-arn <log-group-arn> \
  --cloud-watch-logs-role-arn <role-arn>

# Create a CloudTrail Lake event data store
aws cloudtrail create-event-data-store \
  --name <store-name> \
  --retention-period 90 \
  --advanced-event-selectors '[{
    "Name": "AllManagement",
    "FieldSelectors": [{"Field": "eventCategory", "Equals": ["Management"]}]
  }]'
```

### CloudTrail Lake Queries

```bash
# Start a query
QUERY_ID=$(aws cloudtrail start-query \
  --query-statement "SELECT eventTime, eventName, userIdentity.arn, sourceIPAddress FROM <event-data-store-id> WHERE eventTime > '2024-01-01 00:00:00' AND eventName = 'ConsoleLogin' ORDER BY eventTime DESC LIMIT 50" \
  --query 'QueryId' --output text)

# Check query status
aws cloudtrail describe-query --query-id $QUERY_ID

# Get query results
aws cloudtrail get-query-results --query-id $QUERY_ID
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Stop logging
aws cloudtrail stop-logging --name <trail-name>

# Delete a trail
aws cloudtrail delete-trail --name <trail-name>

# Delete an event data store
aws cloudtrail delete-event-data-store --event-data-store <store-arn>
```

## Safety Rules

1. **NEVER** stop logging or delete trails without explicit user confirmation — creates audit gaps.
2. **NEVER** expose or log AWS credentials or sensitive event details.
3. **ALWAYS** confirm the trail name and region before modifications.
4. **ALWAYS** recommend log file validation to detect tampering.
5. **WARN** about cost implications of data events (high volume).
6. **WARN** that stopping logging creates compliance risk.

## Best Practices

- Enable at least one multi-region trail with log file validation.
- Enable CloudTrail Insights for anomaly detection on API calls.
- Send logs to CloudWatch for real-time monitoring and alerting.
- Enable S3 data events for security-sensitive buckets.
- Use CloudTrail Lake for complex ad-hoc security investigations.

## Common Patterns

### Pattern: Investigate Who Changed a Resource

```bash
# Find who modified a security group
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<sg-id> \
  --query 'Events[*].[EventTime,EventName,Username,sourceIPAddress]' \
  --output table
```

### Pattern: Find Console Logins

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --max-results 20 \
  --query 'Events[*].[EventTime,Username,CloudTrailEvent]' --output text | while read line; do
  echo "$line" | jq -r '.sourceIPAddress // "N/A"' 2>/dev/null
done
```

### Pattern: Detect Unauthorized API Calls

```bash
# Look for AccessDenied events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --start-time $(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ) \
  --max-results 50 | jq '.Events[] | select(.CloudTrailEvent | fromjson | .errorCode == "AccessDenied")'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `TrailNotFoundException` | Trail doesn't exist | Verify with `describe-trails` |
| `InsufficientS3BucketPolicyException` | S3 bucket missing CloudTrail policy | Add CloudTrail service permissions to bucket policy |
| `InsufficientSnsTopicPolicyException` | SNS topic missing permissions | Add `cloudtrail.amazonaws.com` publish permission |
| No events in lookup | Events beyond 90-day window | Use CloudTrail Lake or query S3 logs directly |
| Delayed event delivery | Normal — can take up to 15 min | CloudTrail is not real-time; wait and retry |
| Log file validation failed | Possible log tampering | Investigate immediately — this is a security incident |
