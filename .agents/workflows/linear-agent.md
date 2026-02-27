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

This workflow activates the **Linear Issue Agent** skill, which autonomously picks up To-Do issues from a configured Linear project, implements them, and deploys via GitHub PR.

> **IDE Compatibility**: This workflow is tested with Gemini. For Claude Code, Cursor, or Windsurf, see the [Tool Mapping Table](#tool-mapping) in SKILL.md for capability equivalents.

## Steps

1. **Read the skill instructions**
   - Read the full skill document at `.agents/skills/linear-agent/SKILL.md`
   - Follow every phase exactly as documented

2. **Run Phase 0: Initialization**
   - Load the config from `.agents/config/linear-agent.yml`
   - If the config doesn't exist, copy from `.agents/skills/linear-agent/config.template.yml` and ask the user to fill in required fields
   - Validate all prerequisites (GitHub CLI, Git remote, Linear MCP)
   - Detect or confirm base branch
   - Sync the local repo
   - Connect to the Linear project

3. **Run Phase 1: Issue Discovery**
   - Fetch all To-Do issues from the configured project
   - Present them to the user in a formatted table
   - Ask: auto-pick or manual selection
   - Lock the selected issue (set to In Progress, assign to me)

4. **Run Phase 2: Planning**
   - Read the full issue details and comments
   - Analyze the codebase for affected areas
   - Create an implementation plan (as an artifact)
   - Post the plan summary as a comment on the Linear issue

5. **Run Phase 3: Implementation**
   - Create a feature branch
   - Implement changes with full transparency (explain every edit)
   - Commit incrementally with conventional commit messages

6. **Run Phase 4: Quality Gate**
   - Run lint, tests, and build (if configured)
   - Show all output transparently
   - Fix any issues, report results

7. **Run Phase 5: Ready for Review**
   - Push branch and create GitHub PR
   - Start dev server for local testing
   - Take screenshots if applicable
   - Update Linear issue status and post review comment
   - Notify the user and wait for approval
   - Handle: approved → Phase 6, changes → Phase 3, cancel → revert

8. **Run Phase 6: Deployment**
   - Ensure branch is up-to-date (rebase if needed)
   - Verify CI status on the PR
   - Report preview/deployment URL if available

9. **Run Phase 7: Closure**
   - Take final screenshots
   - Post comprehensive closure comment on Linear (changes, links, learnings)
   - Move issue to Done
   - Cleanup: stop dev server, switch to base branch
   - Ask user: pick up next issue or stop?
