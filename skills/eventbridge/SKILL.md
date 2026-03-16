---
name: eventbridge
description: Manage Amazon EventBridge event buses, rules, targets, schedules, and event replay via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🚌",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon EventBridge

Use this skill for event-driven architecture: creating and managing event buses, defining rules and targets, scheduling events, managing schemas, and replaying archived events.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `events:*`, `scheduler:*` for full access, or scoped policies for specific operations
- Target services (Lambda, SQS, SNS, etc.) must have resource-based policies allowing EventBridge invocation

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all event buses
aws events list-event-buses --output table

# List rules on default bus
aws events list-rules --output table

# List rules on a custom bus
aws events list-rules --event-bus-name <bus-name> --output table

# Describe a specific rule
aws events describe-rule --name <rule-name>

# List targets for a rule
aws events list-targets-by-rule --rule <rule-name>

# List archives
aws events list-archives --output table

# List replays
aws events list-replays --output table

# List connections (for API destinations)
aws events list-connections --output table

# List API destinations
aws events list-api-destinations --output table

# List EventBridge Scheduler schedules
aws scheduler list-schedules --output table

# Describe a schedule
aws scheduler get-schedule --name <schedule-name>

# List schema registries
aws schemas list-registries --output table

# Search discovered schemas
aws schemas search-schemas --registry-name discovered-schemas --keywords <keyword>
```

### Create Rules and Targets

⚠️ **Cost note:** EventBridge charges $1.00 per million custom events published. AWS service events are free. Scheduler: $1.00 per million invocations.

```bash
# Create a custom event bus
aws events create-event-bus --name <bus-name>

# Create a rule matching EC2 state changes
aws events put-rule \
  --name <rule-name> \
  --event-pattern '{
    "source": ["aws.ec2"],
    "detail-type": ["EC2 Instance State-change Notification"],
    "detail": {"state": ["stopped", "terminated"]}
  }' \
  --state ENABLED \
  --description "Notify on EC2 stop/terminate"

# Create a scheduled rule (rate)
aws events put-rule \
  --name <rule-name> \
  --schedule-expression "rate(5 minutes)" \
  --state ENABLED

# Create a scheduled rule (cron)
aws events put-rule \
  --name <rule-name> \
  --schedule-expression "cron(0 9 * * ? *)" \
  --state ENABLED \
  --description "Run daily at 9 AM UTC"

# Add a Lambda target to a rule
aws events put-targets \
  --rule <rule-name> \
  --targets '[{
    "Id": "1",
    "Arn": "<lambda-function-arn>"
  }]'

# Add an SQS target with input transformation
aws events put-targets \
  --rule <rule-name> \
  --targets '[{
    "Id": "1",
    "Arn": "<sqs-queue-arn>",
    "InputTransformer": {
      "InputPathsMap": {"instance": "$.detail.instance-id", "state": "$.detail.state"},
      "InputTemplate": "\"Instance <instance> changed to <state>\""
    }
  }]'

# Create an EventBridge Scheduler schedule (one-time)
aws scheduler create-schedule \
  --name <schedule-name> \
  --schedule-expression "at(2024-12-31T23:59:00)" \
  --target '{"Arn": "<lambda-arn>", "RoleArn": "<role-arn>", "Input": "{}"}' \
  --flexible-time-window '{"Mode": "OFF"}'

# Create a recurring schedule
aws scheduler create-schedule \
  --name <schedule-name> \
  --schedule-expression "rate(1 hour)" \
  --target '{"Arn": "<lambda-arn>", "RoleArn": "<role-arn>"}' \
  --flexible-time-window '{"Mode": "FLEXIBLE", "MaximumWindowInMinutes": 15}'
```

### Enable / Disable Rules

```bash
# Disable a rule
aws events disable-rule --name <rule-name>

# Enable a rule
aws events enable-rule --name <rule-name>
```

### Archive and Replay

```bash
# Create an archive
aws events create-archive \
  --archive-name <archive-name> \
  --source-arn <event-bus-arn> \
  --retention-days 90

