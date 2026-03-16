---
name: acm
description: Manage AWS Certificate Manager certificates, validation, renewal, and import for ALB, CloudFront, and API Gateway via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📜",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS Certificate Manager (ACM)

Use this skill for TLS/SSL certificate operations: requesting and validating certificates, importing third-party certificates, monitoring renewal status, and managing certificates used by ALB, CloudFront, and API Gateway.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `acm:*` for full access
- For CloudFront certificates: must be in **us-east-1**
- DNS access (Route 53 or external) for DNS validation

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all certificates
aws acm list-certificates \
  --query 'CertificateSummaryList[*].[DomainName,CertificateArn,Status,Type]' --output table

# List including expired
aws acm list-certificates --includes keyTypes=RSA_2048,EC_prime256v1 \
  --certificate-statuses ISSUED PENDING_VALIDATION EXPIRED FAILED --output table

# Describe a certificate
aws acm describe-certificate --certificate-arn <cert-arn>

# Get validation details
aws acm describe-certificate --certificate-arn <cert-arn> \
  --query 'Certificate.DomainValidationOptions[*].[DomainName,ValidationStatus,ValidationMethod,ResourceRecord]' --output table

# Get certificate body (PEM)
aws acm get-certificate --certificate-arn <cert-arn>

# List tags
aws acm list-tags-for-certificate --certificate-arn <cert-arn> --output table

# Check renewal status
aws acm describe-certificate --certificate-arn <cert-arn> \
  --query 'Certificate.[DomainName,Status,RenewalSummary.RenewalStatus,NotAfter]' --output table
```

### Request Certificates

⚠️ **Cost note:** Public ACM certificates are **free**. Private CA certificates: $0.75/month per certificate.

```bash
# Request a public certificate (DNS validation — recommended)
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" "www.example.com" \
  --validation-method DNS

# Request with email validation
aws acm request-certificate \
  --domain-name example.com \
  --validation-method EMAIL

# Request for CloudFront (must be us-east-1)
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS \
  --region us-east-1

# Get DNS validation records (after requesting)
aws acm describe-certificate --certificate-arn <cert-arn> \
  --query 'Certificate.DomainValidationOptions[*].ResourceRecord.[Name,Type,Value]' --output table

# Add DNS validation records to Route 53 automatically
CERT_ARN="<cert-arn>"
HOSTED_ZONE_ID="<zone-id>"

# Get the validation record
RECORD=$(aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord')

NAME=$(echo $RECORD | jq -r '.Name')
VALUE=$(echo $RECORD | jq -r '.Value')

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$NAME\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$VALUE\"}]
      }
    }]
  }"

# Resend validation email
aws acm resend-validation-email \
  --certificate-arn <cert-arn> \
  --domain example.com \
  --validation-domain example.com
```

### Import Certificates

```bash
# Import a third-party certificate
aws acm import-certificate \
  --certificate fileb://cert.pem \
  --private-key fileb://key.pem \
  --certificate-chain fileb://chain.pem

# Re-import (update) an existing certificate
aws acm import-certificate \
  --certificate-arn <cert-arn> \
  --certificate fileb://new-cert.pem \
  --private-key fileb://new-key.pem \
  --certificate-chain fileb://new-chain.pem

# Tag a certificate
aws acm add-tags-to-certificate \
  --certificate-arn <cert-arn> \
  --tags Key=Environment,Value=production Key=Application,Value=web
```

### Renewal

```bash
# Request certificate renewal (for imported certs — ACM auto-renews public certs)
aws acm renew-certificate --certificate-arn <cert-arn>

# Check all certificates nearing expiry
aws acm list-certificates --certificate-statuses ISSUED \
  --query 'CertificateSummaryList[*].CertificateArn' --output text | tr '\t' '\n' | while read arn; do
  aws acm describe-certificate --certificate-arn "$arn" \
    --query 'Certificate.[DomainName,NotAfter,RenewalSummary.RenewalStatus]' --output text
done
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a certificate (must not be in use by any resource)
aws acm delete-certificate --certificate-arn <cert-arn>
```

## Safety Rules

1. **NEVER** delete certificates without verifying they aren't attached to any resource.
2. **NEVER** expose or log private keys or AWS credentials.
3. **ALWAYS** use DNS validation for automated renewal.
4. **ALWAYS** request CloudFront certificates in us-east-1.
5. **WARN** that email validation requires manual action for renewal.
6. **WARN** about certificate expiry — monitor and renew before expiration.

## Best Practices

- Use DNS validation for automatic renewal without manual intervention.
- Request wildcard certificates (`*.example.com`) to cover subdomains.
- Use ACM-managed certificates over imported ones when possible (free + auto-renewal).
- Monitor certificate expiry with CloudWatch or AWS Config rules.
- Tag certificates with environment and application for tracking.

## Common Patterns

### Pattern: Full HTTPS Setup

```bash
# Request certificate
CERT_ARN=$(aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS \
  --query 'CertificateArn' --output text)

echo "Certificate ARN: $CERT_ARN"
echo "Add the DNS validation records, then wait for ISSUED status:"
aws acm wait certificate-validated --certificate-arn $CERT_ARN
echo "Certificate validated!"
```

### Pattern: Find Expiring Certificates

```bash
aws acm list-certificates --certificate-statuses ISSUED \
  --query 'CertificateSummaryList[*].CertificateArn' --output text | tr '\t' '\n' | while read arn; do
  EXPIRY=$(aws acm describe-certificate --certificate-arn "$arn" \
    --query 'Certificate.NotAfter' --output text)
  DOMAIN=$(aws acm describe-certificate --certificate-arn "$arn" \
    --query 'Certificate.DomainName' --output text)
  echo "$DOMAIN expires: $EXPIRY"
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `PENDING_VALIDATION` stuck | DNS record not added or not propagated | Verify CNAME record exists; wait for DNS propagation |
| `FAILED` status | Validation timed out (72 hours) | Request a new certificate and validate promptly |
| `ResourceInUseException` on delete | Certificate attached to a resource | Remove from ALB/CloudFront/API GW first |
| Can't use cert with CloudFront | Certificate not in us-east-1 | Re-request in us-east-1 region |
| Renewal failed | DNS validation record removed | Re-add the CNAME validation record |
| Import failed | PEM format issue or key mismatch | Verify cert, key, and chain are valid PEM and match |
