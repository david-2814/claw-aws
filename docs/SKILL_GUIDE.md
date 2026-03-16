# How to Write a claw-aws Skill

This guide walks you through creating a new AWS service skill from scratch.

## What Is a Skill?

A skill is a single `SKILL.md` file inside a `skills/<service>/` directory. OpenClaw reads it and uses the content as instructions for how to interact with that AWS service. There's no code to write — it's all structured Markdown with YAML frontmatter.

## Step-by-Step

### 1. Create the directory

```bash
mkdir -p skills/<service-name>
cp templates/SKILL_TEMPLATE.md skills/<service-name>/SKILL.md
```

### 2. Fill in the frontmatter

```yaml
---
name: <service-name>
description: <One line starting with a verb. This appears in the skill list.>
metadata:
  {
    "openclaw":
      {
        "emoji": "<relevant emoji>",
        "requires": { "bins": ["aws"] },
      },
  }
---
```

The `description` field is critical — OpenClaw uses it to decide when to activate the skill. Make it specific and action-oriented. Good: "Manage Amazon SQS queues, messages, and dead-letter configurations via AWS CLI." Bad: "SQS stuff."

### 3. Structure your content

Follow this order (matches the template):

1. **Service name and summary** — What the service is and when to use the skill
2. **Prerequisites** — IAM permissions, required tools
3. **Common Operations** — Organized into:
   - **List / Describe (Read-Only)** — Safe operations. Put these first.
   - **Create / Update** — With cost warnings
   - **Delete / Destructive** — With the 🛑 confirmation block
4. **Safety Rules** — Non-negotiable rules for the agent
5. **Best Practices** — Well-Architected guidance for this service
6. **Common Patterns** — 2-3 real-world multi-step workflows
7. **Troubleshooting** — Table of common errors, causes, and fixes

### 4. Writing CLI Commands

**Do:**
- Test every command against a real AWS account
- Use `--query` to filter output to relevant fields
- Use `--output table` for list operations shown to users
- Include comments explaining non-obvious flags
- Use `<placeholder>` for user-supplied values
- Include `--region` where applicable

**Don't:**
- Hardcode account IDs, ARNs, or real resource names
- Include commands that expose credentials
- Assume a default VPC or default region exists
- Use deprecated CLI options

### 5. Safety Rules

Every skill must include these baseline rules (customize as needed):

1. NEVER execute destructive commands without explicit user confirmation.
2. NEVER expose or log AWS credentials.
3. ALWAYS confirm the target region before write operations.
4. ALWAYS warn about cost implications before creating resources.

Add service-specific rules. For example, IAM skills should warn about wildcard policies. S3 skills should warn about public access.

### 6. Testing

Before submitting:

- Run every read-only command and verify the output format
- Run create commands in a test/sandbox account
- Verify that destructive commands work (then clean up)
- Check that JMESPath queries return the expected fields
- Run `./scripts/validate.sh` to check formatting

## Tips for Great Skills

- **Start with what people actually do.** Don't document every API — document the 10 most common workflows.
- **Show patterns, not just commands.** A pattern like "Find unused EBS volumes" is more useful than just `describe-volumes`.
- **Be opinionated about best practices.** If versioning should be on, say so. If a certain instance type is better value, recommend it.
- **Think about failure modes.** The troubleshooting table helps the agent recover when things go wrong.
