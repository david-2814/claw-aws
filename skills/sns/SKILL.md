---
name: sns
description: Manage Amazon SNS topics, subscriptions, and message publishing via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔔",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon SNS

Use this skill for pub/sub messaging: creating and managing topics, subscribing endpoints (email, SMS, SQS, Lambda, HTTP), publishing messages, and managing platform applications for push notifications.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `sns:*` for full access, or scoped policies for specific operations
- For SMS: appropriate spend limits and origination numbers configured

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all topics
aws sns list-topics \
  --query 'Topics[].TopicArn' --output table

# Get topic attributes (ARN, subscriptions count, policy)
aws sns get-topic-attributes --topic-arn <topic-arn>

# List subscriptions for a topic
aws sns list-subscriptions-by-topic --topic-arn <topic-arn> \
  --query 'Subscriptions[].{Endpoint:Endpoint,Protocol:Protocol,Status:SubscriptionArn}' \
  --output table

# List all subscriptions
aws sns list-subscriptions \
  --query 'Subscriptions[].{TopicArn:TopicArn,Endpoint:Endpoint,Protocol:Protocol}' \
  --output table

# Get subscription attributes
aws sns get-subscription-attributes --subscription-arn <subscription-arn>

# Check SMS sending attributes (spend limit, default sender ID)
aws sns get-sms-attributes --attributes DefaultSMSType MonthlySpendLimit
```

### Publish Messages

```bash
# Publish to a topic (all subscribers receive it)
aws sns publish \
  --topic-arn <topic-arn> \
  --subject "Alert Subject" \
  --message "Alert message body"

# Publish with different messages per protocol
aws sns publish \
  --topic-arn <topic-arn> \
  --message '{
    "default": "Default message",
    "email": "Detailed email message with formatting",
    "sms": "Short SMS alert",
    "lambda": "{\"key\": \"value\"}"
  }' \
  --message-structure json

# Publish to a FIFO topic
aws sns publish \
  --topic-arn <topic-arn> \
  --message "Ordered message" \
  --message-group-id "<group-id>" \
  --message-deduplication-id "<dedup-id>"

# Send a direct SMS (no topic needed)
aws sns publish \
  --phone-number "+1234567890" \
  --message "Your verification code is 123456"

# Publish with message attributes (for filtering)
aws sns publish \
  --topic-arn <topic-arn> \
  --message "Event notification" \
  --message-attributes '{
    "event_type": {"DataType": "String", "StringValue": "order_placed"},
    "priority": {"DataType": "String", "StringValue": "high"}
  }'
```

### Create / Update

⚠️ **Cost note:** First 1M SNS requests free/month. SMS costs vary by country ($0.00645/msg US). Email delivery is $2 per 100K.

```bash
# Create a standard topic
aws sns create-topic --name <topic-name>

# Create a FIFO topic (name must end in .fifo)
aws sns create-topic \
  --name <topic-name>.fifo \
  --attributes '{"FifoTopic": "true", "ContentBasedDeduplication": "true"}'

# Subscribe an email endpoint
aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol email \
  --notification-endpoint <email@example.com>

# Subscribe an SQS queue
aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol sqs \
  --notification-endpoint <sqs-queue-arn>

# Subscribe a Lambda function
aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol lambda \
  --notification-endpoint <lambda-arn>

# Subscribe an HTTPS endpoint
aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol https \
  --notification-endpoint https://example.com/webhook

# Add a filter policy to a subscription (message filtering)
aws sns set-subscription-attributes \
  --subscription-arn <subscription-arn> \
  --attribute-name FilterPolicy \
  --attribute-value '{"event_type": ["order_placed", "order_shipped"]}'

# Enable encryption on a topic
aws sns set-topic-attributes \
  --topic-arn <topic-arn> \
  --attribute-name KmsMasterKeyId \
  --attribute-value alias/aws/sns

# Tag a topic
aws sns tag-resource \
  --resource-arn <topic-arn> \
  --tags Key=Environment,Value=production
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Unsubscribe an endpoint
aws sns unsubscribe --subscription-arn <subscription-arn>

# Delete a topic (also removes all subscriptions)
aws sns delete-topic --topic-arn <topic-arn>
```

⚠️ **Deleting a topic immediately removes ALL its subscriptions. This cannot be undone.**

## Safety Rules

1. **NEVER** delete a topic without listing its subscriptions first and confirming with the user.
2. **NEVER** send SMS without confirming the phone number and cost with the user.
3. **NEVER** expose or log AWS credentials, access keys, or secret keys.
4. **ALWAYS** confirm the target topic ARN before publishing.
5. **WARN** that email/SMS subscriptions require confirmation by the recipient.
6. **WARN** about SMS spending limits — uncontrolled publishing can be costly.

## Best Practices

- Use message filtering to reduce unnecessary deliveries and cost.
- Enable server-side encryption (SSE) for topics carrying sensitive data.
- Use FIFO topics with SQS FIFO queues when ordering matters.
- Set SMS spending limits to prevent runaway costs.
- Use delivery status logging for SMS and HTTP/S endpoints to track failures.

## Common Patterns

### Pattern: Fan-Out to Multiple SQS Queues

```bash
TOPIC_ARN="<topic-arn>"

# Subscribe multiple queues to the same topic
aws sns subscribe --topic-arn $TOPIC_ARN --protocol sqs \
  --notification-endpoint <queue-1-arn>
aws sns subscribe --topic-arn $TOPIC_ARN --protocol sqs \
  --notification-endpoint <queue-2-arn>

# Each queue needs a policy allowing SNS to send to it
# (configure via SQS set-queue-attributes with a Policy attribute)
```

### Pattern: CloudWatch Alarm → SNS → Email

```bash
# Create topic for alarms
TOPIC_ARN=$(aws sns create-topic --name ops-alerts --query 'TopicArn' --output text)

# Subscribe the ops team
aws sns subscribe --topic-arn $TOPIC_ARN --protocol email \
  --notification-endpoint ops-team@example.com

# Use this topic ARN in CloudWatch alarm actions
```

### Pattern: Event Filtering for Microservices

```bash
# Subscribe order-service to only order events
aws sns set-subscription-attributes \
  --subscription-arn <sub-arn> \
  --attribute-name FilterPolicy \
  --attribute-value '{"event_type": ["order_placed", "order_cancelled"]}'

# Subscribe shipping-service to only shipment events
aws sns set-subscription-attributes \
  --subscription-arn <sub-arn> \
  --attribute-name FilterPolicy \
  --attribute-value '{"event_type": ["order_shipped", "order_delivered"]}'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `AuthorizationError` | Missing IAM permissions | Check IAM policy for required `sns:` actions |
| `NotFound` | Topic or subscription doesn't exist | Verify ARN with `list-topics` or `list-subscriptions` |
| `InvalidParameter` on FIFO | Topic name doesn't end in `.fifo` | Append `.fifo` to the topic name |
| Subscription stuck in `PendingConfirmation` | Recipient hasn't confirmed | Ask recipient to check email/click confirm link |
| SMS not delivered | Spending limit reached or number blocked | Check `get-sms-attributes` for limits; verify number format |
| `KMSAccessDenied` | SNS can't access the KMS key | Update KMS key policy to allow `sns.amazonaws.com` |