# Start a replay
aws events start-replay \
  --replay-name <replay-name> \
  --event-source-arn <archive-arn> \
  --destination '{"Arn": "<event-bus-arn>"}' \
  --event-start-time "2024-01-01T00:00:00Z" \
  --event-end-time "2024-01-02T00:00:00Z"
```

### Send Events

```bash
# Send a custom event
aws events put-events \
  --entries '[{
    "Source": "my.application",
    "DetailType": "OrderPlaced",
    "Detail": "{\"orderId\": \"12345\", \"amount\": 99.99}",
    "EventBusName": "default"
  }]'

# Send multiple events (batch)
aws events put-events \
  --entries '[
    {"Source": "my.app", "DetailType": "Event1", "Detail": "{}", "EventBusName": "default"},
    {"Source": "my.app", "DetailType": "Event2", "Detail": "{}", "EventBusName": "default"}
  ]'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Remove targets from a rule (must remove all targets before deleting rule)
aws events remove-targets --rule <rule-name> --ids "1" "2"

# Delete a rule
aws events delete-rule --name <rule-name>

# Delete a custom event bus (must remove all rules first)
aws events delete-event-bus --name <bus-name>

# Delete an archive
aws events delete-archive --archive-name <archive-name>

# Delete a schedule
aws scheduler delete-schedule --name <schedule-name>
```

## Safety Rules

1. **NEVER** delete rules or event buses without explicit user confirmation.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** confirm the target event bus and region before write operations.
4. **ALWAYS** warn that deleting a rule requires removing all targets first.
5. **WARN** about event replay costs — replayed events are charged as custom events.
6. **WARN** that disabling a rule stops event delivery but does not delete it.

## Best Practices

- Use custom event buses to isolate application events from AWS service events.
- Use dead-letter queues on targets to capture failed event deliveries.
- Use input transformers to send only relevant data to targets.
- Archive events for replay and debugging — set appropriate retention periods.
- Use EventBridge Scheduler instead of CloudWatch Events cron for new scheduled tasks.

## Common Patterns

### Pattern: Fan-Out Event to Multiple Targets

```bash
# Create a rule
aws events put-rule \
  --name order-events \
  --event-pattern '{"source": ["my.orders"], "detail-type": ["OrderPlaced"]}'

# Add multiple targets (Lambda + SQS + SNS)
aws events put-targets \
  --rule order-events \
  --targets '[
    {"Id": "notify", "Arn": "<sns-topic-arn>"},
    {"Id": "process", "Arn": "<lambda-arn>"},
    {"Id": "audit", "Arn": "<sqs-queue-arn>"}
  ]'
```

### Pattern: Cross-Account Event Forwarding

```bash
# On source account: allow target account to receive events
aws events put-permission \
  --event-bus-name default \
  --action events:PutEvents \
  --principal <target-account-id> \
  --statement-id "AllowCrossAccount"
```

### Pattern: Debug with Test Events

```bash
# Send a test event and check CloudWatch Logs
aws events put-events \
  --entries '[{
    "Source": "debug.test",
    "DetailType": "TestEvent",
    "Detail": "{\"test\": true}",
    "EventBusName": "default"
  }]'

# Check if the rule matched
aws events describe-rule --name <rule-name> \
  --query '{State: State, EventPattern: EventPattern}'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFoundException` | Rule or bus doesn't exist | Verify name and region; check `list-rules` |
| Events not triggering target | Event pattern mismatch | Test pattern with `aws events test-event-pattern` |
| `ManagedRuleException` | Trying to modify AWS-managed rule | AWS-managed rules can't be edited or deleted |
| Target invocation failing | Missing resource-based policy on target | Add permission for `events.amazonaws.com` to invoke the target |
| `ValidationException` on schedule | Invalid cron/rate expression | Check [schedule expression syntax](https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html) |
| Duplicate events delivered | At-least-once delivery | Design targets to be idempotent |
