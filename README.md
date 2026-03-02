# 🤖 Linear Issue Agent

![Version](https://img.shields.io/badge/version-1.2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Last Updated](https://img.shields.io/badge/last_updated-2026--02--27-brightgreen)

An autonomous AI agent skill that bridges **Linear** (project management) and **GitHub** (code & deployment). It picks up To-Do issues, plans, implements, tests, and deploys — with full transparency, human-in-the-loop approval gates, **email notifications**, **auto error resolution**, **proactive CI testing**, and **automatic conflict resolution**.

## What It Does

```
To-Do Issue → Plan → Implement → Test → Review → Deploy → Close
                ↑         ↑         ↑        ↑        ↑
              📧 stop   auto-fix  auto-fix  📧 stop  auto-resolve
              for plan   errors    errors   for test  conflicts
```

| Phase | Description |
|-------|-------------|
| **Init** | Validates config, syncs repo, connects to Linear |
| **Discover** | Lists To-Do issues, lets you auto-pick or choose |
| **Plan** | Analyzes codebase, creates implementation plan. **Sends email, waits for approval.** |
| **Implement** | Writes code with full transparency on every change |
| **Quality Gate** | Runs lint, tests, build — **auto-fixes errors** up to 3 attempts before asking you |
| **Review** | Creates GitHub PR, takes screenshots. **Sends email, waits for approval.** |
| **Proactive CI** | Re-runs tests locally after push, fixes issues before GitHub CI reports them |
| **Deploy** | Ensures branch is clean — **auto-resolves merge conflicts** when possible |
| **Close** | Posts learnings, screenshots, links — marks issue Done (manual confirmation) |

## Setup

### 1. Copy into your project

Copy the `.agents/` directory into your project root:

```bash
# Clone this repo
git clone git@github.com:alwaysbiryani/linear-issue-agent.git

# Copy the agent files into your project
cp -r linear-issue-agent/.agents/ /path/to/your/project/.agents/
```

### 2. Configure for your project

```bash
# Copy the config template
cp .agents/skills/linear-agent/config.template.yml .agents/config/linear-agent.yml

# Edit with your project details
# At minimum, fill in:
#   - linear_project: "Your Project Name"
#   - linear_team: "Your Team"
#   - notification_email: "your@gmail.com"  (optional but recommended)
```

### 3. Set up email notifications (optional)

```bash
# Install msmtp
brew install msmtp

# Create ~/.msmtprc with Gmail SMTP config
# See SKILL.md "Notification System" section for the full template

# Test it works
echo "test" | msmtp your@gmail.com
```

### 4. Run

Use the `/linear-agent` slash command in your AI IDE, or just ask:

> "Work on my Linear issues"

## Supported IDEs

| IDE | Support Level | Notes |
|-----|--------------|-------|
| **Gemini** | ✅ Native | Full support, including `// turbo-all` auto-approval |
| **Claude Code** | ✅ Compatible | Works with tool mapping (see SKILL.md [Tool Mapping Table](#tool-mapping)) |
| **Cursor** | ⚠️ Requires adaptation | Map tools manually, no `// turbo-all` support |
| **Windsurf** | ⚠️ Requires adaptation | Map tools manually, no `// turbo-all` support |

> The skill uses **capability-based language** (e.g., "search for patterns") instead of IDE-specific tool names. See the [Tool Mapping Table](.agents/skills/linear-agent/SKILL.md#tool-mapping) in SKILL.md for exact equivalents.

## Requirements

### Prerequisites

- **Git** with push access to a GitHub remote
- **GitHub CLI (`gh`)** — installed and authenticated
- **Linear MCP Server** — connected and authenticated (see setup below)
- An AI IDE that supports skills/workflows (see table above)
- **msmtp** (optional) — for email notifications (`brew install msmtp`)

### Linear MCP Setup

The agent communicates with Linear via the **Model Context Protocol (MCP)**. MCP is a standard that lets AI tools interact with external services like Linear.

**Step 1**: Add the Linear MCP server to your IDE:

```bash
# For most IDEs, add this to your MCP configuration:
npx mcp-remote https://mcp.linear.app/sse
```

**Step 2**: Authenticate when prompted — you'll be redirected to Linear to grant access.

**Step 3**: Verify the connection works:

```
# In your AI IDE, try running:
# "List my Linear teams"
# If it returns team names, MCP is connected.
```

> **Why MCP?** It allows the AI agent to read issues, update statuses, and post comments on Linear directly — no webhooks or API keys to manage manually.

### Required Auth Scopes

**GitHub CLI (`gh`)**:
- `repo` — read/write access to repositories (branches, PRs, commits)

Verify with:
```bash
gh auth status
```

**Linear (via MCP)**:
- **Issues**: read + write (fetch To-Do issues, update status, assign)
- **Comments**: write (post plan summaries, review notifications, closure details)
- **Projects**: read (discover project issues)
- **Teams**: read (verify connectivity, discover statuses)

These scopes are granted automatically when you authorize the Linear MCP connection.

## Configuration Options

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `linear_project` | ✅ | — | Linear project name, slug, or ID |
| `linear_team` | ✅ | — | Linear team name or key |
| `base_branch` | No | Auto-detect | Branch to create features from |
| `branch_prefix` | No | `feature/` | Prefix for feature branch names |
| `prefer_merge_over_rebase` | No | `false` | Use merge instead of rebase for syncing |
| `dev_command` | No | — | Dev server command |
| `test_command` | No | — | Test runner command |
| `lint_command` | No | — | Linter command |
| `build_command` | No | — | Build/compile command |
| `deployment.platform` | No | `none` | Vercel, Netlify, GitHub Pages, etc. |
| `pr_draft` | No | `false` | Create PRs as drafts |
| `pr_reviewers` | No | `[]` | GitHub usernames to request review from |
| `pr_labels` | No | `[]` | Labels to add to PRs |
| `skip_screenshots` | No | `false` | Skip screenshot capture if not available |
| `max_issues_display` | No | `20` | Max issues to show in discovery |
| `auto_pick_highest` | No | `false` | Auto-pick highest priority without asking |
| **`notification_email`** | No | — | Email address for notifications (e.g., Gmail) |
| **`notification_method`** | No | `msmtp` | How to send email: `msmtp`, `sendmail`, `mail`, `script` |
| **`max_auto_fix_attempts`** | No | `3` | Max auto-fix retries per check before asking user (0 = always ask) |
| **`lint_fix_command`** | No | — | Lint auto-fix command (e.g., `eslint . --fix`) |
| **`proactive_conflict_resolution`** | No | `true` | Auto-resolve simple merge conflicts |
| **`proactive_local_ci`** | No | `true` | Re-run CI locally after PR push |

See the full [config template](.agents/skills/linear-agent/config.template.yml) for all options with inline documentation.

## Key Principles

- **🔍 Full Transparency** — Every action is explained before and after execution
- **🛑 Human-in-the-Loop** — Approval gates at plan review and testing; you own the merge and issue closure
- **📧 Email Notifications** — Get notified via email when your attention is needed (msmtp + Gmail SMTP)
- **🔄 Auto Error Resolution** — Lint, test, and build errors auto-fixed up to 3 attempts before escalating
- **🧪 Proactive CI** — Quality gates run locally after PR push, catching issues before GitHub Actions
- **🔀 Conflict Resolution** — Simple merge conflicts auto-resolved; only complex ones escalated
- **📚 Learnings** — Each closed ticket includes notes for future reference
- **🔧 Universal** — Works with any tech stack via configurable commands
- **💾 Resilient State** — Session state persists to disk with backup, validation, and corruption recovery

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed version history.
