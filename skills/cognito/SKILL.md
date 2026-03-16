---
name: cognito
description: Manage Amazon Cognito user pools, identity pools, users, groups, and authentication settings via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔐",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon Cognito

Use this skill for identity and authentication: managing user pools and identity pools, creating and managing users and groups, configuring app clients, setting up MFA, and managing federation with social/SAML/OIDC providers.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `cognito-idp:*`, `cognito-identity:*` for full access

## Common Operations

### User Pools (Read-Only)

```bash
# List user pools
aws cognito-idp list-user-pools --max-results 20 \
  --query 'UserPools[*].[Id,Name,Status,CreationDate]' --output table

# Describe a user pool
aws cognito-idp describe-user-pool --user-pool-id <pool-id>

# List users in a pool
aws cognito-idp list-users --user-pool-id <pool-id> \
  --query 'Users[*].[Username,UserStatus,Enabled,UserCreateDate]' --output table

# List users with filter
aws cognito-idp list-users --user-pool-id <pool-id> \
  --filter 'email = "user@example.com"'

aws cognito-idp list-users --user-pool-id <pool-id> \
  --filter 'status = "Enabled"'

# Get user details
aws cognito-idp admin-get-user --user-pool-id <pool-id> --username <username>

# List groups
aws cognito-idp list-groups --user-pool-id <pool-id> \
  --query 'Groups[*].[GroupName,Description,Precedence]' --output table

# List users in a group
aws cognito-idp list-users-in-group \
  --user-pool-id <pool-id> \
  --group-name <group-name>

# List app clients
aws cognito-idp list-user-pool-clients --user-pool-id <pool-id> \
  --query 'UserPoolClients[*].[ClientId,ClientName]' --output table

# Get app client details
aws cognito-idp describe-user-pool-client \
  --user-pool-id <pool-id> \
  --client-id <client-id>

# List identity providers
aws cognito-idp list-identity-providers --user-pool-id <pool-id> \
  --query 'Providers[*].[ProviderName,ProviderType]' --output table

# List resource servers
aws cognito-idp list-resource-servers --user-pool-id <pool-id>
```

### Identity Pools (Read-Only)

```bash
# List identity pools
aws cognito-identity list-identity-pools --max-results 20 \
  --query 'IdentityPools[*].[IdentityPoolId,IdentityPoolName]' --output table

# Describe an identity pool
aws cognito-identity describe-identity-pool --identity-pool-id <pool-id>

# Get identity pool roles
aws cognito-identity get-identity-pool-roles --identity-pool-id <pool-id>
```

### User Management

```bash
# Create a user (admin)
aws cognito-idp admin-create-user \
  --user-pool-id <pool-id> \
  --username <username> \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --temporary-password "<temp-password>"

# Create a user with no email invite
aws cognito-idp admin-create-user \
  --user-pool-id <pool-id> \
  --username <username> \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id <pool-id> \
  --username <username> \
  --password "<password>" \
  --permanent

# Add user to a group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id <pool-id> \
  --username <username> \
  --group-name <group-name>

# Remove user from a group
aws cognito-idp admin-remove-user-from-group \
  --user-pool-id <pool-id> \
  --username <username> \
  --group-name <group-name>

# Disable a user
aws cognito-idp admin-disable-user \
  --user-pool-id <pool-id> \
  --username <username>

# Enable a user
aws cognito-idp admin-enable-user \
  --user-pool-id <pool-id> \
  --username <username>

# Reset user password (sends reset code)
aws cognito-idp admin-reset-user-password \
  --user-pool-id <pool-id> \
  --username <username>

# Update user attributes
aws cognito-idp admin-update-user-attributes \
  --user-pool-id <pool-id> \
  --username <username> \
  --user-attributes Name=custom:role,Value=admin

# Confirm user signup (skip verification)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id <pool-id> \
  --username <username>

# Sign out user from all devices
aws cognito-idp admin-user-global-sign-out \
  --user-pool-id <pool-id> \
  --username <username>
```

### Create and Configure

⚠️ **Cost note:** Cognito free tier: 50,000 MAU (monthly active users) for user pools. Beyond that: $0.0055/MAU. SAML/OIDC federation: $0.015/MAU. Advanced security: $0.050/MAU.

