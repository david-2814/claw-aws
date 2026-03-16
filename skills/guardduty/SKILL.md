---
name: guardduty
description: Manage Amazon GuardDuty threat detection, findings, detectors, and IP/threat lists via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔍",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon GuardDuty

Use this skill for threat detection operations: enabling and configuring GuardDuty detectors, reviewing and managing findings, configuring trusted IP lists and threat intel sets, managing member accounts, and suppressing known-good findings.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `guardduty:*` for full access, or scoped policies
- GuardDuty requires a detector per region — enable in each region you use

## Common Operations

### List and Inspect (Read-Only)

```bash
# List detectors
aws guardduty list-detectors --output table

# Get detector details
aws guardduty get-detector --detector-id <detector-id>

# List findings (IDs only)
aws guardduty list-findings --detector-id <detector-id>

# List findings with filter (high severity)
aws guardduty list-findings \
  --detector-id <detector-id> \
  --finding-criteria '{
    "Criterion": {
      "severity": {"Gte": 7}
    }
  }' \
  --sort-criteria '{"AttributeName": "severity", "OrderBy": "DESC"}'

# Get finding details
aws guardduty get-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id-1> <finding-id-2>

# Get finding details (summary view)
aws guardduty get-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id> \
  --query 'Findings[*].[Type,Severity,Title,Description,Resource.ResourceType]' \
  --output table

# Get finding statistics
aws guardduty get-findings-statistics \
  --detector-id <detector-id> \
  --finding-statistic-types COUNT_BY_SEVERITY

# List filters
aws guardduty list-filters --detector-id <detector-id> --output table

# Get filter details
aws guardduty get-filter --detector-id <detector-id> --filter-name <filter-name>

# List IP sets (trusted IPs)
aws guardduty list-ip-sets --detector-id <detector-id> --output table

# List threat intel sets
aws guardduty list-threat-intel-sets --detector-id <detector-id> --output table

# List member accounts
aws guardduty list-members --detector-id <detector-id> --output table

# Get usage statistics
aws guardduty get-usage-statistics \
  --detector-id <detector-id> \
  --usage-statistic-type SUM_BY_DATA_SOURCE \
  --usage-criteria '{"DataSources": ["CLOUD_TRAIL", "DNS_LOGS", "FLOW_LOGS"]}'

# List coverage (runtime monitoring)
aws guardduty list-coverage --detector-id <detector-id>
```

### Enable and Configure

⚠️ **Cost note:** GuardDuty pricing is based on data analyzed. CloudTrail events: $4.00 per million events (first 500M). VPC Flow Logs/DNS logs: $1.00-$1.50 per GB. 30-day free trial for new accounts.

```bash
# Enable GuardDuty (creates a detector)
aws guardduty create-detector --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES

# Enable additional features
aws guardduty update-detector \
  --detector-id <detector-id> \
  --enable \
  --features '[
    {"Name": "S3_DATA_EVENTS", "Status": "ENABLED"},
    {"Name": "EKS_AUDIT_LOGS", "Status": "ENABLED"},
    {"Name": "RUNTIME_MONITORING", "Status": "ENABLED"},
    {"Name": "LAMBDA_NETWORK_LOGS", "Status": "ENABLED"}
  ]'

# Create a trusted IP list
aws guardduty create-ip-set \
  --detector-id <detector-id> \
  --name trusted-ips \
  --format TXT \
  --location s3://<bucket>/trusted-ips.txt \
  --activate

# Create a threat intel set
aws guardduty create-threat-intel-set \
  --detector-id <detector-id> \
  --name custom-threats \
  --format TXT \
  --location s3://<bucket>/threat-ips.txt \
  --activate

# Create a findings filter (suppress known-good)
aws guardduty create-filter \
  --detector-id <detector-id> \
  --name suppress-known-scanner \
  --action ARCHIVE \
  --finding-criteria '{
    "Criterion": {
      "type": {"Eq": ["Recon:EC2/PortProbeUnprotectedPort"]},
      "service.action.portProbeAction.portProbeDetails.remoteIpDetails.ipAddressV4": {"Eq": ["<known-scanner-ip>"]}
    }
  }'
```

