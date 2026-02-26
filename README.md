# 🤖 Linear Issue Agent

An autonomous AI agent skill that bridges **Linear** (project management) and **GitHub** (code & deployment). It picks up To-Do issues, plans, implements, tests, and deploys — with full transparency and human-in-the-loop approval gates.

## What It Does

```
To-Do Issue → Plan → Implement → Test → Review → Deploy → Close
```

| Phase | Description |
|-------|-------------|
| **Init** | Validates config, syncs repo, connects to Linear |
| **Discover** | Lists To-Do issues, lets you auto-pick or choose |
| **Plan** | Analyzes codebase, creates implementation plan |
| **Implement** | Writes code with full transparency on every change |
| **Quality Gate** | Runs lint, tests, build — shows all output |
| **Review** | Creates GitHub PR, takes screenshots, notifies via Linear |
| **Deploy** | Ensures branch is clean and pushed to GitHub |
| **Close** | Posts learnings, screenshots, links — marks issue Done |

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
```

### 3. Run

Use the `/linear-agent` slash command in your AI IDE, or just ask:

> "Work on my Linear issues"

## Requirements

- **Git** with push access to a GitHub remote
- **GitHub CLI (`gh`)** — installed and authenticated
- **Linear MCP Server** — connected and authenticated
- An AI IDE that supports skills/workflows (e.g., Gemini)

## Configuration Options

| Field | Required | Description |
|-------|----------|-------------|
| `linear_project` | ✅ | Linear project name, slug, or ID |
| `linear_team` | ✅ | Linear team name or key |
| `base_branch` | Auto-detect | Branch to create features from |
| `dev_command` | Optional | Dev server command |
| `test_command` | Optional | Test runner command |
| `lint_command` | Optional | Linter command |
| `build_command` | Optional | Build/compile command |
| `deployment.platform` | Optional | Vercel, Netlify, etc. |

See the full [config template](.agents/skills/linear-agent/config.template.yml) for all options.

## Key Principles

- **🔍 Full Transparency** — Every action is explained before and after execution
- **🛑 Human-in-the-Loop** — Approval gate before deployment; you own the merge
- **📚 Learnings** — Each closed ticket includes notes for future reference
- **🔧 Universal** — Works with any tech stack via configurable commands
- **🔔 Notifications** — Uses Linear comments to trigger email/app notifications

## License

Private — for personal use only.
