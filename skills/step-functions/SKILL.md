---
name: step-functions
description: Manage AWS Step Functions state machines, executions, and workflow definitions via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔄",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Step Functions

Use this skill for workflow orchestration: creating and managing state machines, starting and monitoring executions, inspecting execution history, and managing activity workers.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `states:*` for full access, or scoped policies
- State machine definitions use Amazon States Language (ASL) in JSON

## Common Operations

### List and Inspect (Read-Only)

```bash
# List state machines
aws stepfunctions list-state-machines \
  --query 'stateMachines[].{Name:name,ARN:stateMachineArn,Type:type,Created:creationDate}' \
  --output table

# Describe a state machine
aws stepfunctions describe-state-machine \
  --state-machine-arn <state-machine-arn>

# Get state machine definition
aws stepfunctions describe-state-machine \
  --state-machine-arn <state-machine-arn> \
  --query 'definition' --output text | jq .

# List executions (running)
aws stepfunctions list-executions \
  --state-machine-arn <state-machine-arn> \
  --status-filter RUNNING \
  --query 'executions[].{Name:name,Status:status,Started:startDate}' \
  --output table

# List recent executions (all statuses)
aws stepfunctions list-executions \
  --state-machine-arn <state-machine-arn> \
  --max-results 20 \
  --query 'executions[].{Name:name,Status:status,Started:startDate,Stopped:stopDate}' \
  --output table

# Describe a specific execution
aws stepfunctions describe-execution \
  --execution-arn <execution-arn>

# Get execution history (step-by-step trace)
aws stepfunctions get-execution-history \
  --execution-arn <execution-arn> \
  --query 'events[].{Id:id,Type:type,Timestamp:timestamp}' \
  --output table

# Get execution history with details (for debugging)
aws stepfunctions get-execution-history \
  --execution-arn <execution-arn> \
  --include-execution-data \
  --max-results 50

# List activities
aws stepfunctions list-activities \
  --query 'activities[].{Name:name,ARN:activityArn,Created:creationDate}' \
  --output table
```

### Start / Manage Executions

```bash
# Start an execution
aws stepfunctions start-execution \
  --state-machine-arn <state-machine-arn> \
  --input '{"key": "value"}'

# Start an execution with a name (for idempotency)
aws stepfunctions start-execution \
  --state-machine-arn <state-machine-arn> \
  --name "<execution-name>" \
  --input '{"key": "value"}'

# Start a sync execution (Express workflows — waits for result)
aws stepfunctions start-sync-execution \
  --state-machine-arn <state-machine-arn> \
  --input '{"key": "value"}'

# Stop a running execution
aws stepfunctions stop-execution \
  --execution-arn <execution-arn> \
  --cause "Stopped by operator"

# Send a task success (for activity/callback patterns)
aws stepfunctions send-task-success \
  --task-token <task-token> \
  --output '{"result": "approved"}'

# Send a task failure
aws stepfunctions send-task-failure \
  --task-token <task-token> \
  --cause "Validation failed" \
  --error "ValidationError"

# Send a task heartbeat
aws stepfunctions send-task-heartbeat --task-token <task-token>
```

### Create / Update

⚠️ **Cost note:** Standard workflows: $0.025 per 1,000 state transitions. Express workflows: priced by number and duration of executions.

