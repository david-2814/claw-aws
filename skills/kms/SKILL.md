---
name: kms
description: Manage AWS KMS keys, aliases, grants, key policies, and encryption/decryption operations via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔑",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS KMS (Key Management Service)

Use this skill for encryption key management: creating and managing KMS keys, encrypting and decrypting data, managing key policies and grants, rotating keys, and configuring cross-account access.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `kms:*` for full access, or scoped policies

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all keys
aws kms list-keys --query 'Keys[*].KeyId' --output table

# Describe a key
aws kms describe-key --key-id <key-id>

# Describe key by alias
aws kms describe-key --key-id alias/<alias-name>

# List aliases
aws kms list-aliases \
  --query 'Aliases[*].[AliasName,TargetKeyId]' --output table

# List aliases for a specific key
aws kms list-aliases --key-id <key-id>

# Get key policy
aws kms get-key-policy --key-id <key-id> --policy-name default --output text

# Get key rotation status
aws kms get-key-rotation-status --key-id <key-id>

# List grants for a key
aws kms list-grants --key-id <key-id> \
  --query 'Grants[*].[GrantId,GranteePrincipal,Operations]' --output table

# List key policies
aws kms list-key-policies --key-id <key-id>

# List resource tags
aws kms list-resource-tags --key-id <key-id> --output table
```

### Encrypt and Decrypt

```bash
# Encrypt data (up to 4KB)
aws kms encrypt \
  --key-id <key-id> \
  --plaintext fileb://secret.txt \
  --query 'CiphertextBlob' --output text > encrypted.b64

# Decrypt data
aws kms decrypt \
  --ciphertext-blob fileb://<(base64 -d encrypted.b64) \
  --query 'Plaintext' --output text | base64 -d > decrypted.txt

# Encrypt with encryption context (recommended)
aws kms encrypt \
  --key-id <key-id> \
  --plaintext "sensitive data" \
  --encryption-context Purpose=config,Environment=prod \
  --query 'CiphertextBlob' --output text

# Decrypt with encryption context
aws kms decrypt \
  --ciphertext-blob fileb://<(echo '<ciphertext>' | base64 -d) \
  --encryption-context Purpose=config,Environment=prod \
  --query 'Plaintext' --output text | base64 -d

# Generate a data key (for envelope encryption)
aws kms generate-data-key \
  --key-id <key-id> \
  --key-spec AES_256

# Generate data key without plaintext (for storage)
aws kms generate-data-key-without-plaintext \
  --key-id <key-id> \
  --key-spec AES_256

# Re-encrypt under a different key
aws kms re-encrypt \
  --ciphertext-blob fileb://<ciphertext-file> \
  --source-key-id <old-key-id> \
  --destination-key-id <new-key-id>
```

### Create and Configure

⚠️ **Cost note:** KMS charges $1.00/month per customer-managed key. API calls: $0.03 per 10,000 requests. AWS-managed keys (aws/*) are free.

```bash
# Create a symmetric key
aws kms create-key \
  --description "Application encryption key" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT \
  --tags '[{"TagKey": "Environment", "TagValue": "production"}]'

# Create an asymmetric key (RSA for signing)
aws kms create-key \
  --description "Code signing key" \
  --key-usage SIGN_VERIFY \
  --key-spec RSA_2048

# Create an HMAC key
aws kms create-key \
  --description "HMAC key" \
  --key-usage GENERATE_VERIFY_MAC \
  --key-spec HMAC_256

# Create an alias
aws kms create-alias \
  --alias-name alias/<alias-name> \
  --target-key-id <key-id>

# Enable automatic key rotation (every year)
aws kms enable-key-rotation --key-id <key-id>

# Set custom rotation period (90-2560 days)
aws kms enable-key-rotation \
  --key-id <key-id> \
  --rotation-period-in-days 180

# Update key description
aws kms update-key-description \
  --key-id <key-id> \
  --description "Updated description"

# Create a grant (delegate key usage)
aws kms create-grant \
  --key-id <key-id> \
  --grantee-principal <iam-role-arn> \
  --operations Encrypt Decrypt GenerateDataKey \
  --constraints '{"EncryptionContextSubset": {"Department": "Finance"}}'

