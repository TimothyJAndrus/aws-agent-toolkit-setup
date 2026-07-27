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

## GitHub Actions OIDC Integration

The `verify` job in `.github/workflows/ci.yml` uses OpenID Connect (OIDC) to assume
an IAM role — no long-lived access keys stored as secrets. Follow these steps to enable it.

### Why OIDC?

With OIDC, GitHub exchanges a short-lived token for temporary AWS credentials at runtime.
Compared to storing `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` as repository secrets:

- No static credentials to rotate or leak
- Credentials expire automatically after each workflow run
- Trust is scoped to a specific repository and branch

### Prerequisites

- Your AWS account ID (find it with `aws sts get-caller-identity --query Account --output text`)
- The GitHub repository in `owner/repo` format — `TimothyJAndrus/aws-agent-toolkit-setup`
- AWS CLI authenticated locally (`aws login`)

---

### Step A — Create the IAM OIDC Identity Provider

Run once per AWS account. Skip if `token.actions.githubusercontent.com` is already listed
under IAM → Identity Providers.

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Verify it was created:

```bash
aws iam list-open-id-connect-providers
```

---

### Step B — Create the IAM Role

**1. Write the trust policy** — replace `<ACCOUNT_ID>` with your 12-digit account ID:

```bash
cat > /tmp/github-actions-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:TimothyJAndrus/aws-agent-toolkit-setup:*"
        }
      }
    }
  ]
}
EOF
```

**2. Create the role:**

```bash
aws iam create-role \
  --role-name GitHubActions-AgentToolkitVerify \
  --assume-role-policy-document file:///tmp/github-actions-trust.json \
  --description "Assumed by GitHub Actions for aws-agent-toolkit-setup CI"
```

---

### Step C — Create and Attach the IAM Policy

This least-privilege policy grants exactly what `verify.sh` needs:

```bash
cat > /tmp/agent-toolkit-verify-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "STSIdentity",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    },
    {
      "Sid": "AgentToolkitRead",
      "Effect": "Allow",
      "Action": [
        "agent-toolkit:ListAvailableSkills"
      ],
      "Resource": "*"
    },
    {
      "Sid": "BedrockRead",
      "Effect": "Allow",
      "Action": "bedrock:ListFoundationModels",
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogsCRUD",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DescribeLogGroups",
        "logs:DeleteLogGroup"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/agent-toolkit/*"
    }
  ]
}
EOF
```

Create and attach the policy:

```bash
POLICY_ARN=$(aws iam create-policy \
  --policy-name AgentToolkitVerifyCI \
  --policy-document file:///tmp/agent-toolkit-verify-policy.json \
  --query 'Policy.Arn' --output text)

aws iam attach-role-policy \
  --role-name GitHubActions-AgentToolkitVerify \
  --policy-arn "$POLICY_ARN"
```

Note the role ARN — you'll need it in the next step:

```bash
aws iam get-role \
  --role-name GitHubActions-AgentToolkitVerify \
  --query 'Role.Arn' --output text
# arn:aws:iam::<ACCOUNT_ID>:role/GitHubActions-AgentToolkitVerify
```

---

### Step D — Add the Secret to GitHub

Add the role ARN as a repository secret named `AWS_ROLE_ARN`:

```bash
gh secret set AWS_ROLE_ARN \
  --repo TimothyJAndrus/aws-agent-toolkit-setup \
  --body "arn:aws:iam::<ACCOUNT_ID>:role/GitHubActions-AgentToolkitVerify"
```

Verify it was stored:

```bash
gh secret list --repo TimothyJAndrus/aws-agent-toolkit-setup
```

---

### Step E — Enable the Workflow Job

In `.github/workflows/ci.yml`, remove the `if: false` guard from the `verify` job:

```yaml
  verify:
    name: Integration test (verify.sh)
    runs-on: ubuntu-latest
    needs: lint
    # if: false  ← delete this line
```

Commit and push — the `verify` job will run on the next push to `main`.

---

### Verifying the Integration

After pushing, confirm the workflow succeeded:

```bash
gh run list --repo TimothyJAndrus/aws-agent-toolkit-setup --limit 5
```

Stream live logs for the most recent run:

```bash
gh run watch --repo TimothyJAndrus/aws-agent-toolkit-setup
```

A successful `verify` job output looks like:

```
[PASS]  AWS CLI found: aws-cli/2.x.x
[PASS]  Credentials valid — Account: <ACCOUNT_ID>
[PASS]  Catalog accessible — 89 skills available
[PASS]  Bedrock accessible — 119 foundation models in us-west-2
[PASS]  Log group created
[PASS]  Log group confirmed in AWS
[PASS]  Log group deleted — no resources left behind

Results: 7/7 checks passed
```

### Cleaning Up

To remove the OIDC resources when they are no longer needed:

```bash
# Detach policy and delete role
aws iam detach-role-policy \
  --role-name GitHubActions-AgentToolkitVerify \
  --policy-arn "$POLICY_ARN"

aws iam delete-policy --policy-arn "$POLICY_ARN"
aws iam delete-role --role-name GitHubActions-AgentToolkitVerify

# Remove the OIDC provider (only if no other roles use it)
# aws iam delete-open-id-connect-provider \
#   --open-id-connect-provider-arn arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
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
- [Configuring OpenID Connect in AWS (GitHub Docs)](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
