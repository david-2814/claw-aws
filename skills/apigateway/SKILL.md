---
name: apigateway
description: Manage Amazon API Gateway REST APIs, HTTP APIs, WebSocket APIs, stages, and deployments via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🚪",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon API Gateway

Use this skill for API management: creating and configuring REST, HTTP, and WebSocket APIs, managing resources and methods, deploying stages, configuring authorizers, and monitoring API usage.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `apigateway:*`, `execute-api:*` for full access
- Backend integrations (Lambda, HTTP endpoints, etc.) must be configured separately
- REST API uses `apigateway`, HTTP/WebSocket API uses `apigatewayv2`

## Common Operations

### REST API — List and Inspect (Read-Only)

```bash
# List REST APIs
aws apigateway get-rest-apis \
  --query 'items[*].[id,name,createdDate,endpointConfiguration.types[0]]' --output table

# Get REST API details
aws apigateway get-rest-api --rest-api-id <api-id>

# List resources (paths)
aws apigateway get-resources --rest-api-id <api-id> \
  --query 'items[*].[id,path,resourceMethods]' --output table

# Get a method
aws apigateway get-method --rest-api-id <api-id> --resource-id <resource-id> --http-method GET

# Get integration
aws apigateway get-integration --rest-api-id <api-id> --resource-id <resource-id> --http-method GET

# List stages
aws apigateway get-stages --rest-api-id <api-id> \
  --query 'item[*].[stageName,deploymentId,description,createdDate]' --output table

# List deployments
aws apigateway get-deployments --rest-api-id <api-id> --output table

# List authorizers
aws apigateway get-authorizers --rest-api-id <api-id> --output table

# List API keys
aws apigateway get-api-keys --include-values \
  --query 'items[*].[id,name,enabled,value]' --output table

# List usage plans
aws apigateway get-usage-plans \
  --query 'items[*].[id,name,throttle,quota]' --output table

# Get usage for a plan
aws apigateway get-usage \
  --usage-plan-id <plan-id> \
  --key-id <api-key-id> \
  --start-date 2024-01-01 \
  --end-date 2024-01-31

# List domain names
aws apigateway get-domain-names \
  --query 'items[*].[domainName,certificateArn,distributionDomainName]' --output table

# Test a method invocation
aws apigateway test-invoke-method \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method GET \
  --path-with-query-string '/'
```

### HTTP API (apigatewayv2) — List and Inspect

```bash
# List HTTP/WebSocket APIs
aws apigatewayv2 get-apis \
  --query 'Items[*].[ApiId,Name,ProtocolType,ApiEndpoint]' --output table

# Get API details
aws apigatewayv2 get-api --api-id <api-id>

# List routes
aws apigatewayv2 get-routes --api-id <api-id> \
  --query 'Items[*].[RouteId,RouteKey,Target]' --output table

# List integrations
aws apigatewayv2 get-integrations --api-id <api-id> \
  --query 'Items[*].[IntegrationId,IntegrationType,IntegrationUri]' --output table

# List stages
aws apigatewayv2 get-stages --api-id <api-id> \
  --query 'Items[*].[StageName,AutoDeploy,DeploymentId]' --output table

# List authorizers
aws apigatewayv2 get-authorizers --api-id <api-id> --output table
```

### Create APIs

⚠️ **Cost note:** REST API: $3.50 per million calls + data transfer. HTTP API: $1.00 per million calls (cheaper, recommended for new APIs). WebSocket: $1.00 per million messages + $0.25 per million connection minutes.

