---
name: waf
description: Manage AWS WAF web ACLs, rules, IP sets, and logging for CloudFront, ALB, and API Gateway via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🛡️",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS WAF

Use this skill for web application firewall operations: creating and managing web ACLs, configuring rules and rule groups, managing IP sets and regex pattern sets, associating WAF with resources, and analyzing WAF logs.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `wafv2:*` for full access, or scoped policies
- For CloudFront: use `--scope CLOUDFRONT --region us-east-1`
- For ALB/API Gateway/AppSync: use `--scope REGIONAL --region <region>`

## Common Operations

### List and Inspect (Read-Only)

```bash
# List web ACLs (regional)
aws wafv2 list-web-acls --scope REGIONAL --region <region> --output table

# List web ACLs (CloudFront — must use us-east-1)
aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1 --output table

# Get web ACL details
aws wafv2 get-web-acl \
  --name <web-acl-name> \
  --scope REGIONAL \
  --id <web-acl-id> \
  --region <region>

# List rules in a web ACL
aws wafv2 get-web-acl \
  --name <web-acl-name> --scope REGIONAL --id <web-acl-id> --region <region> \
  --query 'WebACL.Rules[*].[Name,Priority,Action]' --output table

# List available managed rule groups
aws wafv2 list-available-managed-rule-groups --scope REGIONAL --region <region> --output table

# Describe a managed rule group
aws wafv2 describe-managed-rule-group \
  --vendor-name AWS \
  --name AWSManagedRulesCommonRuleSet \
  --scope REGIONAL --region <region>

# List IP sets
aws wafv2 list-ip-sets --scope REGIONAL --region <region> --output table

# Get IP set
aws wafv2 get-ip-set \
  --name <ip-set-name> --scope REGIONAL --id <ip-set-id> --region <region>

# List regex pattern sets
aws wafv2 list-regex-pattern-sets --scope REGIONAL --region <region> --output table

# List resources associated with a web ACL
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn <web-acl-arn> \
  --resource-type APPLICATION_LOAD_BALANCER

# Get sampled requests (see what WAF is blocking)
aws wafv2 get-sampled-requests \
  --web-acl-arn <web-acl-arn> \
  --rule-metric-name <metric-name> \
  --scope REGIONAL \
  --time-window StartTime=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ),EndTime=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --max-items 50 --region <region>
```

### Create and Configure

⚠️ **Cost note:** WAF charges: $5/month per web ACL, $1/month per rule, $0.60 per million requests inspected. Managed rule groups may have additional subscription costs.

```bash
# Create an IP set
aws wafv2 create-ip-set \
  --name <ip-set-name> \
  --scope REGIONAL \
  --ip-address-version IPV4 \
  --addresses "192.0.2.0/24" "198.51.100.0/24" \
  --region <region>

# Create a web ACL with AWS managed rules
aws wafv2 create-web-acl \
  --name <web-acl-name> \
  --scope REGIONAL \
  --default-action '{"Allow": {}}' \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=<metric-name> \
  --rules '[
    {
      "Name": "AWSCommonRules",
      "Priority": 1,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet"
        }
      },
      "OverrideAction": {"None": {}},
      "VisibilityConfig": {"SampledRequestsEnabled": true, "CloudWatchMetricsEnabled": true, "MetricName": "AWSCommonRules"}
    }
  ]' \
  --region <region>

# Associate web ACL with an ALB
aws wafv2 associate-web-acl \
  --web-acl-arn <web-acl-arn> \
  --resource-arn <alb-arn>

# Update IP set (must include lock token)
LOCK=$(aws wafv2 get-ip-set --name <ip-set-name> --scope REGIONAL --id <ip-set-id> --region <region> \
  --query 'LockToken' --output text)
aws wafv2 update-ip-set \
  --name <ip-set-name> --scope REGIONAL --id <ip-set-id> \
  --addresses "192.0.2.0/24" "198.51.100.0/24" "203.0.113.0/24" \
  --lock-token "$LOCK" --region <region>

# Enable WAF logging
aws wafv2 put-logging-configuration \
  --logging-configuration '{
    "ResourceArn": "<web-acl-arn>",
    "LogDestinationConfigs": ["<firehose-delivery-stream-arn>"]
  }'
```

### Rate Limiting

