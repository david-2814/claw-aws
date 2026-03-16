# Architecture

## How claw-aws Works

claw-aws is a **distribution layer**, not a fork. It installs as a set of skill directories that OpenClaw loads alongside its bundled and managed skills.

```
┌──────────────────────────────────────────────────────┐
│                    OpenClaw Agent                     │
│                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │   Bundled    │  │   Managed    │  │  Workspace  │ │
│  │   Skills     │  │   Skills     │  │   Skills    │ │
│  │  (OpenClaw)  │  │ (~/.openclaw │  │  (project)  │ │
│  │             │  │   /skills)   │  │             │ │
│  └─────────────┘  └──────┬───────┘  └─────────────┘ │
│                          │                           │
│                   ┌──────┴───────┐                   │
│                   │  claw-aws    │                   │
│                   │  skills      │                   │
│                   │  (symlinked) │                   │
│                   └──────────────┘                   │
│                                                      │
│  Precedence: Workspace > Managed > Bundled           │
└──────────────────────────────────────────────────────┘
```

## Installation Flow

1. **Clone** the claw-aws repository to `~/.claw-aws`
2. **Symlink** each skill directory into `~/.openclaw/skills/` with an `aws-` prefix
3. **Copy** the AWS SOUL.md into `~/.openclaw/soul/`
4. **Restart** OpenClaw to pick up the new skills

The symlink approach means:
- `git pull` in the claw-aws directory updates all skills
- No files are copied, so there's a single source of truth
- Removing the symlinks cleanly uninstalls everything

## Skill Loading

OpenClaw loads skills at session start. Each skill's `SKILL.md` frontmatter declares:
- **name**: Used for identification and deduplication
- **description**: Used by the agent to decide when to activate the skill
- **metadata.openclaw.requires.bins**: Binary dependencies (always `["aws"]` for us)

When a user's message matches a skill's description, OpenClaw injects that skill's content into the agent's context. The agent then follows the instructions in the SKILL.md to execute AWS CLI commands.

## Naming Convention

Skills are installed as `aws-<service>` (e.g., `aws-s3`, `aws-ec2`) to:
- Avoid conflicts with other OpenClaw skills
- Make it clear which skills come from claw-aws
- Group all AWS skills together alphabetically

## Update Strategy

Since claw-aws is not a fork:
- OpenClaw upstream updates are independent — users update OpenClaw normally
- claw-aws updates are a `git pull` — skills update without touching OpenClaw
- No merge conflicts, no rebasing, no version pinning