# Update key policy
aws kms put-key-policy \
  --key-id <key-id> \
  --policy-name default \
  --policy file://key-policy.json

# Tag a key
aws kms tag-resource \
  --key-id <key-id> \
  --tags '[{"TagKey": "Project", "TagValue": "MyApp"}]'
```

### Key Lifecycle

```bash
# Disable a key (temporarily prevent use)
aws kms disable-key --key-id <key-id>

# Enable a key
aws kms enable-key --key-id <key-id>

# Import key material (for imported keys)
# Step 1: Get parameters for import
aws kms get-parameters-for-import \
  --key-id <key-id> \
  --wrapping-algorithm RSAES_OAEP_SHA_256 \
  --wrapping-key-spec RSA_2048
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands. Deleting a KMS key is irreversible and makes all data encrypted with it permanently unrecoverable.**

```bash
# Schedule key deletion (7-30 day waiting period)
aws kms schedule-key-deletion \
  --key-id <key-id> \
  --pending-window-in-days 30

# Cancel scheduled deletion (during waiting period)
aws kms cancel-key-deletion --key-id <key-id>

# Delete an alias
aws kms delete-alias --alias-name alias/<alias-name>

# Revoke a grant
aws kms revoke-grant --key-id <key-id> --grant-id <grant-id>

# Retire a grant
aws kms retire-grant --grant-id <grant-id> --key-id <key-id>
```

## Safety Rules

1. **NEVER** schedule key deletion without explicit user confirmation — encrypted data becomes PERMANENTLY unrecoverable.
2. **NEVER** expose or log plaintext key material, decrypted data, or AWS credentials.
3. **ALWAYS** use the maximum pending window (30 days) for key deletion.
4. **ALWAYS** recommend encryption context for all encrypt/decrypt operations.
5. **WARN** that disabling a key prevents all encryption/decryption operations using it.
6. **WARN** about the impact of key policy changes — can lock out all access.

## Best Practices

- Use aliases to reference keys (easier to rotate and manage).
- Enable automatic key rotation for symmetric keys.
- Use encryption context to bind ciphertext to its intended use.
- Use grants for temporary, scoped access instead of broad key policies.
- Use envelope encryption (generate-data-key) for large data.
- Never use the same key for different purposes.

## Common Patterns

### Pattern: Envelope Encryption

```bash
# Generate a data key
DATA_KEY=$(aws kms generate-data-key \
  --key-id alias/my-key \
  --key-spec AES_256)

# Extract plaintext key and encrypted key
PLAINTEXT=$(echo $DATA_KEY | jq -r '.Plaintext')
ENCRYPTED_KEY=$(echo $DATA_KEY | jq -r '.CiphertextBlob')

# Use plaintext key to encrypt data locally (with openssl)
echo "$PLAINTEXT" | base64 -d > /tmp/datakey.bin
openssl enc -aes-256-cbc -in largefile.dat -out largefile.enc -pass file:/tmp/datakey.bin
rm /tmp/datakey.bin  # Delete plaintext key immediately

# Store encrypted data key alongside encrypted data
echo "$ENCRYPTED_KEY" > largefile.key
```

### Pattern: Audit Key Usage

```bash
# Find who used a KMS key (via CloudTrail)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<key-id> \
  --max-results 20 \
  --query 'Events[*].[EventTime,EventName,Username]' --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NotFoundException` | Key doesn't exist or was deleted | Check `list-keys`; deleted keys can't be recovered |
| `DisabledException` | Key is disabled | Enable with `enable-key` |
| `InvalidCiphertextException` | Wrong key or missing encryption context | Verify key ID and encryption context match |
| `KMSAccessDeniedException` | IAM or key policy blocks access | Check both IAM policy and key policy |
| `KMSInvalidStateException` | Key is pending deletion or import | Check key state with `describe-key` |
| `KeyUnavailableException` | Key is in a custom key store that's disconnected | Reconnect the custom key store |
