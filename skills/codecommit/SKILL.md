---
name: codecommit
description: Manage AWS CodeCommit repositories, branches, pull requests, and merge operations via AWS CLI.
metadata:
  {
    "openclaw":
      {
        "emoji": "📦",
        "requires": { "bins": ["aws"] },
      },
  }
---

# AWS CodeCommit

Use this skill for source code repository operations: creating and managing repositories, working with branches and tags, managing pull requests, reviewing code, and configuring repository triggers.

> **Note:** AWS CodeCommit stopped accepting new customers as of July 2024. This skill is for managing existing repositories.

## Prerequisites

- AWS CLI v2 configured with valid credentials
- IAM permissions: `codecommit:*` for full access, or scoped policies
- Git credential helper configured: `git config --global credential.helper '!aws codecommit credential-helper $@'`

## Common Operations

### List and Inspect (Read-Only)

```bash
# List all repositories
aws codecommit list-repositories --output table

# Get repository details
aws codecommit get-repository --repository-name <repo-name>

# List branches
aws codecommit list-branches --repository-name <repo-name> --output table

# Get branch details
aws codecommit get-branch --repository-name <repo-name> --branch-name <branch>

# Get a file
aws codecommit get-file \
  --repository-name <repo-name> \
  --file-path <path/to/file>

# Get folder contents
aws codecommit get-folder \
  --repository-name <repo-name> \
  --folder-path /

# Get commit details
aws codecommit get-commit \
  --repository-name <repo-name> \
  --commit-id <commit-id>

# Get differences between commits
aws codecommit get-differences \
  --repository-name <repo-name> \
  --before-commit-specifier <old-commit> \
  --after-commit-specifier <new-commit>

# List tags
aws codecommit list-tags-for-resource \
  --resource-arn arn:aws:codecommit:<region>:<account>:<repo-name>

# List pull requests
aws codecommit list-pull-requests \
  --repository-name <repo-name> \
  --pull-request-status OPEN \
  --output table

# Get pull request details
aws codecommit get-pull-request --pull-request-id <pr-id>

# List approval rules for a PR
aws codecommit get-pull-request-approval-states --pull-request-id <pr-id> --revision-id <rev-id>

# List repository triggers
aws codecommit get-repository-triggers --repository-name <repo-name>
```

### Create and Update

⚠️ **Cost note:** CodeCommit free tier: 5 active users/month with 50 GB storage and 10,000 Git requests. Beyond that: $1/active user/month.

```bash
# Create a repository
aws codecommit create-repository \
  --repository-name <repo-name> \
  --repository-description "My repository"

# Create a branch
aws codecommit create-branch \
  --repository-name <repo-name> \
  --branch-name <branch-name> \
  --commit-id <parent-commit-id>

# Create a pull request
aws codecommit create-pull-request \
  --title "Feature: add login page" \
  --description "Implements user authentication" \
  --targets "repositoryName=<repo-name>,sourceReference=feature-branch,destinationReference=main"

# Add a comment to a PR
aws codecommit post-comment-for-pull-request \
  --pull-request-id <pr-id> \
  --repository-name <repo-name> \
  --before-commit-id <before-commit> \
  --after-commit-id <after-commit> \
  --content "Looks good to me!"

# Approve a pull request
aws codecommit update-pull-request-approval-state \
  --pull-request-id <pr-id> \
  --revision-id <rev-id> \
  --approval-state APPROVE

# Merge a pull request (fast-forward)
aws codecommit merge-pull-request-by-fast-forward \
  --pull-request-id <pr-id> \
  --repository-name <repo-name>

# Merge (squash)
aws codecommit merge-pull-request-by-squash \
  --pull-request-id <pr-id> \
  --repository-name <repo-name>

# Put a file directly (without git client)
aws codecommit put-file \
  --repository-name <repo-name> \
  --branch-name main \
  --file-content fileb://local-file.txt \
  --file-path path/in/repo.txt \
  --commit-message "Add file" \
  --name "Author Name" \
  --email "author@example.com"

# Set up repository triggers (e.g., SNS notification)
aws codecommit put-repository-triggers \
  --repository-name <repo-name> \
  --triggers '[{
    "name": "push-notify",
    "destinationArn": "<sns-topic-arn>",
    "events": ["all"],
    "branches": ["main"]
  }]'
```

### Delete / Destructive

🛑 **DESTRUCTIVE — Always confirm with the user before executing any of these commands.**

```bash
# Delete a repository (IRREVERSIBLE)
aws codecommit delete-repository --repository-name <repo-name>

# Delete a branch
aws codecommit delete-branch \
  --repository-name <repo-name> \
  --branch-name <branch-name>

# Close a pull request (without merging)
aws codecommit update-pull-request-status \
  --pull-request-id <pr-id> \
  --pull-request-status CLOSED
```

## Safety Rules

1. **NEVER** delete a repository without explicit user confirmation — all code and history is lost.
2. **NEVER** expose or log AWS credentials, access keys, or secret keys.
3. **ALWAYS** confirm the repository and branch before merge or delete operations.
4. **WARN** that CodeCommit is no longer accepting new customers — consider migration.
5. **WARN** before force-merging without review approvals.

## Best Practices

- Use branch protection with approval rule templates for production branches.
- Set up triggers for CI/CD notifications on push events.
- Use pull requests for all changes to main/production branches.
- Consider migrating to GitHub, GitLab, or Bitbucket since CodeCommit is in maintenance mode.

## Common Patterns

### Pattern: Clone via HTTPS with Credential Helper

```bash
# Configure git credential helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Clone
git clone https://git-codecommit.<region>.amazonaws.com/v1/repos/<repo-name>
```

### Pattern: Review Open Pull Requests

```bash
# List open PRs
aws codecommit list-pull-requests \
  --repository-name <repo-name> \
  --pull-request-status OPEN \
  --query 'pullRequestIds' --output text | tr '\t' '\n' | while read pr_id; do
  aws codecommit get-pull-request --pull-request-id $pr_id \
    --query 'pullRequest.[pullRequestId,title,pullRequestStatus,creationDate]' \
    --output text
done
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `RepositoryDoesNotExistException` | Repo doesn't exist | Verify name with `list-repositories` |
| `BranchDoesNotExistException` | Branch not found | Check with `list-branches` |
| `403` on git clone | Credential helper not configured | Set up git credential helper for CodeCommit |
| `MergeOptionRequiredException` | Merge conflicts exist | Use `merge-by-three-way` with conflict resolution |
| `PullRequestApprovalRulesNotSatisfied` | Missing required approvals | Get required approvals before merging |
