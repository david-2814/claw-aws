---
name: sagemaker
description: Manage Amazon SageMaker notebooks, training jobs, models, endpoints, and pipelines via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "requires": { "bins": ["aws"] },
      },
  }
---

# Amazon SageMaker

Use this skill for machine learning operations: managing notebook instances, training jobs, model hosting, batch transforms, endpoints, and ML pipelines.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `sagemaker:*` for full access, or scoped policies
- SageMaker execution role with access to S3, ECR, and other needed services

## Common Operations

### List and Inspect (Read-Only)

```bash
# List notebook instances
aws sagemaker list-notebook-instances \
  --query 'NotebookInstances[*].[NotebookInstanceName,InstanceType,NotebookInstanceStatus]' --output table

# Describe a notebook instance
aws sagemaker describe-notebook-instance --notebook-instance-name <name>

# List training jobs
aws sagemaker list-training-jobs --sort-by CreationTime --sort-order Descending \
  --query 'TrainingJobSummaries[*].[TrainingJobName,TrainingJobStatus,CreationTime]' --output table

# Describe a training job
aws sagemaker describe-training-job --training-job-name <job-name>

# List models
aws sagemaker list-models \
  --query 'Models[*].[ModelName,CreationTime]' --output table

# List endpoints
aws sagemaker list-endpoints \
  --query 'Endpoints[*].[EndpointName,EndpointStatus,CreationTime]' --output table

# Describe an endpoint
aws sagemaker describe-endpoint --endpoint-name <endpoint-name>

# List endpoint configs
aws sagemaker list-endpoint-configs \
  --query 'EndpointConfigs[*].[EndpointConfigName,CreationTime]' --output table

# List processing jobs
aws sagemaker list-processing-jobs --sort-by CreationTime --sort-order Descending \
  --query 'ProcessingJobSummaries[*].[ProcessingJobName,ProcessingJobStatus]' --output table

# List pipelines
aws sagemaker list-pipelines \
  --query 'PipelineSummaries[*].[PipelineName,PipelineStatus]' --output table

# List pipeline executions
aws sagemaker list-pipeline-executions --pipeline-name <pipeline-name> \
  --query 'PipelineExecutionSummaries[*].[PipelineExecutionArn,PipelineExecutionStatus,StartTime]' --output table

# List experiments
aws sagemaker list-experiments \
  --query 'ExperimentSummaries[*].[ExperimentName,CreationTime]' --output table

# List model packages
aws sagemaker list-model-packages --output table

# List transform jobs
aws sagemaker list-transform-jobs --sort-by CreationTime --sort-order Descending \
  --query 'TransformJobSummaries[*].[TransformJobName,TransformJobStatus]' --output table
```

### Notebook Instances

⚠️ **Cost note:** Notebook instances charge per hour while running. ml.t3.medium: ~$0.05/hr. ml.p3.2xlarge (GPU): ~$3.83/hr. Stop when not in use!

```bash
# Create a notebook instance
aws sagemaker create-notebook-instance \
  --notebook-instance-name <name> \
  --instance-type ml.t3.medium \
  --role-arn <sagemaker-role-arn> \
  --volume-size-in-gb 20

# Start a notebook instance
aws sagemaker start-notebook-instance --notebook-instance-name <name>

# Stop a notebook instance
aws sagemaker stop-notebook-instance --notebook-instance-name <name>

# Get presigned URL to access notebook
aws sagemaker create-presigned-notebook-instance-url \
  --notebook-instance-name <name> \
  --query 'AuthorizedUrl' --output text
```

### Training Jobs

```bash
# Create a training job
aws sagemaker create-training-job \
  --training-job-name <job-name> \
  --algorithm-specification '{
    "TrainingImage": "<ecr-image-uri>",
    "TrainingInputMode": "File"
  }' \
  --role-arn <sagemaker-role-arn> \
  --input-data-config '[{
    "ChannelName": "train",
    "DataSource": {"S3DataSource": {"S3DataType": "S3Prefix", "S3Uri": "s3://<bucket>/train/"}}
  }]' \
  --output-data-config '{"S3OutputPath": "s3://<bucket>/output/"}' \
  --resource-config '{
    "InstanceType": "ml.m5.xlarge",
    "InstanceCount": 1,
    "VolumeSizeInGB": 50
  }' \
  --stopping-condition '{"MaxRuntimeInSeconds": 3600}' \
  --hyper-parameters '{"epochs": "10", "batch_size": "32"}'

# Stop a training job
aws sagemaker stop-training-job --training-job-name <job-name>

# Get training job logs
aws logs get-log-events \
  --log-group-name /aws/sagemaker/TrainingJobs \
  --log-stream-name <job-name>/algo-1 \
  --query 'events[*].message' --output text
```