```bash
# Create a state machine
aws stepfunctions create-state-machine \
  --name <state-machine-name> \
  --role-arn <execution-role-arn> \
  --type STANDARD \
  --definition '{
    "Comment": "A simple sequential workflow",
    "StartAt": "FirstStep",
    "States": {
      "FirstStep": {
        "Type": "Task",
        "Resource": "<lambda-arn>",
        "Next": "SecondStep"
      },
      "SecondStep": {
        "Type": "Task",
        "Resource": "<lambda-arn>",
        "End": true
      }
    }
  }'

# Create an Express workflow (high volume, short duration)
aws stepfunctions create-state-machine \
  --name <state-machine-name> \
  --role-arn <execution-role-arn> \
  --type EXPRESS \
  --definition file://definition.json

# Update a state machine definition
aws stepfunctions update-state-machine \
  --state-machine-arn <state-machine-arn> \
  --definition file://updated-definition.json

# Enable logging
aws stepfunctions update-state-machine \
  --state-machine-arn <state-machine-arn> \
  --logging-configuration '{
    "level": "ALL",
    "includeExecutionData": true,
    "destinations": [{
      "cloudWatchLogsLogGroup": {
        "logGroupArn": "<log-group-arn>"
      }
    }]
  }'

# Enable tracing (X-Ray)
aws stepfunctions update-state-machine \
  --state-machine-arn <state-machine-arn> \
  --tracing-configuration enabled=true

# Tag a state machine
aws stepfunctions tag-resource \
  --resource-arn <state-machine-arn> \
  --tags key=Environment,value=production
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a state machine (running executions will continue to completion)
aws stepfunctions delete-state-machine \
  --state-machine-arn <state-machine-arn>

# Delete an activity
aws stepfunctions delete-activity \
  --activity-arn <activity-arn>
```

⚠️ **Deleting a state machine does NOT stop running executions. Stop them first if needed.**

## Safety Rules

1. **NEVER** delete a state machine without checking for running executions first.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** confirm the state machine ARN before starting executions.
4. **ALWAYS** warn about cost implications for high-volume Standard workflows (use Express instead).
5. **WARN** about execution timeout limits (Standard: 1 year, Express: 5 minutes).
6. **RECOMMEND** stopping running executions before deleting a state machine.

## Best Practices

- Use Express workflows for high-volume, short-duration workloads (event processing, API orchestration).
- Enable logging and X-Ray tracing for debugging complex workflows.
- Use error handling (`Retry` and `Catch` blocks) in every Task state.
- Use `Map` states for parallel processing of collections.
- Store large payloads in S3 and pass references — state data is limited to 256KB.

## Common Patterns

### Pattern: Retry with Exponential Backoff

```json
{
  "Type": "Task",
  "Resource": "<lambda-arn>",
  "Retry": [{
    "ErrorEquals": ["States.TaskFailed", "Lambda.ServiceException"],
    "IntervalSeconds": 2,
    "MaxAttempts": 3,
    "BackoffRate": 2.0
  }],
  "Catch": [{
    "ErrorEquals": ["States.ALL"],
    "Next": "HandleError"
  }],
  "End": true
}
```

### Pattern: List Failed Executions

```bash
aws stepfunctions list-executions \
  --state-machine-arn <state-machine-arn> \
  --status-filter FAILED \
  --max-results 10 \
  --query 'executions[].{Name:name,Started:startDate,Stopped:stopDate}' \
  --output table

# Get the error from a failed execution
aws stepfunctions describe-execution \
  --execution-arn <execution-arn> \
  --query '{Status:status,Error:error,Cause:cause}'
```

### Pattern: Parallel Processing with Map

```json
{
  "Type": "Map",
  "ItemsPath": "$.items",
  "MaxConcurrency": 10,
  "Iterator": {
    "StartAt": "ProcessItem",
    "States": {
      "ProcessItem": {
        "Type": "Task",
        "Resource": "<lambda-arn>",
        "End": true
      }
    }
  },
  "End": true
}
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ExecutionDoesNotExist` | Execution ARN is wrong or execution expired | Verify with `list-executions`; Express execution history is short-lived |
| `InvalidDefinition` | ASL syntax error | Validate JSON; check state names match transitions |
| `ExecutionAlreadyExists` | Duplicate execution name | Use a unique name or omit for auto-generated |
| `StateMachineDeleting` | State machine is being deleted | Wait for deletion to complete |
| `TaskTimedOut` | Activity or callback didn't respond in time | Increase `TimeoutSeconds` or ensure worker sends heartbeats |
| Execution stuck | Waiting for callback token or activity | Check for pending `send-task-success` calls |
