# AWS Agent Toolkit for AWS — Setup & Verification

A reference guide for installing, authenticating, and verifying the
[Agent Toolkit for AWS](https://github.com/aws/agent-toolkit-for-aws) on macOS.

---

## Overview

The Agent Toolkit for AWS equips AI coding agents (Claude Code, Codex, Kiro, Cursor, etc.)
with curated AWS skills and an AWS MCP Server connection — enabling them to build, deploy,
and manage AWS resources with service-specific guardrails and up-to-date guidance.

**What gets installed:**
- 16 default AWS skills (markdown guidance files) deployed to each detected AI agent
- AWS MCP Server configured for supported agents (Claude Code auto-configured via `~/.claude.json`)
- Authentication via IAM Identity Center (`aws login`) — no long-lived access keys needed

---

## Prerequisites

| Requirement | Notes |
|---|---|
| macOS (Apple Silicon or Intel) | Linux supported via same `install.sh` script |
| `curl` | Pre-installed on macOS |
| Internet access to `awscli.amazonaws.com` | Required for CLI installer |
| AWS account | Root or IAM user with sufficient permissions |

---

## Step 1 — Install AWS CLI v2

If AWS CLI is not already installed:

```bash
curl -fsSL 'https://awscli.amazonaws.com/v2/install.sh' | bash
```

Add the CLI to your PATH for the current and future sessions:

```bash
export PATH="$HOME/.local/bin:$PATH"

SHELL_RC="$HOME/.zshrc"   # or ~/.bashrc for bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC" && source "$SHELL_RC"
```

Verify:

```bash
aws --version
# aws-cli/2.x.x ...
```

> If AWS CLI v2 is already present, skip this step entirely.

---

## Step 2 — Configure Default Region

```bash
aws configure set region us-west-2   # substitute your preferred region
```

---

## Step 3 — Authenticate via Browser (IAM Identity Center)

```bash
aws login --region us-west-2
```

A browser window opens for sign-in. Complete authentication there, then return to the terminal.

**Session lifetime:**
- Credentials are valid for **12 hours**
- Can be **renewed for 90 days** without re-authenticating in the browser
- Re-run `aws login` to refresh an expired session

---

## Step 4 — Verify Credentials

```bash
aws sts get-caller-identity
```

Expected output:

```json
{
    "UserId": "<account-id>",
    "Account": "<account-id>",
    "Arn": "arn:aws:iam::<account-id>:..."
}
```

---

## Step 5 — Install the Agent Toolkit

> **Note:** The Agent Toolkit service endpoint is only available in `us-east-1`.
> Use `us-east-1` for all `agent-toolkit` commands, regardless of your default region.

```bash
aws configure agent-toolkit --yes --region us-east-1
```

The installer will:
1. Detect installed AI coding agents on your machine
2. Fetch and install 16 default AWS skills to each detected agent's skills directory
3. Configure the AWS MCP Server connection where supported

**Skills are installed to:**

| Agent | Skills path |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.agents/skills/` |
| Kiro | `~/.kiro/skills/` |
| Cursor | `~/.cursor/skills/` |

**MCP Server auto-configured for:**
- Claude Code (`~/.claude.json` updated automatically)

**Manual MCP setup required for:**
- Codex — requires `codex` binary on `$PATH` first, then rerun the installer
- OpenClaw — see [manual setup docs](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html)

### Troubleshooting: Exit code 253

If the installer exits with code 253 ("requires interactive terminal"), run it
manually in your terminal:

```bash
aws configure agent-toolkit --region us-east-1
```

---

## Step 6 — Verify Agent Toolkit Installation

List all skills in the remote catalog:

```bash
aws agent-toolkit list-available-skills --region us-east-1 --no-cli-pager
```

List skills currently installed on your machine:

```bash
aws agent-toolkit list-installed-skills --region us-east-1 --no-cli-pager
```

Expected response: JSON array of skill objects with `name`, `description`,
`skillVersion`, and `categories` fields.

---

## Verification Snapshot (July 2026)

### Default Skills Installed (16)

| Skill | Category |
|---|---|
| `amazon-bedrock` | aws-core |
| `aws-billing-and-cost-management` | aws-core |
| `aws-blocks` | aws-core |
| `aws-cdk` | aws-core |
| `aws-cloudformation` | aws-core |
| `aws-compute` | aws-core |
| `aws-containers` | aws-core |
| `aws-deployment` | aws-core |
| `aws-messaging-and-streaming` | aws-core |
| `aws-observability` | aws-core |
| `aws-sdk-js-v3-usage` | aws-core |
| `aws-sdk-python-usage` | aws-core |
| `aws-sdk-swift-usage` | aws-core |
| `aws-serverless` | aws-core |
| `launch-with-aws` | aws-core |
| `signing-in-to-aws` | aws-core |

### Catalog Size
89+ skills available in the remote catalog (as of July 2026), covering databases,
networking, compute, resilience, security, analytics, and more.

### End-to-End Functional Test

Verified credentials and write access with a create/read/delete cycle:

```bash
# Create
aws logs create-log-group --log-group-name "/agent-toolkit/verification" --region us-west-2

# Read
aws logs describe-log-groups --log-group-name-prefix "/agent-toolkit/verification" --region us-west-2

# Delete
aws logs delete-log-group --log-group-name "/agent-toolkit/verification" --region us-west-2
```

---

## Day-to-Day Usage

### Refresh expired credentials

```bash
aws login --region us-west-2
```

### List models available on Amazon Bedrock

```bash
aws bedrock list-foundation-models --region us-west-2 --no-cli-pager \
  --query 'modelSummaries[?modelLifecycle.status==`ACTIVE`].{ModelId:modelId,Provider:providerName}' \
  --output table
```

### Add an additional skill

```bash
aws agent-toolkit add-skill --skill-name <skill-name> --region us-east-1
```

### Search for skills by topic

```bash
aws agent-toolkit search-skills --search-query "serverless" --region us-east-1
```

### Update all installed skills

```bash
aws agent-toolkit update-skill --skill-name <skill-name> --region us-east-1
```

### Remove a skill

```bash
aws agent-toolkit remove-skill --skill-name <skill-name> --region us-east-1
```

---

## Known Issues

| Issue | Cause | Workaround |
|---|---|---|
| `aws ssm put-parameter` hangs | SSM write operations restricted for root account credentials | Use an IAM user or role (not root) for day-to-day operations |
| Exit code 253 on toolkit install | Non-interactive terminal | Run `aws configure agent-toolkit --region us-east-1` manually |
| Browser does not open on `aws login` | Headless environment | Copy the URL from terminal output and open it manually |

---

## References

- [Agent Toolkit for AWS — GitHub](https://github.com/aws/agent-toolkit-for-aws)
- [AWS CLI v2 Installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Agent Toolkit User Guide](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/)
- [Manual MCP Server Setup](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html)
- [Amazon Bedrock Foundation Models](https://docs.aws.amazon.com/bedrock/latest/userguide/foundation-models.html)
