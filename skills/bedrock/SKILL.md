---
name: bedrock
description: Manage Amazon Bedrock foundation models, inference, knowledge bases, and model access via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon Bedrock

Use this skill for generative AI operations: listing and invoking foundation models, managing model access, creating knowledge bases, working with guardrails, and managing custom model training jobs.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `bedrock:*` for full access, or scoped policies
- Model access must be requested via the Bedrock console for each model
- Available regions: us-east-1, us-west-2, eu-west-1 (model availability varies)

## Common Operations

### List and Inspect (Read-Only)

```bash
# List available foundation models
aws bedrock list-foundation-models \
  --query 'modelSummaries[].{Id:modelId,Name:modelName,Provider:providerName,Input:inputModalities,Output:outputModalities}' \
  --output table

# List models by provider
aws bedrock list-foundation-models \
  --by-provider Anthropic \
  --query 'modelSummaries[].{Id:modelId,Name:modelName}' \
  --output table

# Get details about a specific model
aws bedrock get-foundation-model --model-identifier anthropic.claude-3-sonnet-20240229-v1:0

# List custom models
aws bedrock list-custom-models \
  --query 'modelSummaries[].{Name:modelName,ARN:modelArn,Status:modelStatus}' \
  --output table

# List provisioned model throughput
aws bedrock list-provisioned-model-throughputs \
  --query 'provisionedModelSummaries[].{Name:provisionedModelName,ModelARN:modelArn,Status:status}' \
  --output table

# List knowledge bases
aws bedrock-agent list-knowledge-bases \
  --query 'knowledgeBaseSummaries[].{Id:knowledgeBaseId,Name:name,Status:status}' \
  --output table

# List guardrails
aws bedrock list-guardrails \
  --query 'guardrails[].{Id:guardrailId,Name:name,Status:status,Version:version}' \
  --output table

# List model invocation logging configuration
aws bedrock get-model-invocation-logging-configuration
```

### Invoke Models

```bash
# Invoke Claude (Anthropic Messages API)
aws bedrock-runtime invoke-model \
  --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
  --content-type application/json \
  --accept application/json \
  --body '{
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }' \
  /dev/stdout 2>/dev/null | jq .

# Invoke Amazon Titan Text
aws bedrock-runtime invoke-model \
  --model-id amazon.titan-text-express-v1 \
  --content-type application/json \
  --accept application/json \
  --body '{
    "inputText": "Summarize the benefits of cloud computing.",
    "textGenerationConfig": {
      "maxTokenCount": 512,
      "temperature": 0.7,
      "topP": 0.9
    }
  }' \
  /dev/stdout 2>/dev/null | jq .

# Invoke Meta Llama
aws bedrock-runtime invoke-model \
  --model-id meta.llama3-70b-instruct-v1:0 \
  --content-type application/json \
  --accept application/json \
  --body '{
    "prompt": "<|begin_of_text|><|start_header_id|>user<|end_header_id|>\nWhat is serverless computing?<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n",
    "max_gen_len": 512,
    "temperature": 0.7
  }' \
  /dev/stdout 2>/dev/null | jq .

# Invoke Stable Diffusion (image generation)
aws bedrock-runtime invoke-model \
  --model-id stability.stable-diffusion-xl-v1 \
  --content-type application/json \
  --accept application/json \
  --body '{
    "text_prompts": [{"text": "A sunset over mountains, digital art"}],
    "cfg_scale": 10,
    "steps": 50,
    "width": 1024,
    "height": 1024
  }' \
  output.json

# Invoke with streaming (Claude)
aws bedrock-runtime invoke-model-with-response-stream \
  --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
  --content-type application/json \
  --body '{
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Tell me a story"}]
  }' \
  /dev/stdout
```

### Create / Configure

⚠️ **Cost note:** Pricing varies dramatically by model. Claude 3 Sonnet: ~$3/M input tokens, ~$15/M output tokens. Titan Text Express: ~$0.20/$0.60. Provisioned throughput has hourly costs. Check current pricing.

