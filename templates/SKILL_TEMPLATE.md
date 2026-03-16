---
name: <service-name>
description: <One-line description of what this skill enables. Start with a verb. Example: "Manage Amazon S3 buckets, objects, and lifecycle policies via AWS CLI.">
metadata:
  {
    "openclaw":
      {
        "emoji": "<emoji>",
        "requires": { "bins": ["aws"] },
      },
  }
---

# <Service Display Name>

<Brief paragraph: what this service is, when to use this skill, and what it covers.>

## Prerequisites

- AWS CLI v2 configured with valid credentials
- Appropriate IAM permissions for <service> operations
- <Any service-specific prerequisites>

## Common Operations

### List / Describe (Read-Only)

<Document the most common read operations. These should be the default — safe to run anytime.>

```
aws <service> <list-command> --region $AWS_DEFAULT_REGION
```

### Create / Update

<Document create and update operations. Flag cost implications.>

⚠️ **Cost note:** <Describe any cost implications if applicable.>

### Delete / Destructive

<Document delete operations with explicit safety warnings.>

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```
aws <service> <delete-command> --<resource-id> <id>
```

## Safety Rules

1. **NEVER** execute delete/terminate/remove commands without explicit user confirmation.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** include `--region` in commands or confirm the active region with the user.
4. **ALWAYS** warn about cost implications before creating resources.
5. **PREFER** `--dry-run` flags where available before executing write operations.

## Best Practices

<List 3-5 AWS Well-Architected best practices relevant to this service. These guide the agent's suggestions.>

- <Practice 1>
- <Practice 2>
- <Practice 3>

## Common Patterns

<Show 2-3 real-world workflows that chain multiple commands together.>

### Pattern: <Name>

<Description of when you'd use this pattern.>

```bash
# Step 1: ...
aws <service> ...

# Step 2: ...
aws <service> ...
```

## Troubleshooting

<Common errors and how to resolve them.>

| Error | Cause | Fix |
|-------|-------|-----|
| `AccessDenied` | Missing IAM permissions | Check IAM policy for `<service>:<action>` |
| <error> | <cause> | <fix> |
