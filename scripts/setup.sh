#!/usr/bin/env bash
# =============================================================================
# setup.sh — Automated setup for the AWS Agent Toolkit
#
# Usage:
#   chmod +x scripts/setup.sh
#   ./scripts/setup.sh --region us-west-2
#
# What this script does:
#   1. Detects the operating system
#   2. Installs AWS CLI v2 if not present (macOS / Linux only)
#   3. Configures the default AWS region
#   4. Authenticates via `aws login` (browser-based; no access keys required)
#   5. Verifies credentials with STS
#   6. Installs the Agent Toolkit with 16 default AWS skills
#   7. Confirms installation by listing available skills
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") --region <aws-region>

Options:
  --region   AWS Region to use as default (required). Example: us-west-2
  --help     Show this help message

Example:
  ./scripts/setup.sh --region us-west-2
EOF
  exit 0
}

# ── Parse arguments ───────────────────────────────────────────────────────────
REGION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) die "Unknown argument: $1. Run with --help for usage." ;;
  esac
done

[[ -z "$REGION" ]] && die "--region is required. Example: --region us-west-2"

# ── Step 1: Detect OS ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 1 — Detecting operating system${RESET}"
OS="$(uname -s)"
case "$OS" in
  Darwin) OS_LABEL="macOS" ;;
  Linux)  OS_LABEL="Linux" ;;
  *)      die "Unsupported OS: $OS. Only macOS and Linux are supported." ;;
esac
success "Detected: $OS_LABEL"

# ── Step 2: Install AWS CLI v2 ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 2 — Checking AWS CLI${RESET}"
if command -v aws &>/dev/null; then
  AWS_VERSION="$(aws --version 2>&1 | awk '{print $1}')"
  success "AWS CLI already installed: $AWS_VERSION"
else
  info "AWS CLI not found — installing v2 for $OS_LABEL..."
  if ! command -v curl &>/dev/null; then
    die "curl is required but not installed. Install it and re-run this script."
  fi
  curl -fsSL 'https://awscli.amazonaws.com/v2/install.sh' | bash
  export PATH="$HOME/.local/bin:$PATH"

  SHELL_RC="$HOME/.bashrc"
  [[ "$(basename "${SHELL:-bash}")" == "zsh" ]] && SHELL_RC="$HOME/.zshrc"
  grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC" 2>/dev/null \
    || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"

  command -v aws &>/dev/null || die "AWS CLI installation failed. Check output above."
  success "AWS CLI installed: $(aws --version 2>&1 | awk '{print $1}')"
fi

# ── Step 3: Configure default region ─────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 3 — Configuring default region: $REGION${RESET}"
aws configure set region "$REGION"
success "Default region set to $REGION"

# ── Step 4: Authenticate via browser ─────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 4 — Authenticating via AWS IAM Identity Center${RESET}"
info "A browser window will open for sign-in."
info "Complete authentication in your browser, then return here."
info "Session credentials are valid for 12 hours (renewable for 90 days)."
echo ""
aws login --region "$REGION"
success "Authentication complete"

# ── Step 5: Verify credentials ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 5 — Verifying credentials${RESET}"
IDENTITY="$(aws sts get-caller-identity --output json 2>&1)" \
  || die "Credential verification failed:\n$IDENTITY"
ACCOUNT="$(echo "$IDENTITY" | grep '"Account"' | sed 's/.*: "\(.*\)".*/\1/')"
ARN="$(echo "$IDENTITY" | grep '"Arn"' | sed 's/.*: "\(.*\)".*/\1/')"
success "Credentials valid — Account: $ACCOUNT"
info   "Identity ARN: $ARN"

# ── Step 6: Install Agent Toolkit ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 6 — Installing the AWS Agent Toolkit${RESET}"
info "Note: The Agent Toolkit service endpoint is only available in us-east-1."
info "      Your default region ($REGION) will be used for all other AWS calls."
echo ""
if aws configure agent-toolkit --yes --region us-east-1; then
  success "Agent Toolkit installed"
else
  EXIT_CODE=$?
  if [[ $EXIT_CODE -eq 253 ]]; then
    warn "Exit code 253 — non-interactive terminal detected."
    warn "Run the following command manually in your terminal, then re-run verify.sh:"
    warn "  aws configure agent-toolkit --region us-east-1"
    exit 0
  fi
  die "Agent Toolkit installation failed with exit code $EXIT_CODE"
fi

# ── Step 7: Verify installation ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 7 — Verifying Agent Toolkit installation${RESET}"
SKILL_COUNT="$(aws agent-toolkit list-available-skills --region us-east-1 --no-cli-pager \
  | grep -c '"name"')"
success "Agent Toolkit is operational — $SKILL_COUNT skills available in catalog"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}Setup complete!${RESET}"
echo ""
echo "  Default region : $REGION"
echo "  AWS account    : $ACCOUNT"
echo "  Skills in catalog: $SKILL_COUNT"
echo ""
echo "Next steps:"
echo "  • Run scripts/verify.sh to confirm end-to-end write access"
echo "  • Search for additional skills:"
echo "    aws agent-toolkit search-skills --search-query <topic> --region us-east-1"
echo ""
