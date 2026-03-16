#!/usr/bin/env bash
set -euo pipefail

# Validate all claw-aws skills for structural correctness.

BOLD="\033[1m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd)"
ERRORS=0
WARNINGS=0
CHECKED=0

pass() { echo -e "  ${GREEN}✓${RESET} $*"; }
fail() { echo -e "  ${RED}✗${RESET} $*"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "  ${YELLOW}!${RESET} $*"; WARNINGS=$((WARNINGS + 1)); }

echo -e "${BOLD}Validating claw-aws skills...${RESET}"
echo ""

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  # Skip empty placeholder directories
  if [ ! -f "$skill_file" ]; then
    warn "$skill_name: No SKILL.md found (placeholder directory)"
    continue
  fi

  CHECKED=$((CHECKED + 1))
  echo -e "${BOLD}$skill_name${RESET}"

  # Check frontmatter exists
  if head -1 "$skill_file" | grep -q '^---$'; then
    pass "Has YAML frontmatter"
  else
    fail "Missing YAML frontmatter"
  fi

  # Check required frontmatter fields
  if grep -q '^name:' "$skill_file"; then
    pass "Has 'name' field"
  else
    fail "Missing 'name' field in frontmatter"
  fi

  if grep -q '^description:' "$skill_file"; then
    pass "Has 'description' field"
  else
    fail "Missing 'description' field in frontmatter"
  fi

  # Check for required sections
  if grep -q '## Safety Rules' "$skill_file"; then
    pass "Has Safety Rules section"
  else
    fail "Missing '## Safety Rules' section"
  fi

  if grep -q '## Best Practices' "$skill_file"; then
    pass "Has Best Practices section"
  else
    fail "Missing '## Best Practices' section"
  fi

  if grep -q '## Troubleshooting' "$skill_file"; then
    pass "Has Troubleshooting section"
  else
    fail "Missing '## Troubleshooting' section"
  fi

  if grep -q '## Common Patterns' "$skill_file"; then
    pass "Has Common Patterns section"
  else
    warn "Missing '## Common Patterns' section (recommended)"
  fi

  # Check for destructive operation warnings
  if grep -q 'delete\|terminate\|remove\|destroy' "$skill_file"; then
    if grep -q '🛑' "$skill_file"; then
      pass "Has destructive operation warning (🛑)"
    else
      fail "Has destructive commands but missing 🛑 warning"
    fi
  fi

  # Check for credential safety
  if grep -qi 'AKIA\|secret.*key\|password' "$skill_file" | grep -qv 'NEVER\|never\|placeholder'; then
    fail "Possible credential leak in skill content"
  else
    pass "No credential leaks detected"
  fi

  echo ""
done

# Summary
echo -e "${BOLD}Summary${RESET}"
echo "  Skills checked: $CHECKED"
echo -e "  Errors:         ${RED}$ERRORS${RESET}"
echo -e "  Warnings:       ${YELLOW}$WARNINGS${RESET}"
echo ""

if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}Validation failed with $ERRORS error(s).${RESET}"
  exit 1
else
  echo -e "${GREEN}All checks passed.${RESET}"
fi
