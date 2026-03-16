---
name: cloudfront
description: Manage Amazon CloudFront distributions, cache invalidations, origins, and behaviors via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "⚡",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon CloudFront

Use this skill for CDN operations: creating and managing distributions, configuring origins and cache behaviors, managing SSL certificates, creating cache invalidations, and monitoring distribution metrics.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `cloudfront:*` for full access, or scoped policies for specific operations
- For custom SSL: ACM certificate in `us-east-1` (CloudFront requirement)

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all distributions
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,Domain:DomainName,Status:Status,Enabled:Enabled,Aliases:Aliases.Items[0]}' \
  --output table

# Get distribution details
aws cloudfront get-distribution --id <distribution-id>

# Get distribution config (needed for updates)
aws cloudfront get-distribution-config --id <distribution-id>

# List invalidations for a distribution
aws cloudfront list-invalidations --distribution-id <distribution-id> \
  --query 'InvalidationList.Items[].{Id:Id,Status:Status,Created:CreateTime}' \
  --output table

# Get invalidation status
aws cloudfront get-invalidation \
  --distribution-id <distribution-id> \
  --id <invalidation-id>

# List cache policies
aws cloudfront list-cache-policies \
  --query 'CachePolicyList.Items[].{Id:CachePolicy.Id,Name:CachePolicy.CachePolicyConfig.Name}' \
  --output table

# List origin request policies
aws cloudfront list-origin-request-policies \
  --query 'OriginRequestPolicyList.Items[].{Id:OriginRequestPolicy.Id,Name:OriginRequestPolicy.OriginRequestPolicyConfig.Name}' \
  --output table
```

### Create Invalidations

```bash
# Invalidate specific paths
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths '/index.html' '/css/*' '/js/*'

# Invalidate everything (expensive — use sparingly)
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths '/*'

# Wait for invalidation to complete
aws cloudfront wait invalidation-completed \
  --distribution-id <distribution-id> \
  --id <invalidation-id>
```

⚠️ **Cost note:** First 1,000 invalidation paths/month free. After that, $0.005 per path. Wildcard (`/*`) counts as one path.

### Create a Distribution

⚠️ **Cost note:** CloudFront charges per request + data transfer. No minimum. ~$0.085/GB for first 10TB from US/EU edges.

```bash
# Create a basic S3 origin distribution
aws cloudfront create-distribution \
  --distribution-config '{
    "CallerReference": "'$(date +%s)'",
    "Comment": "<description>",
    "Enabled": true,
    "Origins": {
      "Quantity": 1,
      "Items": [{
        "Id": "s3-origin",
        "DomainName": "<bucket-name>.s3.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }]
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "s3-origin",
      "ViewerProtocolPolicy": "redirect-to-https",
      "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
      "Compress": true,
      "AllowedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      },
      "ForwardedValues": {
        "QueryString": false,
        "Cookies": {"Forward": "none"}
      },
      "MinTTL": 0
    },
    "DefaultRootObject": "index.html",
    "PriceClass": "PriceClass_100",
    "ViewerCertificate": {
      "CloudFrontDefaultCertificate": true
    }
  }'
```

### Update a Distribution

Updating CloudFront requires a get-modify-put cycle:

```bash
# Step 1: Get current config and ETag
aws cloudfront get-distribution-config --id <distribution-id> > dist-config.json

# Step 2: Extract ETag
ETAG=$(jq -r '.ETag' dist-config.json)

# Step 3: Edit the DistributionConfig (remove ETag from the config)
jq '.DistributionConfig' dist-config.json > update-config.json
# ... edit update-config.json ...

# Step 4: Update with the ETag
aws cloudfront update-distribution \
  --id <distribution-id> \
  --distribution-config file://update-config.json \
  --if-match $ETAG
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Step 1: Disable the distribution first
# (Update with "Enabled": false, then wait for deployment)
aws cloudfront wait distribution-deployed --id <distribution-id>

# Step 2: Delete (must be disabled first)
ETAG=$(aws cloudfront get-distribution-config --id <distribution-id> --query 'ETag' --output text)
aws cloudfront delete-distribution --id <distribution-id> --if-match $ETAG
```

⚠️ **A distribution must be disabled before deletion. Disabling can take 15-30 minutes to propagate.**

## Safety Rules

1. **NEVER** delete a distribution without confirming with the user and verifying no active traffic.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** warn that distribution changes take 5-15 minutes to propagate globally.
4. **ALWAYS** recommend HTTPS (redirect-to-https or https-only) for viewer protocol.
5. **WARN** about invalidation costs when invalidating many paths.
6. **WARN** that `/*` invalidations clear the entire cache and may cause origin load spikes.

## Best Practices

- Use Origin Access Control (OAC) instead of OAI for S3 origins — it supports SSE-KMS and newer features.
- Enable compression (`Compress: true`) to reduce data transfer costs.
- Use `PriceClass_100` (US/EU only) or `PriceClass_200` to reduce costs if global coverage isn't needed.
- Set appropriate cache TTLs — longer TTLs reduce origin load and cost.
- Use custom error pages for better user experience on 403/404.

## Common Patterns

### Pattern: Static Website with Custom Domain

```bash
# 1. Create ACM certificate in us-east-1
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS \
  --region us-east-1

# 2. Create distribution with the certificate
# (include Aliases and ViewerCertificate with ACMCertificateArn)

# 3. Create Route 53 alias record pointing to the distribution
```

### Pattern: Invalidate After Deployment

```bash
# Deploy to S3
aws s3 sync ./build/ s3://<bucket-name>/ --delete

# Invalidate changed files
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths '/index.html' '/static/*'

# Wait for completion
aws cloudfront wait invalidation-completed \
  --distribution-id <dist-id> --id <inv-id>
```

### Pattern: Check Cache Hit Ratio

```bash
# Get CloudFront metrics from CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=<distribution-id> Name=Region,Value=Global \
  --start-time $(date -u -v-1d +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average \
  --region us-east-1
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `CNAMEAlreadyExists` | Domain already used by another distribution | Remove the CNAME from the other distribution first |
| `InvalidViewerCertificate` | Certificate not in us-east-1 or not validated | ACM certs for CloudFront MUST be in us-east-1 |
| `DistributionNotDisabled` | Trying to delete an enabled distribution | Disable first, wait for deployment, then delete |
| `AccessDenied` on origin | OAI/OAC misconfigured or S3 bucket policy wrong | Verify bucket policy grants CloudFront access |
| `PreconditionFailed` | ETag mismatch on update | Re-fetch the config to get the latest ETag |
| 403 on S3 objects | Missing `s3:GetObject` permission | Update bucket policy or OAC configuration |