### Manage Findings

```bash
# Archive findings (mark as handled)
aws guardduty archive-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id-1> <finding-id-2>

# Unarchive findings
aws guardduty unarchive-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id>

# Generate sample findings (for testing)
aws guardduty create-sample-findings \
  --detector-id <detector-id> \
  --finding-types "Recon:EC2/PortProbeUnprotectedPort" "UnauthorizedAccess:EC2/SSHBruteForce"

# Update feedback on a finding
aws guardduty update-findings-feedback \
  --detector-id <detector-id> \
  --finding-ids <finding-id> \
  --feedback USEFUL
```

### Multi-Account Management

```bash
# Invite a member account
aws guardduty create-members \
  --detector-id <detector-id> \
  --account-details '[{"AccountId": "<member-account-id>", "Email": "admin@example.com"}]'

aws guardduty invite-members \
  --detector-id <detector-id> \
  --account-ids <member-account-id>

# Accept invitation (run from member account)
aws guardduty accept-invitation \
  --detector-id <member-detector-id> \
  --administrator-id <admin-account-id> \
  --invitation-id <invitation-id>
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Disable GuardDuty (stops all monitoring)
aws guardduty delete-detector --detector-id <detector-id>

# Delete an IP set
aws guardduty delete-ip-set --detector-id <detector-id> --ip-set-id <ip-set-id>

# Delete a filter
aws guardduty delete-filter --detector-id <detector-id> --filter-name <filter-name>

# Disassociate a member account
aws guardduty disassociate-members --detector-id <detector-id> --account-ids <account-id>
```

## Safety Rules

1. **NEVER** delete a detector without explicit user confirmation — stops all threat monitoring.
2. **NEVER** expose or log AWS credentials.
3. **ALWAYS** investigate high-severity findings before archiving.
4. **ALWAYS** confirm the detector ID and region before modifications.
5. **WARN** that disabling GuardDuty deletes all existing findings.
6. **WARN** about cost implications when enabling additional data sources.

## Best Practices

- Enable GuardDuty in all regions, even unused ones (detect unauthorized activity).
- Enable S3 protection, EKS audit logs, and runtime monitoring for comprehensive coverage.
- Use suppression filters for known false positives instead of ignoring findings.
- Integrate with EventBridge for automated incident response.
- Review high/medium severity findings daily.

## Common Patterns

### Pattern: Daily Security Review

```bash
DETECTOR=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)

# Get high-severity findings from last 24 hours
aws guardduty list-findings \
  --detector-id $DETECTOR \
  --finding-criteria '{
    "Criterion": {
      "severity": {"Gte": 7},
      "updatedAt": {"GreaterThan": '$(date -u -v-1d +%s000)'}
    }
  }' | jq -r '.FindingIds[]' | while read fid; do
  aws guardduty get-findings --detector-id $DETECTOR --finding-ids "$fid" \
    --query 'Findings[0].[Severity,Type,Title]' --output text
done
```

### Pattern: Auto-Remediate with EventBridge

```bash
# Create EventBridge rule for high-severity findings
aws events put-rule \
  --name guardduty-high-severity \
  --event-pattern '{
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {"severity": [{"numeric": [">=", 7]}]}
  }'

# Target a Lambda for auto-remediation
aws events put-targets \
  --rule guardduty-high-severity \
  --targets '[{"Id":"remediate","Arn":"<lambda-arn>"}]'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `DetectorNotFoundException` | No detector in this region | Enable GuardDuty with `create-detector` |
| `BadRequestException` on create-detector | GuardDuty already enabled | Use `list-detectors` to find existing detector |
| No findings appearing | Insufficient data or new account | Wait 24-48h; GuardDuty needs baseline data |
| `AccessDeniedException` | Missing IAM permissions | Check for `guardduty:*` in IAM policy |
| High false positive rate | Generic findings on known services | Create suppression filters for known-good patterns |