```bash
# Request model access (must be done in console — CLI can only check status)
# Navigate to: Bedrock Console → Model Access → Manage model access

# Enable invocation logging
aws bedrock put-model-invocation-logging-configuration \
  --logging-config '{
    "cloudWatchConfig": {
      "logGroupName": "/aws/bedrock/invocations",
      "roleArn": "<logging-role-arn>",
      "largeDataDeliveryS3Config": {
        "bucketName": "<bucket-name>",
        "keyPrefix": "bedrock-logs/"
      }
    },
    "s3Config": {
      "bucketName": "<bucket-name>",
      "keyPrefix": "bedrock-logs/"
    }
  }'

# Create a guardrail
aws bedrock create-guardrail \
  --name "<guardrail-name>" \
  --description "Content filtering guardrail" \
  --blocked-input-messaging "I cannot process this request." \
  --blocked-outputs-messaging "I cannot provide this response." \
  --content-policy-config '{
    "filtersConfig": [
      {"type": "SEXUAL", "inputStrength": "HIGH", "outputStrength": "HIGH"},
      {"type": "HATE", "inputStrength": "HIGH", "outputStrength": "HIGH"},
      {"type": "VIOLENCE", "inputStrength": "HIGH", "outputStrength": "HIGH"},
      {"type": "INSULTS", "inputStrength": "HIGH", "outputStrength": "HIGH"}
    ]
  }'

# Create a knowledge base
aws bedrock-agent create-knowledge-base \
  --name "<kb-name>" \
  --role-arn "<kb-role-arn>" \
  --knowledge-base-configuration '{
    "type": "VECTOR",
    "vectorKnowledgeBaseConfiguration": {
      "embeddingModelArn": "arn:aws:bedrock:<region>::foundation-model/amazon.titan-embed-text-v1"
    }
  }' \
  --storage-configuration '{
    "type": "OPENSEARCH_SERVERLESS",
    "opensearchServerlessConfiguration": {
      "collectionArn": "<collection-arn>",
      "vectorIndexName": "<index-name>",
      "fieldMapping": {
        "vectorField": "vector",
        "textField": "text",
        "metadataField": "metadata"
      }
    }
  }'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a guardrail
aws bedrock delete-guardrail --guardrail-identifier <guardrail-id>

# Delete a knowledge base
aws bedrock-agent delete-knowledge-base --knowledge-base-id <kb-id>

# Delete a custom model
aws bedrock delete-custom-model --model-identifier <model-name>

# Delete provisioned throughput
aws bedrock delete-provisioned-model-throughput \
  --provisioned-model-id <provisioned-model-id>
```

## Safety Rules

1. **NEVER** expose or log AWS credentials, access keys, or secret keys.
2. **NEVER** delete provisioned throughput without confirming — it may be serving production traffic.
3. **ALWAYS** warn about per-token/per-image costs before invoking models.
4. **ALWAYS** recommend guardrails for production deployments.
5. **WARN** that model access requests may take time to be approved.
6. **WARN** about data privacy — input/output may be logged depending on configuration.

## Best Practices

- Use guardrails to filter harmful content in production applications.
- Enable invocation logging for audit trails and debugging.
- Use provisioned throughput for consistent latency in production.
- Prefer Converse API for multi-model compatibility (unified request format).
- Test with on-demand pricing before committing to provisioned throughput.

## Common Patterns

### Pattern: Compare Model Responses

```bash
PROMPT='{"messages": [{"role": "user", "content": "Explain quantum computing in one paragraph."}]}'

# Claude
aws bedrock-runtime invoke-model \
  --model-id anthropic.claude-3-haiku-20240307-v1:0 \
  --body "{\"anthropic_version\": \"bedrock-2023-05-31\", \"max_tokens\": 256, $PROMPT}" \
  /dev/stdout 2>/dev/null | jq -r '.content[0].text'

# Titan
aws bedrock-runtime invoke-model \
  --model-id amazon.titan-text-express-v1 \
  --body '{"inputText": "Explain quantum computing in one paragraph.", "textGenerationConfig": {"maxTokenCount": 256}}' \
  /dev/stdout 2>/dev/null | jq -r '.results[0].outputText'
```

### Pattern: Check Model Access Status

```bash
aws bedrock list-foundation-models \
  --query 'modelSummaries[?providerName==`Anthropic`].{Model:modelId,Status:modelLifecycle.status}' \
  --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `AccessDeniedException` | Model access not granted | Request access in Bedrock console; wait for approval |
| `ValidationException` | Invalid request body format | Check model-specific request format; each provider differs |
| `ThrottlingException` | Rate limit exceeded | Reduce request rate or use provisioned throughput |
| `ModelNotReadyException` | Model is still loading | Wait and retry; first request may take longer |
| `ServiceUnavailableException` | Region capacity issue | Try a different region or wait |
| Empty response | Output length too short | Increase `max_tokens` / `maxTokenCount` |