### Models and Endpoints

```bash
# Create a model
aws sagemaker create-model \
  --model-name <model-name> \
  --primary-container '{
    "Image": "<ecr-image-uri>",
    "ModelDataUrl": "s3://<bucket>/output/<job-name>/output/model.tar.gz"
  }' \
  --execution-role-arn <sagemaker-role-arn>

# Create an endpoint config
aws sagemaker create-endpoint-config \
  --endpoint-config-name <config-name> \
  --production-variants '[{
    "VariantName": "primary",
    "ModelName": "<model-name>",
    "InstanceType": "ml.m5.large",
    "InitialInstanceCount": 1,
    "InitialVariantWeight": 1.0
  }]'

# Create an endpoint
aws sagemaker create-endpoint \
  --endpoint-name <endpoint-name> \
  --endpoint-config-name <config-name>

# Invoke an endpoint (for testing)
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name <endpoint-name> \
  --content-type application/json \
  --body '{"instances": [{"features": [1.0, 2.0, 3.0]}]}' \
  /dev/stdout

# Update an endpoint (blue/green)
aws sagemaker update-endpoint \
  --endpoint-name <endpoint-name> \
  --endpoint-config-name <new-config-name>
```

### Batch Transform

```bash
# Create a transform job
aws sagemaker create-transform-job \
  --transform-job-name <job-name> \
  --model-name <model-name> \
  --transform-input '{
    "DataSource": {"S3DataSource": {"S3DataType": "S3Prefix", "S3Uri": "s3://<bucket>/input/"}},
    "ContentType": "text/csv"
  }' \
  --transform-output '{"S3OutputPath": "s3://<bucket>/predictions/"}' \
  --transform-resources '{"InstanceType": "ml.m5.xlarge", "InstanceCount": 1}'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete an endpoint (stops billing)
aws sagemaker delete-endpoint --endpoint-name <endpoint-name>

# Delete an endpoint config
aws sagemaker delete-endpoint-config --endpoint-config-name <config-name>

# Delete a model
aws sagemaker delete-model --model-name <model-name>

# Delete a notebook instance (must be stopped first)
aws sagemaker delete-notebook-instance --notebook-instance-name <name>
```

## Safety Rules

1. **NEVER** delete endpoints or models without explicit user confirmation.
2. **NEVER** expose or log AWS credentials or model data.
3. **ALWAYS** stop notebook instances when not in use — they charge per hour.
4. **ALWAYS** set `MaxRuntimeInSeconds` on training jobs to prevent runaway costs.
5. **WARN** about GPU instance costs before creating training jobs or endpoints.
6. **WARN** that endpoints charge continuously until deleted.

## Best Practices

- Always set stopping conditions on training jobs.
- Use spot instances for training to save 60-90%.
- Stop notebook instances when not in use.
- Use SageMaker Pipelines for reproducible ML workflows.
- Monitor endpoint invocation metrics to right-size instances.

## Common Patterns

### Pattern: End-to-End ML Workflow

```bash
# 1. Train
aws sagemaker create-training-job --training-job-name my-model-v1 ...

# 2. Wait for completion
aws sagemaker wait training-job-completed-or-stopped --training-job-name my-model-v1

# 3. Create model from trained artifacts
MODEL_DATA=$(aws sagemaker describe-training-job --training-job-name my-model-v1 \
  --query 'ModelArtifacts.S3ModelArtifacts' --output text)
aws sagemaker create-model --model-name my-model-v1 \
  --primary-container "{\"Image\":\"<image>\",\"ModelDataUrl\":\"$MODEL_DATA\"}" \
  --execution-role-arn <role>

# 4. Deploy
aws sagemaker create-endpoint-config --endpoint-config-name my-config-v1 ...
aws sagemaker create-endpoint --endpoint-name my-endpoint --endpoint-config-name my-config-v1
```

### Pattern: Check Running Costs

```bash
echo "=== Running Notebooks ==="
aws sagemaker list-notebook-instances --status-equals InService \
  --query 'NotebookInstances[*].[NotebookInstanceName,InstanceType]' --output table

echo "=== Active Endpoints ==="
aws sagemaker list-endpoints --status-equals InService \
  --query 'Endpoints[*].[EndpointName]' --output table
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFound` | Resource doesn't exist | Verify name with list commands |
| Training job failed | Algorithm error or resource issue | Check CloudWatch logs for the training job |
| Endpoint creation stuck | Instance provisioning issue | Check `describe-endpoint` for failure reason |
| `ModelError` on invoke | Model loading or inference error | Check endpoint CloudWatch logs |
| `ThrottlingException` | API rate limit | Reduce request rate; use exponential backoff |
| High endpoint latency | Instance undersized | Scale up instance type or add auto-scaling |
