---
name: ses
description: Manage Amazon SES email sending, identities, configuration sets, templates, and suppression lists via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "✉️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon SES (Simple Email Service)

Use this skill for email operations: verifying identities, sending emails, managing templates, configuring email events, managing suppression lists, and monitoring sending reputation.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `ses:*` for full access, or scoped policies
- SES uses v2 API (`sesv2`) — this skill covers both v1 and v2 commands
- Account must be out of sandbox for production sending (request via AWS console)

## Common Operations

### List and Inspect (Read-Only)

```bash
# Get account sending status
aws sesv2 get-account

# Get sending quota and stats
aws ses get-send-quota
aws ses get-send-statistics

# List verified email identities
aws sesv2 list-email-identities \
  --query 'EmailIdentities[*].[IdentityType,IdentityName,SendingEnabled]' --output table

# Get identity details (DKIM, verification)
aws sesv2 get-email-identity --email-identity <identity>

# List configuration sets
aws sesv2 list-configuration-sets --output table

# Get configuration set details
aws sesv2 get-configuration-set --configuration-set-name <config-set>

# List email templates
aws sesv2 list-email-templates \
  --query 'TemplatesMetadata[*].[TemplateName,CreatedTimestamp]' --output table

# Get a template
aws sesv2 get-email-template --template-name <template-name>

# List suppressed destinations (bounces, complaints)
aws sesv2 list-suppressed-destinations \
  --query 'SuppressedDestinationSummaries[*].[EmailAddress,Reason,CreatedTimestamp]' --output table

# List contact lists
aws sesv2 list-contact-lists --output table

# List contacts in a list
aws sesv2 list-contacts --contact-list-name <list-name> \
  --query 'Contacts[*].[EmailAddress,UnsubscribeAll,CreatedTimestamp]' --output table

# Get deliverability dashboard
aws sesv2 get-deliverability-dashboard-options
```

### Verify Identities

```bash
# Verify an email address
aws sesv2 create-email-identity --email-identity user@example.com

# Verify a domain (returns DKIM tokens)
aws sesv2 create-email-identity --email-identity example.com

# Get DKIM tokens for DNS setup
aws sesv2 get-email-identity --email-identity example.com \
  --query 'DkimAttributes.Tokens'

# Enable DKIM signing
aws sesv2 put-email-identity-dkim-attributes \
  --email-identity example.com \
  --signing-enabled
```

### Send Emails

⚠️ **Cost note:** SES charges $0.10 per 1,000 emails sent. Free tier: 62,000 emails/month when sent from EC2. Receiving: $0.10 per 1,000 emails + $0.09/GB attachment.

```bash
# Send a simple email
aws sesv2 send-email \
  --from-email-address sender@example.com \
  --destination '{"ToAddresses": ["recipient@example.com"]}' \
  --content '{
    "Simple": {
      "Subject": {"Data": "Test Subject"},
      "Body": {"Text": {"Data": "Hello from SES!"}}
    }
  }'

# Send HTML email
aws sesv2 send-email \
  --from-email-address sender@example.com \
  --destination '{"ToAddresses": ["recipient@example.com"]}' \
  --content '{
    "Simple": {
      "Subject": {"Data": "HTML Test"},
      "Body": {
        "Html": {"Data": "<h1>Hello</h1><p>This is an HTML email.</p>"},
        "Text": {"Data": "Hello. This is a text fallback."}
      }
    }
  }'

# Send using a template
aws sesv2 send-email \
  --from-email-address sender@example.com \
  --destination '{"ToAddresses": ["recipient@example.com"]}' \
  --content '{
    "Template": {
      "TemplateName": "<template-name>",
      "TemplateData": "{\"name\": \"John\", \"order_id\": \"12345\"}"
    }
  }'

# Send with a configuration set (for tracking)
aws sesv2 send-email \
  --from-email-address sender@example.com \
  --destination '{"ToAddresses": ["recipient@example.com"]}' \
  --content '{"Simple": {"Subject": {"Data": "Tracked Email"}, "Body": {"Text": {"Data": "Hello!"}}}}' \
  --configuration-set-name <config-set>

# Send bulk templated email
aws sesv2 send-bulk-email \
  --from-email-address sender@example.com \
  --default-content '{"Template": {"TemplateName": "<template-name>", "TemplateData": "{\"company\": \"ACME\"}"}}' \
  --bulk-email-entries '[
    {"Destination": {"ToAddresses": ["user1@example.com"]}, "ReplacementEmailContent": {"ReplacementTemplate": {"ReplacementTemplateData": "{\"name\": \"Alice\"}"}}},
    {"Destination": {"ToAddresses": ["user2@example.com"]}, "ReplacementEmailContent": {"ReplacementTemplate": {"ReplacementTemplateData": "{\"name\": \"Bob\"}"}}}
  ]'
```