```bash
# Create a user pool
aws cognito-idp create-user-pool \
  --pool-name <pool-name> \
  --auto-verified-attributes email \
  --username-attributes email \
  --mfa-configuration OFF \
  --policies '{"PasswordPolicy": {"MinimumLength": 8, "RequireUppercase": true, "RequireLowercase": true, "RequireNumbers": true, "RequireSymbols": false}}'

# Create a group
aws cognito-idp create-group \
  --user-pool-id <pool-id> \
  --group-name <group-name> \
  --description "Admin users" \
  --precedence 1

# Create an app client
aws cognito-idp create-user-pool-client \
  --user-pool-id <pool-id> \
  --client-name <client-name> \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --generate-secret

# Create an app client (SPA — no secret)
aws cognito-idp create-user-pool-client \
  --user-pool-id <pool-id> \
  --client-name <client-name> \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --no-generate-secret \
  --supported-identity-providers COGNITO \
  --callback-urls "http://localhost:3000/callback" \
  --logout-urls "http://localhost:3000/logout" \
  --allowed-o-auth-flows code \
  --allowed-o-auth-scopes openid email profile \
  --allowed-o-auth-flows-user-pool-client

# Set up a domain for hosted UI
aws cognito-idp create-user-pool-domain \
  --user-pool-id <pool-id> \
  --domain <unique-domain-prefix>

# Enable MFA
aws cognito-idp set-user-pool-mfa-config \
  --user-pool-id <pool-id> \
  --mfa-configuration ON \
  --software-token-mfa-configuration Enabled=true

# Create an identity pool
aws cognito-identity create-identity-pool \
  --identity-pool-name <pool-name> \
  --allow-unauthenticated-identities \
  --cognito-identity-providers '[{
    "ProviderName": "cognito-idp.<region>.amazonaws.com/<user-pool-id>",
    "ClientId": "<app-client-id>"
  }]'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a user
aws cognito-idp admin-delete-user \
  --user-pool-id <pool-id> \
  --username <username>

# Delete a group
aws cognito-idp delete-group \
  --user-pool-id <pool-id> \
  --group-name <group-name>

# Delete a user pool domain
aws cognito-idp delete-user-pool-domain \
  --user-pool-id <pool-id> \
  --domain <domain>

# Delete a user pool (IRREVERSIBLE)
aws cognito-idp delete-user-pool --user-pool-id <pool-id>

# Delete an identity pool
aws cognito-identity delete-identity-pool --identity-pool-id <pool-id>
```

## Safety Rules

1. **NEVER** delete user pools without explicit user confirmation — all users are permanently lost.
2. **NEVER** expose or log passwords, client secrets, or tokens.
3. **ALWAYS** confirm the user pool ID before user management operations.
4. **ALWAYS** warn before disabling or deleting users.
5. **WARN** about the impact of changing auth flows on existing app clients.
6. **WARN** that deleting a user pool domain breaks all hosted UI integrations.

## Best Practices

- Enable MFA for production user pools (at least optional).
- Use SRP auth flow for browser/mobile clients (never send plain passwords).
- Set appropriate password policies.
- Use groups with IAM role mappings for authorization.
- Enable advanced security features for production (adaptive auth, compromised credentials).

## Common Patterns

### Pattern: Admin Login Test

```bash
# Initiate auth as admin (for testing)
aws cognito-idp admin-initiate-auth \
  --user-pool-id <pool-id> \
  --client-id <client-id> \
  --auth-flow ADMIN_USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=<username>,PASSWORD=<password>
```

### Pattern: Bulk User Export

```bash
# List all users (paginated)
aws cognito-idp list-users --user-pool-id <pool-id> \
  --query 'Users[*].[Username,UserStatus,Attributes[?Name==`email`].Value|[0]]' \
  --output text
```

### Pattern: Set Up Google Federation

```bash
# Create Google identity provider
aws cognito-idp create-identity-provider \
  --user-pool-id <pool-id> \
  --provider-name Google \
  --provider-type Google \
  --provider-details '{"client_id": "<google-client-id>", "client_secret": "<google-secret>", "authorize_scopes": "openid email profile"}' \
  --attribute-mapping '{"email": "email", "username": "sub"}'
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `UserNotFoundException` | Username doesn't exist | Verify with `list-users`; check if pool uses email as username |
| `UsernameExistsException` | User already registered | Check existing users; may need different username |
| `NotAuthorizedException` | Wrong password or disabled user | Verify credentials; check user is enabled |
| `InvalidParameterException` | Missing required attributes | Check user pool schema for required attributes |
| `UserNotConfirmedException` | User hasn't confirmed signup | Use `admin-confirm-sign-up` or resend confirmation |
| `ExpiredCodeException` | Verification code expired | Request new code with `resend-confirmation-code` |
