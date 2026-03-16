# 🦞 claw-aws — The AWS Toolkit for OpenClaw

**A curated, battle-tested collection of AWS skills for [OpenClaw](https://github.com/openclaw/openclaw).**

Stop configuring scattered AWS skills one by one. `claw-aws` gives you a complete AWS developer experience out of the box — from EC2 and S3 to CDK deployments and cost analysis.

> **This is not a fork.** It's a distribution layer that sits on top of vanilla OpenClaw. You get all upstream updates automatically while keeping a purpose-built AWS toolkit.

---

## Why?

OpenClaw is incredible, but the AWS experience today looks like this:

1. Install OpenClaw
2. Search ClawHub for an S3 skill... install it
3. Search for an EC2 skill... install it
4. Repeat 20 more times for Lambda, IAM, CloudFormation, ECS, RDS...
5. Discover they have inconsistent conventions and gaps
6. Write your own skills to fill the holes

**claw-aws** replaces all of that with one command.

## Quick Start

```bash
# Option 1: Install into an existing OpenClaw workspace
curl -fsSL https://raw.githubusercontent.com/claw-aws/claw-aws/main/scripts/install.sh | bash

# Option 2: Clone and link manually
git clone https://github.com/claw-aws/claw-aws.git ~/.claw-aws
cd ~/.claw-aws && ./scripts/install.sh --local
```

After installation, restart your OpenClaw session. All AWS skills are immediately available.

## What's Included

### Skills (47 services)

| Category | Skills | Description |
|----------|--------|-------------|
| **Compute** | `ec2`, `lambda`, `ecs`, `eks`, `lightsail`, `autoscaling` | Instances, serverless, containers, Kubernetes, simplified VPS, auto scaling |
| **Storage** | `s3` | Bucket operations, object management, lifecycle policies |
| **Networking** | `vpc`, `elb`, `cloudfront`, `route53`, `apigateway` | VPCs, load balancers, CDN, DNS, API management |
| **Database** | `rds`, `dynamodb`, `elasticache` | Relational, NoSQL, and in-memory caching |
| **IaC / Deploy** | `cloudformation`, `cdk`, `sam` | Stack management, CDK synthesis, serverless application model |
| **CI/CD** | `codepipeline`, `codebuild`, `codecommit`, `codedeploy` | Pipelines, builds, source control, deployments |
| **Messaging** | `sqs`, `sns`, `ses`, `eventbridge` | Queues, notifications, email, event buses |
| **Security** | `iam`, `kms`, `secrets-manager`, `waf`, `guardduty`, `cognito`, `acm` | Identity, encryption, secrets, firewall, threat detection, auth, certificates |
| **Observability** | `cloudwatch`, `cloudtrail`, `config` | Logs/metrics/alarms, audit trails, compliance rules |
| **Data & Analytics** | `glue`, `athena`, `kinesis` | ETL, SQL queries on S3, real-time streaming |
| **ML / AI** | `sagemaker`, `bedrock` | ML training/hosting, foundation models |
| **Management** | `organizations`, `ssm`, `cost-explorer` | Multi-account, fleet management, cost analysis |
| **Developer Tools** | `ecr`, `appsync`, `step-functions` | Container registry, GraphQL APIs, workflow orchestration |

### Configuration

- **AWS SOUL.md** — Agent personality tuned for AWS best practices, cost awareness, and Well-Architected principles
- **Safety guards** — Destructive operations (delete, terminate) always require explicit confirmation
- **Region awareness** — Skills respect `AWS_DEFAULT_REGION` and prompt when region matters

## Requirements

- [OpenClaw](https://github.com/openclaw/openclaw) (latest)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and configured
- Valid AWS credentials (via `aws configure`, IAM role, SSO, etc.)

## Project Structure

```
claw-aws/
├── skills/                  # One directory per AWS service (47 services)
│   ├── s3/
│   │   └── SKILL.md
│   ├── ec2/
│   │   └── SKILL.md
│   ├── lambda/
│   │   └── SKILL.md
│   └── ...                  # See full list in Skills table above
├── templates/               # Skill authoring template
│   └── SKILL_TEMPLATE.md
├── soul/
│   └── AWS_SOUL.md          # AWS-tuned agent personality
├── scripts/
│   ├── install.sh           # One-command installer
│   └── validate.sh          # CI: validate all skills
├── docs/
│   ├── CONTRIBUTING.md
│   ├── SKILL_GUIDE.md       # How to write a new skill
│   └── ARCHITECTURE.md
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── new-skill.md
│   │   └── bug-report.md
│   └── workflows/
│       └── validate.yml
└── README.md
```

## Contributing

We'd love your help! Every AWS service skill is **independent and self-contained**, so you can contribute a skill for a service you know well without understanding anything else in the repo.

**Easiest way to start:**
1. Pick an AWS service that doesn't have a skill yet
2. Copy `templates/SKILL_TEMPLATE.md`
3. Fill it in following `docs/SKILL_GUIDE.md`
4. Open a PR

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for full details.

### Wanted Skills

We're tracking requested skills in [GitHub Issues](../../issues?q=is%3Aissue+label%3A%22new+skill%22). Grab one!

Some services we'd love to cover next:
- `redshift` — Data warehouse
- `opensearch` — Search and log analytics
- `msk` — Managed Kafka
- `transfer-family` — Managed SFTP/FTPS
- `app-runner` — Simplified container hosting
- `amplify` — Full-stack web/mobile development
- `backup` — Centralized backup management
- `control-tower` — Multi-account governance
- `service-catalog` — Self-service provisioning
- `datasync` — Data transfer and replication

## Philosophy

1. **Read-only by default.** Skills should prefer read/describe/list operations. Any write/delete operation must include a confirmation step.
2. **Cost-aware.** The agent should flag when an action might incur significant cost.
3. **Region-explicit.** Always state which region an operation targets.
4. **Well-Architected.** Suggestions should follow AWS best practices — least privilege, encryption at rest, multi-AZ when appropriate.
5. **No credentials in chat.** Skills must never log, echo, or expose AWS credentials.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

Built on top of [OpenClaw](https://github.com/openclaw/openclaw) by Peter Steinberger and contributors.

This project is not affiliated with or endorsed by Amazon Web Services or the OpenClaw project.