### Templates

```bash
# Create an email template
aws sesv2 create-email-template \
  --template-name <template-name> \
  --template-content '{
    "Subject": "Order Confirmation #{{order_id}}",
    "Html": "<h1>Thanks {{name}}</h1><p>Your order #{{order_id}} is confirmed.</p>",
    "Text": "Thanks {{name}}. Your order #{{order_id}} is confirmed."
  }'

# Update a template
aws sesv2 update-email-template \
  --template-name <template-name> \
  --template-content '{
    "Subject": "Updated: Order #{{order_id}}",
    "Html": "<h1>Hi {{name}}</h1><p>Updated template.</p>",
    "Text": "Hi {{name}}. Updated template."
  }'

# Test a template (render with data)
aws ses test-render-template \
  --template-name <template-name> \
  --template-data '{"name": "Test User", "order_id": "99999"}'
```

### Configuration Sets and Event Tracking

```bash
# Create a configuration set
aws sesv2 create-configuration-set --configuration-set-name <config-set>

# Add SNS event destination (track bounces, complaints)
aws sesv2 create-configuration-set-event-destination \
  --configuration-set-name <config-set> \
  --event-destination-name bounce-notify \
  --event-destination '{
    "Enabled": true,
    "MatchingEventTypes": ["BOUNCE", "COMPLAINT"],
    "SnsDestination": {"TopicArn": "<sns-topic-arn>"}
  }'
```

### Suppression List

```bash
# Add email to suppression list
aws sesv2 put-suppressed-destination \
  --email-address bounced@example.com \
  --reason BOUNCE

# Remove from suppression list
aws sesv2 delete-suppressed-destination --email-address bounced@example.com
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete an email identity
aws sesv2 delete-email-identity --email-identity <identity>

# Delete a template
aws sesv2 delete-email-template --template-name <template-name>

# Delete a configuration set
aws sesv2 delete-configuration-set --configuration-set-name <config-set>

# Delete a contact list
aws sesv2 delete-contact-list --contact-list-name <list-name>
```

## Safety Rules

1. **NEVER** send emails without explicit user confirmation — reputation damage is hard to fix.
2. **NEVER** expose or log AWS credentials or email content with sensitive data.
3. **ALWAYS** verify the recipient address before sending test emails.
4. **ALWAYS** use a configuration set with bounce/complaint tracking in production.
5. **WARN** that sandbox accounts can only send to verified addresses.
6. **WARN** about sending reputation impact from bounces and complaints.

## Best Practices

- Set up bounce and complaint handling via SNS before production sending.
- Use templates for transactional emails to ensure consistency.
- Enable DKIM signing for all domain identities.
- Monitor sending reputation and bounce/complaint rates.
- Stay under 5% bounce rate and 0.1% complaint rate.

## Common Patterns

### Pattern: Production Email Setup

```bash
# Verify domain
aws sesv2 create-email-identity --email-identity example.com

# Create configuration set with tracking
aws sesv2 create-configuration-set --configuration-set-name production-emails

aws sesv2 create-configuration-set-event-destination \
  --configuration-set-name production-emails \
  --event-destination-name all-events \
  --event-destination '{
    "Enabled": true,
    "MatchingEventTypes": ["SEND", "DELIVERY", "BOUNCE", "COMPLAINT", "REJECT"],
    "SnsDestination": {"TopicArn": "<sns-topic-arn>"}
  }'
```

### Pattern: Check Sending Health

```bash
echo "=== Sending Quota ==="
aws ses get-send-quota \
  --query '{Max24HourSend:Max24HourSend,SentLast24Hours:SentLast24Hours,MaxSendRate:MaxSendRate}' \
  --output table

echo "=== Suppressed Addresses ==="
aws sesv2 list-suppressed-destinations \
  --query 'SuppressedDestinationSummaries | length(@)'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `MessageRejected` | Sender not verified or sandbox | Verify sender identity; request production access |
| `MailFromDomainNotVerifiedException` | MAIL FROM domain not set up | Configure custom MAIL FROM or use default |
| `AccountSendingPausedException` | Sending suspended by AWS | Check bounce/complaint rates; contact AWS support |
| `ConfigurationSetDoesNotExist` | Config set not found | Verify with `list-configuration-sets` |
| `TemplateDoesNotExist` | Template not found | Check template name with `list-email-templates` |
| Email in spam folder | Missing DKIM/SPF/DMARC | Set up DKIM, SPF, and DMARC DNS records |
