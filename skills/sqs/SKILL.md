---
name: sqs
description: Manage Amazon SQS queues, messages, dead-letter queues, and queue policies via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📨",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon SQS

Use this skill for message queue operations: creating and configuring queues, sending and receiving messages, managing dead-letter queues (DLQs), setting queue policies, and monitoring queue metrics.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `sqs:*` for full access, or scoped policies for specific operations

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all queues
aws sqs list-queues --output table

# List queues with a name prefix
aws sqs list-queues --queue-name-prefix <prefix>

# Get queue URL by name
aws sqs get-queue-url --queue-name <queue-name>

# Get queue attributes (message count, settings, ARN)
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names All

# Get approximate message count
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed \
  --output table

# List queue tags
aws sqs list-queue-tags --queue-url <queue-url>

# List dead-letter source queues (which queues send to this DLQ)
aws sqs list-dead-letter-source-queues --queue-url <dlq-url>
```

### Send and Receive Messages

```bash
# Send a message
aws sqs send-message \
  --queue-url <queue-url> \
  --message-body '<message-text>'

# Send a message with attributes
aws sqs send-message \
  --queue-url <queue-url> \
  --message-body '<message-text>' \
  --message-attributes '{
    "AttributeName": {"DataType": "String", "StringValue": "value"}
  }'

# Send a message to a FIFO queue
aws sqs send-message \
  --queue-url <queue-url> \
  --message-body '<message-text>' \
  --message-group-id '<group-id>' \
  --message-deduplication-id '<dedup-id>'

# Receive messages (up to 10, with 20s long polling)
aws sqs receive-message \
  --queue-url <queue-url> \
  --max-number-of-messages 10 \
  --wait-time-seconds 20 \
  --attribute-names All \
  --message-attribute-names All

# Delete a message after processing
aws sqs delete-message \
  --queue-url <queue-url> \
  --receipt-handle <receipt-handle>

# Send a batch of messages (up to 10)
aws sqs send-message-batch \
  --queue-url <queue-url> \
  --entries '[
    {"Id": "1", "MessageBody": "first"},
    {"Id": "2", "MessageBody": "second"}
  ]'
```

### Create / Update Queues

⚠️ **Cost note:** SQS pricing is per request — $0.40 per million requests (Standard) or $0.50 per million (FIFO). First 1M requests/month free.

```bash
# Create a standard queue
aws sqs create-queue --queue-name <queue-name>

# Create a FIFO queue (name must end in .fifo)
aws sqs create-queue \
  --queue-name <queue-name>.fifo \
  --attributes '{
    "FifoQueue": "true",
    "ContentBasedDeduplication": "true"
  }'

# Create a queue with custom settings
aws sqs create-queue \
  --queue-name <queue-name> \
  --attributes '{
    "VisibilityTimeout": "60",
    "MessageRetentionPeriod": "1209600",
    "ReceiveMessageWaitTimeSeconds": "20"
  }'

# Set up a dead-letter queue
# Step 1: Create the DLQ
aws sqs create-queue --queue-name <queue-name>-dlq

# Step 2: Get the DLQ ARN
DLQ_ARN=$(aws sqs get-queue-attributes \
  --queue-url <dlq-url> \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text)

# Step 3: Configure the source queue's redrive policy
aws sqs set-queue-attributes \
  --queue-url <source-queue-url> \
  --attributes "{
    \"RedrivePolicy\": \"{\\\"maxReceiveCount\\\":\\\"5\\\",\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\"}\"
  }"

# Update queue attributes
aws sqs set-queue-attributes \
  --queue-url <queue-url> \
  --attributes '{"VisibilityTimeout": "120"}'

# Tag a queue
aws sqs tag-queue \
  --queue-url <queue-url> \
  --tags Environment=production,Team=backend
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Purge all messages from a queue (IRREVERSIBLE)
aws sqs purge-queue --queue-url <queue-url>

# Delete a queue (IRREVERSIBLE — waits 60s before final deletion)
aws sqs delete-queue --queue-url <queue-url>
```

⚠️ **Purge can only be called once every 60 seconds. Messages in flight may not be purged.**

## Safety Rules

1. **NEVER** purge or delete a queue without explicit user confirmation.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** confirm the target queue name/URL before write operations.
4. **ALWAYS** recommend setting up a DLQ for production queues.
5. **WARN** that deleting a message requires the receipt handle from the most recent receive — stale handles fail silently.
6. **WARN** about FIFO queue naming requirement (must end in `.fifo`).

## Best Practices

- Always configure a dead-letter queue (DLQ) to capture failed messages.
- Use long polling (`ReceiveMessageWaitTimeSeconds: 20`) to reduce empty responses and cost.
- Set visibility timeout to at least 6x your processing time.
- Use FIFO queues when ordering and exactly-once delivery matter.
- Enable server-side encryption (SSE-SQS or SSE-KMS) for sensitive data.

## Common Patterns

### Pattern: Replay Messages from DLQ

```bash
DLQ_URL="<dlq-url>"
MAIN_URL="<main-queue-url>"

# Receive from DLQ and resend to main queue
while true; do
  MSG=$(aws sqs receive-message --queue-url $DLQ_URL --max-number-of-messages 1 --wait-time-seconds 1)
  BODY=$(echo $MSG | jq -r '.Messages[0].Body // empty')
  HANDLE=$(echo $MSG | jq -r '.Messages[0].ReceiptHandle // empty')
  [ -z "$BODY" ] && break
  aws sqs send-message --queue-url $MAIN_URL --message-body "$BODY"
  aws sqs delete-message --queue-url $DLQ_URL --receipt-handle "$HANDLE"
done
```

### Pattern: Monitor Queue Depth

```bash
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --query 'Attributes' --output table
```

### Pattern: Move to Encrypted Queue

```bash
# Enable SSE on an existing queue
aws sqs set-queue-attributes \
  --queue-url <queue-url> \
  --attributes '{"SqsManagedSseEnabled": "true"}'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NonExistentQueue` | Queue doesn't exist or wrong region | Verify with `list-queues` and check region |
| `QueueDeletedRecently` | Recreating a queue within 60s of deletion | Wait 60 seconds before recreating with same name |
| `OverLimit` | Too many queues (default 1000) | Request a limit increase or clean up unused queues |
| `InvalidParameterValue` on FIFO | Queue name doesn't end in `.fifo` | Append `.fifo` to the queue name |
| `ReceiptHandleIsInvalid` | Message visibility timed out | Re-receive the message to get a fresh receipt handle |
| `PurgeQueueInProgress` | Purge called within 60s of previous purge | Wait 60 seconds between purge calls |
