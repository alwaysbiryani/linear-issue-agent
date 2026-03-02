---
description: Run the Linear Issue Agent to pick up and work on To-Do issues from a Linear project
---

# Linear Issue Agent Workflow

<!--
  Platform Note: The directive below auto-approves safe terminal commands
  without prompting. It is currently supported by Gemini-based IDEs only.
  Other IDEs (Claude Code, Cursor, Windsurf) will safely ignore it —
  you'll simply be prompted to approve each command manually.
-->
// turbo-all

This workflow activates the **Linear Issue Agent** skill, which autonomously picks up To-Do issues from a configured Linear project, implements them, and deploys via GitHub PR — with **email notifications**, **auto error resolution**, **proactive CI testing**, and **automatic conflict resolution**.

> **IDE Compatibility**: This workflow is tested with Gemini. For Claude Code, Cursor, or Windsurf, see the [Tool Mapping Table](#tool-mapping) in SKILL.md for capability equivalents.

## Steps

1. **Read the skill instructions**
   - Read the full skill document at `.agents/skills/linear-agent/SKILL.md`
   - Follow every phase exactly as documented

2. **Run Phase 0: Initialization**
   - Load the config from `.agents/config/linear-agent.yml`
   - If the config doesn't exist, copy from `.agents/skills/linear-agent/config.template.yml` and ask the user to fill in required fields
   - Validate all prerequisites (GitHub CLI, Git remote, Linear MCP)
   - Validate notification setup (msmtp) if `notification_email` is configured
   - Detect or confirm base branch
   - Sync the local repo
   - Connect to the Linear project

3. **Run Phase 1: Issue Discovery**
   - Fetch all To-Do issues from the configured project
   - Present them to the user in a formatted table
   - Ask: auto-pick or manual selection
   - Lock the selected issue (set to In Progress, assign to me)

4. **Run Phase 2: Planning** _(MANUAL CHECKPOINT)_
   - Read the full issue details and comments
   - Analyze the codebase for affected areas
   - Create an implementation plan (as an artifact)
   - Post the plan summary as a comment on the Linear issue
   - Send email notification if configured
   - **STOP and wait for user to approve/revise/cancel the plan**

5. **Run Phase 3: Implementation**
   - Create a feature branch
   - Implement changes with full transparency (explain every edit)
   - Commit incrementally with conventional commit messages

6. **Run Phase 4: Quality Gate** _(AUTO-FIX LOOP)_
   - Run lint, tests, and build (if configured)
   - Auto-fix failures up to `max_auto_fix_attempts` (default: 3) per check
   - Only escalate to user after exhausting all fix attempts
   - Commit auto-fix changes with proper references

7. **Run Phase 5: Ready for Review** _(MANUAL CHECKPOINT)_
   - Push branch and create GitHub PR
   - Start dev server for local testing
   - Take screenshots if applicable
   - Update Linear issue status and post review comment
   - Send email notification if configured
   - **STOP and wait for user approval**
   - Handle: approved → Phase 6, changes → Phase 3, cancel → revert

8. **Run Phase 5B: Proactive Local CI** _(runs during Phase 5 wait)_
   - Re-run quality gates locally after PR push
   - Auto-fix any issues found before GitHub CI reports them
   - Monitor GitHub Actions status and fix proactively
   - Only runs if `proactive_local_ci: true` in config

9. **Run Phase 6: Deployment** _(with conflict resolution)_
   - Ensure branch is up-to-date (rebase/merge as needed)
   - If conflicts: auto-resolve simple ones, escalate complex ones
   - Re-run quality gates after conflict resolution
   - Verify CI status on the PR
   - Report preview/deployment URL if available

10. **Run Phase 7: Closure** _(MANUAL CHECKPOINT)_
    - Take final screenshots
    - Post comprehensive closure comment on Linear (changes, links, learnings)
    - Move issue to Done (only after user confirms)
    - Cleanup: stop dev server, switch to base branch
    - Ask user: pick up next issue or stop?
