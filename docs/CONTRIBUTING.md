# Contributing to claw-aws

Thanks for your interest in contributing! Every AWS service skill is independent and self-contained, so you can contribute a skill for a service you know well without needing to understand the rest of the project.

## Ways to Contribute

### 1. Add a New Skill (Most Needed)

Check [open issues labeled `new skill`](../../issues?q=is%3Aissue+label%3A%22new+skill%22) for requested services, or propose one.

**Quick steps:**

1. Fork this repo
2. Copy `templates/SKILL_TEMPLATE.md` to `skills/<service-name>/SKILL.md`
3. Fill it in following `docs/SKILL_GUIDE.md`
4. Test your CLI commands against a real AWS account
5. Open a PR

### 2. Improve an Existing Skill

Found a missing command, outdated pattern, or better way to do something? PRs for improvements to existing skills are very welcome.

### 3. Report Issues

Found a bug, a CLI command that doesn't work, or a security concern? Open an issue.

### 4. Documentation

Typo fixes, better examples, additional troubleshooting entries — all appreciated.

## Skill Quality Checklist

Before submitting a skill PR, check that your SKILL.md:

- [ ] Has correct YAML frontmatter (name, description, metadata)
- [ ] Requires `"bins": ["aws"]` in metadata
- [ ] Starts with read-only operations (list, describe)
- [ ] Marks destructive operations with the 🛑 warning block
- [ ] Includes the standard Safety Rules section
- [ ] Includes a Best Practices section with Well-Architected guidance
- [ ] Includes a Troubleshooting table with common errors
- [ ] Includes at least 2 Common Patterns showing real workflows
- [ ] Mentions cost implications for create/launch operations
- [ ] Does NOT contain any hardcoded account IDs, ARNs, or credentials
- [ ] Uses placeholder values like `<bucket-name>`, `<instance-id>`, etc.
- [ ] Has been tested with real `aws` CLI commands

## Code Style

- Use `<placeholder>` for user-supplied values (not `$VARIABLE` unless it's a scripted pattern)
- Include `--output table` for human-readable list commands
- Include `--query` JMESPath filters to show relevant columns
- Use `--output text` when piping to other commands
- Include comments explaining non-obvious flags
- Keep the Safety Rules section consistent with other skills (copy from template)

## Naming Conventions

- Skill directory name = AWS service short name, lowercase, hyphenated if needed
  - `s3`, `ec2`, `lambda`, `iam`, `cloudformation`, `step-functions`, `secrets-manager`
- Symlinks in OpenClaw are prefixed with `aws-`: `aws-s3`, `aws-ec2`, etc. (the installer handles this)

## Pull Request Process

1. Create a branch from `main`: `git checkout -b add-skill-<service>`
2. Make your changes
3. Run `./scripts/validate.sh` to check SKILL.md formatting
4. Open a PR with a clear description of what the skill covers
5. A maintainer will review within a few days

## Community Standards

- Be respectful and constructive in issues and reviews.
- When reviewing PRs, focus on accuracy and safety of CLI patterns.
- If you're unsure about an IAM permission or a destructive command, ask — better safe than sorry.

## Questions?

Open a Discussion or ask in the project's Discord channel. We're happy to help first-time contributors.
