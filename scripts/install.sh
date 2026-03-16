#!/usr/bin/env bash
set -euo pipefail

# claw-aws installer
# Installs the AWS skills pack into your OpenClaw workspace.

REPO_URL="https://github.com/claw-aws/claw-aws.git"
INSTALL_DIR="${CLAW_AWS_DIR:-$HOME/.claw-aws}"
OPENCLAW_SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-$HOME/.openclaw/skills}"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
LOCAL_MODE=false

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()  { echo -e "${GREEN}[claw-aws]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[claw-aws]${RESET} $*"; }
error() { echo -e "${RED}[claw-aws]${RESET} $*" >&2; }

usage() {
  cat <<EOF
${BOLD}claw-aws installer${RESET}

Usage: install.sh [OPTIONS]

Options:
  --local       Use the current directory as the source (for development)
  --dir DIR     Install to DIR instead of ~/.claw-aws
  --help        Show this message

Environment variables:
  CLAW_AWS_DIR         Override install directory (default: ~/.claw-aws)
  OPENCLAW_SKILLS_DIR  Override OpenClaw skills directory (default: ~/.openclaw/skills)
EOF
  exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --local)  LOCAL_MODE=true; shift ;;
    --dir)    INSTALL_DIR="$2"; shift 2 ;;
    --help)   usage ;;
    *)        error "Unknown option: $1"; usage ;;
  esac
done

echo ""
echo -e "${BOLD}🦞 claw-aws — AWS Toolkit for OpenClaw${RESET}"
echo ""

# --- Preflight checks ---

# Check for OpenClaw
if ! command -v openclaw &>/dev/null; then
  warn "OpenClaw CLI not found in PATH."
  warn "Install it first: npm install -g openclaw@latest"
  warn "Continuing anyway — skills will be ready when OpenClaw is installed."
  echo ""
fi

# Check for AWS CLI
if ! command -v aws &>/dev/null; then
  warn "AWS CLI not found in PATH."
  warn "Install it: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  warn "Skills will load but won't function without the AWS CLI."
  echo ""
fi

# Check for configured credentials
if command -v aws &>/dev/null; then
  if aws sts get-caller-identity &>/dev/null 2>&1; then
    ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")
    info "AWS credentials found (account: $ACCOUNT)"
  else
    warn "AWS CLI is installed but credentials are not configured."
    warn "Run 'aws configure' or set up SSO before using claw-aws skills."
  fi
fi

# --- Install ---

if [ "$LOCAL_MODE" = true ]; then
  # Development mode: use current directory
  INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  info "Local mode: using $INSTALL_DIR"
else
  # Clone or update
  if [ -d "$INSTALL_DIR/.git" ]; then
    info "Updating existing installation at $INSTALL_DIR"
    cd "$INSTALL_DIR" && git pull --quiet
  else
    info "Cloning claw-aws to $INSTALL_DIR"
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
  fi
fi

# --- Link skills ---

info "Linking AWS skills to OpenClaw..."
mkdir -p "$OPENCLAW_SKILLS_DIR"

SKILL_COUNT=0
for skill_dir in "$INSTALL_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  # Only link if SKILL.md exists (skip empty placeholder dirs)
  if [ -f "$skill_dir/SKILL.md" ]; then
    target="$OPENCLAW_SKILLS_DIR/aws-$skill_name"
    # Remove existing link/dir if present
    [ -L "$target" ] && rm "$target"
    [ -d "$target" ] && rm -rf "$target"
    ln -sf "$skill_dir" "$target"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  fi
done

info "Linked $SKILL_COUNT AWS skills."

# --- Install SOUL.md ---

if [ -f "$INSTALL_DIR/soul/AWS_SOUL.md" ]; then
  SOUL_TARGET="$HOME/.openclaw/soul"
  mkdir -p "$SOUL_TARGET"
  cp "$INSTALL_DIR/soul/AWS_SOUL.md" "$SOUL_TARGET/AWS_SOUL.md"
  info "Installed AWS SOUL.md to $SOUL_TARGET/"
fi

# --- Done ---

echo ""
echo -e "${BOLD}${GREEN}✓ claw-aws installed successfully!${RESET}"
echo ""
echo "  Skills installed to: $OPENCLAW_SKILLS_DIR"
echo "  Source directory:     $INSTALL_DIR"
echo ""
echo "  Next steps:"
echo "    1. Restart your OpenClaw session"
echo "    2. Try: \"List my S3 buckets\" or \"Show running EC2 instances\""
echo ""
echo "  To update later:"
if [ "$LOCAL_MODE" = true ]; then
  echo "    cd $INSTALL_DIR && git pull"
else
  echo "    cd $INSTALL_DIR && git pull && ./scripts/install.sh --local"
fi
echo ""
