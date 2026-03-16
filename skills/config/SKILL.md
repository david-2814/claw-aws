---
name: config
description: Manage AWS Config rules, conformance packs, configuration recorder, and compliance evaluation via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📋",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Config

Use this skill for compliance and configuration management: tracking resource configurations, evaluating compliance rules, managing conformance packs, querying resource history, and running advanced queries against your AWS inventory.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `config:*` for full access, or scoped policies
- S3 bucket for configuration snapshots
- AWS Config recorder must be enabled (one-time setup per region)

## Common Operations

### List and Inspect (Read-Only)

```bash
# Check configuration recorder status
aws configservice describe-configuration-recorder-status --output table

# Describe configuration recorders
aws configservice describe-configuration-recorders

# Describe delivery channels
aws configservice describe-delivery-channels

# Describe delivery channel status
aws configservice describe-delivery-channel-status --output table

# List discovered resources by type
aws configservice list-discovered-resources --resource-type AWS::EC2::Instance --output table
aws configservice list-discovered-resources --resource-type AWS::S3::Bucket --output table

# Get resource configuration
aws configservice get-resource-config-history \
  --resource-type AWS::EC2::Instance \
  --resource-id <instance-id> \
  --limit 5

# List Config rules
aws configservice describe-config-rules \
  --query 'ConfigRules[*].[ConfigRuleName,ConfigRuleState,Source.Owner]' \
  --output table

# Get rule compliance
aws configservice describe-compliance-by-config-rule --output table

# Get compliance details for a rule
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name <rule-name> \
  --compliance-types NON_COMPLIANT \
  --output table

# Get compliance by resource
aws configservice describe-compliance-by-resource \
  --resource-type AWS::S3::Bucket \
  --compliance-types NON_COMPLIANT \
  --output table

# Get aggregate compliance
aws configservice describe-aggregate-compliance-by-config-rules \
  --configuration-aggregator-name <aggregator-name> --output table

# List conformance packs
aws configservice describe-conformance-packs --output table

# Get conformance pack compliance
aws configservice describe-conformance-pack-compliance \
  --conformance-pack-name <pack-name> --output table

# List aggregators
aws configservice describe-configuration-aggregators --output table
```

### Advanced Queries

```bash
# Select all EC2 instances
aws configservice select-resource-config \
  --expression "SELECT resourceId, resourceType, configuration.instanceType, tags WHERE resourceType = 'AWS::EC2::Instance'" \
  --output table

# Find all public S3 buckets
aws configservice select-resource-config \
  --expression "SELECT resourceId, resourceName WHERE resourceType = 'AWS::S3::Bucket' AND supplementaryConfiguration.PublicAccessBlockConfiguration.blockPublicAcls = 'false'"

# Find unencrypted EBS volumes
aws configservice select-resource-config \
  --expression "SELECT resourceId WHERE resourceType = 'AWS::EC2::Volume' AND configuration.encrypted = 'false'"

# Count resources by type
aws configservice select-resource-config \
  --expression "SELECT resourceType, COUNT(*) WHERE resourceType LIKE 'AWS::EC2::%' GROUP BY resourceType"

# Find resources with specific tags
aws configservice select-resource-config \
  --expression "SELECT resourceId, resourceType WHERE tags.key = 'Environment' AND tags.value = 'production'"
```

### Setup and Configure

⚠️ **Cost note:** AWS Config charges per configuration item recorded ($0.003 each) and per rule evaluation ($0.001 each). Conformance packs: $0.001 per evaluation. Can add up with many resources.

```bash
# Create a configuration recorder
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=<config-role-arn> \
  --recording-group allSupported=true,includeGlobalResourceTypes=true

# Create a delivery channel
aws configservice put-delivery-channel \
  --delivery-channel '{
    "name": "default",
    "s3BucketName": "<bucket-name>",
    "configSnapshotDeliveryProperties": {"deliveryFrequency": "TwentyFour_Hours"}
  }'

# Start recording
aws configservice start-configuration-recorder --configuration-recorder-name default

# Add a managed Config rule
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "s3-bucket-versioning-enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "S3_BUCKET_VERSIONING_ENABLED"
    },
    "Scope": {"ComplianceResourceTypes": ["AWS::S3::Bucket"]}
  }'

# Add a Config rule with parameters
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "restricted-ssh",
    "Source": {"Owner": "AWS", "SourceIdentifier": "INCOMING_SSH_DISABLED"},
    "Scope": {"ComplianceResourceTypes": ["AWS::EC2::SecurityGroup"]}
  }'

# Deploy a conformance pack
aws configservice put-conformance-pack \
  --conformance-pack-name security-best-practices \
  --template-s3-uri s3://<bucket>/conformance-pack-template.yaml

# Create an aggregator (multi-account/region)
aws configservice put-configuration-aggregator \
  --configuration-aggregator-name org-aggregator \
  --organization-aggregation-source '{"RoleArn": "<role-arn>", "AllAwsRegions": true}'

# Trigger rule evaluation manually
aws configservice start-config-rules-evaluation \
  --config-rule-names <rule-name-1> <rule-name-2>
```

