---
name: appsync
description: Manage AWS AppSync GraphQL APIs, schemas, data sources, resolvers, and API keys via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔗",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS AppSync

Use this skill for managed GraphQL API operations: creating and managing GraphQL APIs, defining schemas, configuring data sources and resolvers, managing API keys, and monitoring API usage.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `appsync:*` for full access, or scoped policies
- Data sources (DynamoDB, Lambda, RDS, OpenSearch, HTTP) must be provisioned separately

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all GraphQL APIs
aws appsync list-graphql-apis \
  --query 'graphqlApis[*].[name,apiId,authenticationType,uris.GRAPHQL]' --output table

# Get API details
aws appsync get-graphql-api --api-id <api-id>

# Get current schema (introspection)
aws appsync get-introspection-schema \
  --api-id <api-id> \
  --format SDL \
  /dev/stdout

# List data sources
aws appsync list-data-sources --api-id <api-id> \
  --query 'dataSources[*].[name,type,serviceRoleArn]' --output table

# Get data source details
aws appsync get-data-source --api-id <api-id> --name <source-name>

# List resolvers for a type
aws appsync list-resolvers --api-id <api-id> --type-name Query \
  --query 'resolvers[*].[fieldName,dataSourceName,kind]' --output table

aws appsync list-resolvers --api-id <api-id> --type-name Mutation \
  --query 'resolvers[*].[fieldName,dataSourceName,kind]' --output table

# Get resolver details
aws appsync get-resolver --api-id <api-id> --type-name Query --field-name <field-name>

# List API keys
aws appsync list-api-keys --api-id <api-id> \
  --query 'apiKeys[*].[id,description,expires]' --output table

# List functions (pipeline resolvers)
aws appsync list-functions --api-id <api-id> \
  --query 'functions[*].[name,functionId,dataSourceName]' --output table

# List types
aws appsync list-types --api-id <api-id> --format SDL \
  --query 'types[*].[name,format]' --output table
```

### Create and Configure

⚠️ **Cost note:** AppSync charges per query/mutation ($4.00 per million) and per real-time update ($2.00 per million). Data transfer and caching incur additional charges.

```bash
# Create a GraphQL API (API key auth)
aws appsync create-graphql-api \
  --name <api-name> \
  --authentication-type API_KEY

# Create with Cognito auth
aws appsync create-graphql-api \
  --name <api-name> \
  --authentication-type AMAZON_COGNITO_USER_POOLS \
  --user-pool-config '{
    "userPoolId": "<user-pool-id>",
    "awsRegion": "<region>",
    "defaultAction": "ALLOW"
  }'

# Upload schema
aws appsync start-schema-creation \
  --api-id <api-id> \
  --definition fileb://schema.graphql

# Check schema creation status
aws appsync get-schema-creation-status --api-id <api-id>

# Create a DynamoDB data source
aws appsync create-data-source \
  --api-id <api-id> \
  --name <source-name> \
  --type AMAZON_DYNAMODB \
  --service-role-arn <role-arn> \
  --dynamodb-config '{
    "tableName": "<table-name>",
    "awsRegion": "<region>"
  }'

# Create a Lambda data source
aws appsync create-data-source \
  --api-id <api-id> \
  --name <source-name> \
  --type AWS_LAMBDA \
  --service-role-arn <role-arn> \
  --lambda-config '{"lambdaFunctionArn": "<function-arn>"}'

# Create a resolver (unit resolver with VTL)
aws appsync create-resolver \
  --api-id <api-id> \
  --type-name Query \
  --field-name getItem \
  --data-source-name <source-name> \
  --request-mapping-template '{
    "version": "2017-02-28",
    "operation": "GetItem",
    "key": {"id": $util.dynamodb.toDynamoDBJson($ctx.args.id)}
  }' \
  --response-mapping-template '$util.toJson($ctx.result)'

# Create a JS resolver (AppSync JavaScript runtime)
aws appsync create-resolver \
  --api-id <api-id> \
  --type-name Query \
  --field-name getItem \
  --data-source-name <source-name> \
  --runtime '{"name": "APPSYNC_JS", "runtimeVersion": "1.0.0"}' \
  --code 'export function request(ctx) { return { operation: "GetItem", key: util.dynamodb.toMapValues({ id: ctx.args.id }) }; } export function response(ctx) { return ctx.result; }'

# Create an API key
aws appsync create-api-key \
  --api-id <api-id> \
  --description "Development key" \
  --expires $(date -u -v+30d +%s)

# Enable caching
aws appsync create-api-cache \
  --api-id <api-id> \
  --ttl 3600 \
  --api-caching-behavior FULL_REQUEST_CACHING \
  --type SMALL
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a resolver
aws appsync delete-resolver --api-id <api-id> --type-name Query --field-name <field-name>

# Delete a data source
aws appsync delete-data-source --api-id <api-id> --name <source-name>

# Delete an API key
aws appsync delete-api-key --api-id <api-id> --id <key-id>

# Delete an entire GraphQL API
aws appsync delete-graphql-api --api-id <api-id>
```

## Safety Rules

1. **NEVER** delete APIs or data sources without explicit user confirmation.
2. **NEVER** expose or log API keys, AWS credentials, or auth tokens.
3. **ALWAYS** confirm the API ID before schema or resolver changes.
4. **ALWAYS** recommend Cognito or IAM auth over API keys for production.
5. **WARN** about cost implications for high-throughput APIs.
6. **WARN** that schema changes can break existing clients.

## Best Practices

- Use Cognito User Pools or IAM for production auth (API keys for dev only).
- Use pipeline resolvers for complex operations that touch multiple data sources.
- Use the JavaScript runtime for new resolvers (VTL is legacy).
- Enable caching for read-heavy workloads.
- Use field-level authorization with `@auth` directives.

## Common Patterns

### Pattern: Test a Query

```bash
# Get the API URL and key
API_URL=$(aws appsync get-graphql-api --api-id <api-id> \
  --query 'graphqlApi.uris.GRAPHQL' --output text)
API_KEY=$(aws appsync list-api-keys --api-id <api-id> \
  --query 'apiKeys[0].id' --output text)

# Run a query
curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"query": "{ listItems { items { id name } } }"}' | jq .
```

### Pattern: Export and Backup Schema

```bash
aws appsync get-introspection-schema \
  --api-id <api-id> \
  --format SDL \
  schema-backup-$(date +%Y%m%d).graphql
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NotFoundException` | API or resource doesn't exist | Verify api-id with `list-graphql-apis` |
| `UnauthorizedException` | Invalid or expired API key | Check API key expiry with `list-api-keys` |
| Schema creation failed | Invalid GraphQL schema | Check `get-schema-creation-status` for error details |
| Resolver error | VTL/JS template issue | Check CloudWatch logs for resolver errors |
| `GraphQLSchemaException` | Schema has validation errors | Fix type definitions and re-upload |
| Data source connection failed | IAM role or network issue | Verify service role and VPC/security group config |