```bash
# Create an HTTP API with Lambda integration (simplest)
aws apigatewayv2 create-api \
  --name <api-name> \
  --protocol-type HTTP \
  --target <lambda-function-arn>

# Create an HTTP API (manual setup)
aws apigatewayv2 create-api \
  --name <api-name> \
  --protocol-type HTTP

# Add a Lambda integration to HTTP API
aws apigatewayv2 create-integration \
  --api-id <api-id> \
  --integration-type AWS_PROXY \
  --integration-uri <lambda-function-arn> \
  --payload-format-version "2.0"

# Add a route
aws apigatewayv2 create-route \
  --api-id <api-id> \
  --route-key "GET /items" \
  --target "integrations/<integration-id>"

# Create a stage with auto-deploy
aws apigatewayv2 create-stage \
  --api-id <api-id> \
  --stage-name prod \
  --auto-deploy

# Create a REST API
aws apigateway create-rest-api \
  --name <api-name> \
  --endpoint-configuration types=REGIONAL

# Add a resource to REST API
PARENT_ID=$(aws apigateway get-resources --rest-api-id <api-id> \
  --query 'items[?path==`/`].id' --output text)

aws apigateway create-resource \
  --rest-api-id <api-id> \
  --parent-id $PARENT_ID \
  --path-part items

# Add a method
aws apigateway put-method \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method GET \
  --authorization-type NONE

# Add Lambda integration to REST API
aws apigateway put-integration \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:<region>:lambda:path/2015-03-31/functions/<lambda-arn>/invocations"

# Deploy REST API
aws apigateway create-deployment \
  --rest-api-id <api-id> \
  --stage-name prod \
  --description "Production deployment"
```

### Authorizers

```bash
# Create a Cognito authorizer (HTTP API)
aws apigatewayv2 create-authorizer \
  --api-id <api-id> \
  --authorizer-type JWT \
  --name cognito-auth \
  --identity-source '$request.header.Authorization' \
  --jwt-configuration '{"Audience": ["<client-id>"], "Issuer": "https://cognito-idp.<region>.amazonaws.com/<pool-id>"}'

# Create an API key (REST API)
aws apigateway create-api-key \
  --name <key-name> \
  --enabled

# Create a usage plan
aws apigateway create-usage-plan \
  --name <plan-name> \
  --throttle burstLimit=100,rateLimit=50 \
  --quota limit=10000,period=MONTH \
  --api-stages apiId=<api-id>,stage=prod
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete an HTTP/WebSocket API
aws apigatewayv2 delete-api --api-id <api-id>

# Delete a REST API
aws apigateway delete-rest-api --rest-api-id <api-id>

# Delete a stage
aws apigateway delete-stage --rest-api-id <api-id> --stage-name <stage>
aws apigatewayv2 delete-stage --api-id <api-id> --stage-name <stage>

# Delete a route
aws apigatewayv2 delete-route --api-id <api-id> --route-id <route-id>
```

## Safety Rules

1. **NEVER** delete APIs without explicit user confirmation.
2. **NEVER** expose or log API keys, authorizer tokens, or AWS credentials.
3. **ALWAYS** confirm the API ID and stage before deploying or deleting.
4. **ALWAYS** recommend HTTP APIs over REST APIs for new projects (cheaper, simpler).
5. **WARN** about breaking changes when modifying production stages.
6. **WARN** about throttling limits affecting production traffic.

## Best Practices

- Use HTTP APIs for new projects (lower cost, simpler, faster).
- Use stages for environment separation (dev, staging, prod).
- Enable CloudWatch logging and X-Ray tracing for debugging.
- Set throttling and quota limits to protect backends.
- Use custom domain names with ACM certificates for production.

## Common Patterns

### Pattern: Quick Lambda API

```bash
# Create HTTP API with Lambda — single command
API_ID=$(aws apigatewayv2 create-api \
  --name quick-api \
  --protocol-type HTTP \
  --target <lambda-function-arn> \
  --query 'ApiId' --output text)

echo "API Endpoint: $(aws apigatewayv2 get-api --api-id $API_ID --query 'ApiEndpoint' --output text)"
```

### Pattern: Custom Domain Setup

```bash
# Create custom domain (HTTP API)
aws apigatewayv2 create-domain-name \
  --domain-name api.example.com \
  --domain-name-configurations CertificateArn=<acm-cert-arn>

# Map to API stage
aws apigatewayv2 create-api-mapping \
  --domain-name api.example.com \
  --api-id <api-id> \
  --stage prod
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NotFoundException` | API or resource doesn't exist | Verify with list commands |
| `403 Forbidden` | Missing auth or API key | Check authorizer config and API key requirement |
| `500 Internal Server Error` | Lambda error or integration misconfigured | Check Lambda logs and integration setup |
| `429 Too Many Requests` | Throttled | Increase throttle limits or implement retry |
| CORS errors | Missing CORS configuration | Enable CORS on API or add OPTIONS method |
| Deployment not reflecting changes | Stale stage | Create new deployment or enable auto-deploy |