```bash
# Add a rate-based rule (limit requests per IP)
# Use update-web-acl and include the rate-based rule in the rules array
# Rate limit: 100-200,000,000 requests per 5-minute window
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Disassociate web ACL from resource
aws wafv2 disassociate-web-acl --resource-arn <alb-arn>

# Delete a web ACL (must disassociate from all resources first)
LOCK=$(aws wafv2 get-web-acl --name <name> --scope REGIONAL --id <id> --region <region> \
  --query 'LockToken' --output text)
aws wafv2 delete-web-acl --name <name> --scope REGIONAL --id <id> --lock-token "$LOCK" --region <region>

# Delete an IP set
LOCK=$(aws wafv2 get-ip-set --name <name> --scope REGIONAL --id <id> --region <region> \
  --query 'LockToken' --output text)
aws wafv2 delete-ip-set --name <name> --scope REGIONAL --id <id> --lock-token "$LOCK" --region <region>
```

## Safety Rules

1. **NEVER** delete or modify web ACLs without explicit user confirmation — may expose applications.
2. **NEVER** expose or log AWS credentials.
3. **ALWAYS** use Count mode first to test rules before switching to Block.
4. **ALWAYS** confirm scope (REGIONAL vs CLOUDFRONT) before operations.
5. **WARN** that removing a web ACL from a resource leaves it unprotected.
6. **WARN** about managed rule group costs and WCU (Web ACL Capacity Unit) limits.

## Best Practices

- Start with AWS Managed Rules (CommonRuleSet, SQLiRuleSet, KnownBadInputsRuleSet).
- Test new rules in Count mode before switching to Block.
- Enable sampled request logging to understand traffic patterns.
- Use rate-based rules to protect against DDoS and brute force.
- Monitor `BlockedRequests` and `AllowedRequests` CloudWatch metrics.

## Common Patterns

### Pattern: Block Bad IPs

```bash
# Create an IP block list
IP_SET=$(aws wafv2 create-ip-set \
  --name blocked-ips \
  --scope REGIONAL \
  --ip-address-version IPV4 \
  --addresses "1.2.3.4/32" "5.6.7.0/24" \
  --region <region> \
  --query 'Summary.Id' --output text)

# Add to web ACL as a block rule (via update-web-acl with the full rule set)
```

### Pattern: Production Web ACL with Common Protections

```bash
# Create a web ACL with multiple managed rule groups
aws wafv2 create-web-acl \
  --name production-waf \
  --scope REGIONAL \
  --default-action '{"Allow": {}}' \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=production-waf \
  --rules '[
    {"Name":"CommonRules","Priority":1,"Statement":{"ManagedRuleGroupStatement":{"VendorName":"AWS","Name":"AWSManagedRulesCommonRuleSet"}},"OverrideAction":{"None":{}},"VisibilityConfig":{"SampledRequestsEnabled":true,"CloudWatchMetricsEnabled":true,"MetricName":"CommonRules"}},
    {"Name":"SQLiRules","Priority":2,"Statement":{"ManagedRuleGroupStatement":{"VendorName":"AWS","Name":"AWSManagedRulesSQLiRuleSet"}},"OverrideAction":{"None":{}},"VisibilityConfig":{"SampledRequestsEnabled":true,"CloudWatchMetricsEnabled":true,"MetricName":"SQLiRules"}},
    {"Name":"BadInputs","Priority":3,"Statement":{"ManagedRuleGroupStatement":{"VendorName":"AWS","Name":"AWSManagedRulesKnownBadInputsRuleSet"}},"OverrideAction":{"None":{}},"VisibilityConfig":{"SampledRequestsEnabled":true,"CloudWatchMetricsEnabled":true,"MetricName":"BadInputs"}}
  ]' \
  --region <region>
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `WAFNonexistentItemException` | Resource not found | Verify name, id, and scope |
| `WAFOptimisticLockException` | Stale lock token | Re-fetch the resource to get current lock token |
| `WAFLimitsExceededException` | Exceeded WCU limit (1500 default) | Reduce rule complexity or request limit increase |
| Legitimate traffic blocked | Managed rule false positive | Use rule exclusions or switch specific rule to Count |
| `WAFInvalidParameterException` on CloudFront | Wrong scope or region | Use `--scope CLOUDFRONT --region us-east-1` |
| Logs not appearing | Logging not configured | Enable logging with `put-logging-configuration` |
