#!/usr/bin/env bash
# =============================================================================
# verify.sh — End-to-end verification of the AWS Agent Toolkit installation
#
# Usage:
#   chmod +x scripts/verify.sh
#   ./scripts/verify.sh
#
# What this script checks:
#   1. AWS CLI is present and reachable
#   2. Active credentials via STS
#   3. Agent Toolkit skill catalog is accessible
#   4. Amazon Bedrock foundation models are listable
#   5. Write access via a CloudWatch Logs create/describe/delete cycle
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
pass()    { echo -e "${GREEN}[PASS]${RESET}  $*"; ((PASS++)) || true; }
fail()    { echo -e "${RED}[FAIL]${RESET}  $*"; ((FAIL++)) || true; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
section() { echo ""; echo -e "${BOLD}── $* ──────────────────────────────────────${RESET}"; }

# ── Detect region from AWS config ─────────────────────────────────────────────
REGION="$(aws configure get region 2>/dev/null || echo "us-east-1")"
LOG_GROUP="/agent-toolkit/verify-$(date +%s)"

echo ""
echo -e "${BOLD}AWS Agent Toolkit — Verification Suite${RESET}"
echo -e "Region: $REGION"
echo -e "Time:   $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ── Check 1: AWS CLI ──────────────────────────────────────────────────────────
section "Check 1: AWS CLI"
if command -v aws &>/dev/null; then
  AWS_VER="$(aws --version 2>&1 | awk '{print $1}')"
  pass "AWS CLI found: $AWS_VER"
else
  fail "AWS CLI not found — run setup.sh first"
fi

# ── Check 2: Active credentials ───────────────────────────────────────────────
section "Check 2: Credentials"
if IDENTITY="$(aws sts get-caller-identity --output json 2>&1)"; then
  ACCOUNT="$(echo "$IDENTITY" | grep '"Account"' | sed 's/.*: "\(.*\)".*/\1/')"
  ARN="$(echo "$IDENTITY" | grep '"Arn"' | sed 's/.*: "\(.*\)".*/\1/')"
  pass "Credentials valid — Account: $ACCOUNT"
  info "  ARN: $ARN"
else
  fail "Credential check failed — run: aws login --region $REGION"
fi

# ── Check 3: Skill catalog ────────────────────────────────────────────────────
section "Check 3: Agent Toolkit skill catalog"
if SKILL_COUNT="$(aws agent-toolkit list-available-skills --region us-east-1 --no-cli-pager 2>/dev/null \
    | grep -c '"name"')"; then
  pass "Catalog accessible — $SKILL_COUNT skills available"
else
  fail "Could not reach Agent Toolkit catalog (us-east-1)"
fi

# ── Check 4: Bedrock model list ───────────────────────────────────────────────
section "Check 4: Amazon Bedrock (foundation models)"
if MODEL_COUNT="$(aws bedrock list-foundation-models --region "$REGION" --no-cli-pager 2>/dev/null \
    | grep -c '"modelId"')"; then
  pass "Bedrock accessible — $MODEL_COUNT foundation models in $REGION"
else
  fail "Could not list Bedrock foundation models in $REGION"
  warn "  Bedrock may not be available in this region — try us-east-1 or us-west-2"
fi

# ── Check 5: Write access (CloudWatch Logs CRUD) ──────────────────────────────
section "Check 5: Write access (CloudWatch Logs)"

# Create
info "Creating log group: $LOG_GROUP"
if aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION" --no-cli-pager 2>/dev/null; then
  pass "Log group created"
  CREATED=true
else
  fail "Could not create log group — check IAM permissions"
  CREATED=false
fi

# Describe (brief sleep for CloudWatch eventual consistency)
if [[ "$CREATED" == true ]]; then
  sleep 2
  info "Describing log group..."
  if DESCRIBE="$(aws logs describe-log-groups \
      --log-group-name-prefix "$LOG_GROUP" \
      --region "$REGION" --no-cli-pager 2>/dev/null)" \
      && echo "$DESCRIBE" | grep -q "$LOG_GROUP"; then
    pass "Log group confirmed in AWS"
  else
    fail "Log group not found after creation"
  fi

  # Delete (cleanup)
  info "Deleting log group (cleanup)..."
  if aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION" --no-cli-pager 2>/dev/null; then
    pass "Log group deleted — no resources left behind"
  else
    warn "Could not delete $LOG_GROUP — delete it manually to avoid charges"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}────────────────────────────────────────────────────${RESET}"
echo -e "${BOLD}Results: $PASS/$TOTAL checks passed${RESET}"
echo -e "${BOLD}────────────────────────────────────────────────────${RESET}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed. The Agent Toolkit is fully operational.${RESET}"
  echo ""
  echo "Useful next commands:"
  echo "  aws agent-toolkit search-skills --search-query <topic> --region us-east-1"
  echo "  aws agent-toolkit add-skill --skill-name <name> --region us-east-1"
  echo "  aws bedrock list-foundation-models --region $REGION --no-cli-pager --output table"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed. Review the output above.${RESET}"
  echo ""
  echo "Common fixes:"
  echo "  Expired credentials  →  aws login --region $REGION"
  echo "  Toolkit not set up   →  ./scripts/setup.sh --region $REGION"
  exit 1
fi