### Remediation

```bash
# Set up auto-remediation for a rule
aws configservice put-remediation-configurations \
  --remediation-configurations '[{
    "ConfigRuleName": "s3-bucket-versioning-enabled",
    "TargetType": "SSM_DOCUMENT",
    "TargetId": "AWS-ConfigureS3BucketVersioning",
    "Parameters": {
      "AutomationAssumeRole": {"StaticValue": {"Values": ["<role-arn>"]}},
      "BucketName": {"ResourceValue": {"Value": "RESOURCE_ID"}}
    },
    "Automatic": true,
    "MaximumAutomaticAttempts": 3,
    "RetryAttemptSeconds": 60
  }]'

# Run remediation manually
aws configservice start-remediation-execution \
  --config-rule-name <rule-name> \
  --resource-keys '[{"resourceType": "AWS::S3::Bucket", "resourceId": "<bucket-name>"}]'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Stop recording
aws configservice stop-configuration-recorder --configuration-recorder-name default

# Delete a Config rule
aws configservice delete-config-rule --config-rule-name <rule-name>

# Delete a conformance pack
aws configservice delete-conformance-pack --conformance-pack-name <pack-name>

# Delete an aggregator
aws configservice delete-configuration-aggregator \
  --configuration-aggregator-name <aggregator-name>

# Delete remediation configuration
aws configservice delete-remediation-configuration --config-rule-name <rule-name>
```

## Safety Rules

1. **NEVER** stop the configuration recorder or delete rules without explicit user confirmation.
2. **NEVER** expose or log AWS credentials.
3. **ALWAYS** test remediation actions in non-production first.
4. **ALWAYS** confirm before enabling automatic remediation.
5. **WARN** about cost implications — many resources × many rules = significant cost.
6. **WARN** that stopping the recorder creates compliance blind spots.

## Best Practices

- Enable AWS Config in all regions for complete visibility.
- Use conformance packs for standardized compliance frameworks (CIS, NIST, PCI DSS).
- Set up auto-remediation for clear-cut violations (e.g., S3 public access).
- Use aggregators for multi-account/multi-region visibility.
- Use advanced queries for custom compliance reports and resource inventory.

## Common Patterns

### Pattern: Compliance Dashboard

```bash
# Quick compliance summary
echo "=== Non-Compliant Rules ==="
aws configservice describe-compliance-by-config-rule \
  --compliance-types NON_COMPLIANT \
  --query 'ComplianceByConfigRules[*].[ConfigRuleName,Compliance.ComplianceType]' \
  --output table

echo "=== Non-Compliant Resources ==="
aws configservice describe-compliance-by-resource \
  --compliance-types NON_COMPLIANT \
  --query 'ComplianceByResources[*].[ResourceType,ResourceId]' \
  --output table
```

### Pattern: Track Resource Changes

```bash
# See how a resource changed over time
aws configservice get-resource-config-history \
  --resource-type AWS::EC2::SecurityGroup \
  --resource-id <sg-id> \
  --limit 10 \
  --query 'configurationItems[*].[configurationItemCaptureTime,configurationItemStatus,configuration]'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NoAvailableConfigurationRecorderException` | Recorder not set up | Create recorder with `put-configuration-recorder` |
| `InsufficientDeliveryPolicyException` | S3 bucket policy issue | Add Config service permissions to bucket policy |
| `MaxNumberOfConfigRulesExceededException` | Too many rules (150 default) | Request limit increase or consolidate rules |
| Rule always shows `NOT_APPLICABLE` | Scope doesn't match any resources | Check `ComplianceResourceTypes` in rule scope |
| Advanced query returns empty | Resources not yet recorded | Wait for recorder to capture; check recorder status |
| Remediation failing | SSM document or role issues | Check remediation execution status and IAM role |
