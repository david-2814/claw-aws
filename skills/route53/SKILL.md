---
name: route53
description: Manage Amazon Route 53 hosted zones, DNS records, health checks, and domain registrations via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🌐",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon Route 53

Use this skill for DNS management: creating and managing hosted zones, adding/updating/deleting DNS records, configuring health checks, managing registered domains, and troubleshooting DNS resolution.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `route53:*` for full access, or scoped policies for specific operations
- For domain registration: `route53domains:*` (operates only in `us-east-1`)

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all hosted zones
aws route53 list-hosted-zones --output table \
  --query 'HostedZones[].{Id:Id,Name:Name,Records:ResourceRecordSetCount,Private:Config.PrivateZone}'

# List records in a hosted zone
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --output table \
  --query 'ResourceRecordSets[].{Name:Name,Type:Type,TTL:TTL,Values:ResourceRecords[].Value|join(`, `,@)}'

# Get hosted zone details
aws route53 get-hosted-zone --id <zone-id>

# List health checks
aws route53 list-health-checks \
  --query 'HealthChecks[].{Id:Id,Type:HealthCheckConfig.Type,FQDN:HealthCheckConfig.FullyQualifiedDomainName,Port:HealthCheckConfig.Port}' \
  --output table

# Get health check status
aws route53 get-health-check-status --health-check-id <health-check-id>

# List registered domains (us-east-1 only)
aws route53domains list-domains --region us-east-1 \
  --query 'Domains[].{Name:DomainName,Expiry:Expiry,AutoRenew:AutoRenew}' \
  --output table

# Test DNS resolution (Route 53 resolver)
aws route53 test-dns-answer \
  --hosted-zone-id <zone-id> \
  --record-name <fqdn> \
  --record-type A
```

### Create / Update Records

⚠️ **Cost note:** Hosted zones cost $0.50/month. Queries cost $0.40 per million for standard records. Health checks start at $0.50/month.

Route 53 uses change batches for record modifications:

```bash
# Create or update a record (UPSERT = create if missing, update if exists)
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "<record-name>",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<ip-address>"}]
      }
    }]
  }'

# Create a CNAME record
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "<subdomain.example.com>",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<target.example.com>"}]
      }
    }]
  }'

# Create an alias record (for ALB, CloudFront, S3, etc.)
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "<record-name>",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "<target-hosted-zone-id>",
          "DNSName": "<target-dns-name>",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# Create MX records
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "<domain>",
        "Type": "MX",
        "TTL": 3600,
        "ResourceRecords": [
          {"Value": "10 mail1.example.com"},
          {"Value": "20 mail2.example.com"}
        ]
      }
    }]
  }'

# Create a hosted zone
aws route53 create-hosted-zone \
  --name <domain-name> \
  --caller-reference "$(date +%s)"

# Check change status
aws route53 get-change --id <change-id>
```

### Health Checks

```bash
# Create an HTTP health check
aws route53 create-health-check \
  --caller-reference "$(date +%s)" \
  --health-check-config '{
    "Type": "HTTP",
    "FullyQualifiedDomainName": "<fqdn>",
    "Port": 80,
    "ResourcePath": "/health",
    "RequestInterval": 30,
    "FailureThreshold": 3
  }'

# Create an HTTPS health check
aws route53 create-health-check \
  --caller-reference "$(date +%s)" \
  --health-check-config '{
    "Type": "HTTPS",
    "FullyQualifiedDomainName": "<fqdn>",
    "Port": 443,
    "ResourcePath": "/health",
    "RequestInterval": 30,
    "FailureThreshold": 3
  }'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a record
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "<record-name>",
        "Type": "<record-type>",
        "TTL": <ttl>,
        "ResourceRecords": [{"Value": "<current-value>"}]
      }
    }]
  }'

# Delete a hosted zone (must be empty of non-default records first)
aws route53 delete-hosted-zone --id <zone-id>

# Delete a health check
aws route53 delete-health-check --health-check-id <health-check-id>
```

⚠️ **Deleting a record requires specifying the EXACT current values (name, type, TTL, records). Always `list-resource-record-sets` first.**

## Safety Rules

1. **NEVER** delete DNS records without explicit user confirmation and verifying current values.
2. **NEVER** delete a hosted zone without listing all records first and confirming.
3. **NEVER** expose or log AWS credentials, access keys, or secret keys.
4. **ALWAYS** use UPSERT instead of CREATE to avoid duplicate record errors.
5. **ALWAYS** warn that DNS changes may take time to propagate (TTL-dependent).
6. **WARN** about split-horizon DNS implications when creating private hosted zones.

## Best Practices

- Use alias records (free, no TTL needed) instead of CNAME for AWS resources (ALB, CloudFront, S3).
- Set reasonable TTLs: 300s for records that may change, 86400s for stable records.
- Enable DNSSEC signing on public hosted zones for security.
- Use health checks with failover routing for high availability.
- Tag hosted zones for cost allocation and organization.

## Common Patterns

### Pattern: Set Up a Domain with WWW Redirect

```bash
ZONE_ID="<zone-id>"

# Root domain → ALB
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "<alb-zone-id>",
          "DNSName": "<alb-dns-name>",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# www → root (CNAME)
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "www.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "example.com"}]
      }
    }]
  }'
```

### Pattern: Weighted Routing (Blue/Green)

```bash
ZONE_ID="<zone-id>"

# Blue environment (90% traffic)
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "A",
        "SetIdentifier": "blue",
        "Weight": 90,
        "TTL": 60,
        "ResourceRecords": [{"Value": "<blue-ip>"}]
      }
    }]
  }'

# Green environment (10% traffic)
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "A",
        "SetIdentifier": "green",
        "Weight": 10,
        "TTL": 60,
        "ResourceRecords": [{"Value": "<green-ip>"}]
      }
    }]
  }'
```

### Pattern: Export All Records from a Zone

```bash
aws route53 list-resource-record-sets --hosted-zone-id <zone-id> \
  --output json > zone-backup-$(date +%Y%m%d).json
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NoSuchHostedZone` | Invalid zone ID | Verify with `list-hosted-zones`; zone IDs start with `/hostedzone/` |
| `InvalidChangeBatch` | Record values don't match for DELETE | List current records first; DELETE requires exact current values |
| `HostedZoneNotEmpty` | Trying to delete zone with records | Delete all non-NS/SOA records first |
| `DelegationSetNotAvailable` | Creating too many zones rapidly | Wait and retry; AWS throttles zone creation |
| `PriorRequestNotComplete` | Previous change still propagating | Wait for INSYNC status with `get-change` |
