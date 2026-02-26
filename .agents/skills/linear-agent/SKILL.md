---
name: Linear Issue Agent
description: >
  An autonomous agent that reads issues from a specified Linear project, plans and implements
  code for To-Do issues, notifies for manual testing, and deploys via GitHub PR on approval.
  Closes Linear tickets with full details (screenshots, links, learnings).
---

# Linear Issue Agent

> An end-to-end autonomous development agent that bridges **Linear** (project management) and **GitHub** (code & deployment). It picks up To-Do issues, plans, implements, tests, and deploys — with full transparency and human-in-the-loop approval gates.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Configuration](#configuration)
3. [Agent Lifecycle](#agent-lifecycle)
4. [Phase 0: Initialization](#phase-0-initialization)
5. [Phase 1: Issue Discovery](#phase-1-issue-discovery)
6. [Phase 2: Planning](#phase-2-planning)
7. [Phase 3: Implementation](#phase-3-implementation)
8. [Phase 4: Quality Gate](#phase-4-quality-gate)
9. [Phase 5: Ready for Review](#phase-5-ready-for-review)
10. [Phase 6: Deployment](#phase-6-deployment)
11. [Phase 7: Closure](#phase-7-closure)
12. [Error Handling](#error-handling)
13. [Transparency Rules](#transparency-rules)

---

## Prerequisites

Before using this skill, ensure:

1. **Linear MCP Server** is connected and authenticated.
2. **Git** is installed and the repo is cloned locally with push access.
3. **GitHub CLI (`gh`)** is installed and authenticated (`gh auth status`).
4. A **per-repo config file** exists at `.agents/config/linear-agent.yml` (see [Configuration](#configuration)).

### First-Time Setup Check

Run these checks at the start of every session:

```
# Verify GitHub CLI
gh auth status

# Verify git remote
git remote -v

# Verify Linear MCP is available
# (use mcp_linear-mcp-server_list_teams to test connectivity)
```

If any check fails, **stop and inform the user** before proceeding.

---

## Configuration

Each repository should have a config file at `.agents/config/linear-agent.yml`.

If one doesn't exist, **copy from the template** at `.agents/skills/linear-agent/config.template.yml` and ask the user to fill in the required values.

### Config Schema

```yaml
# .agents/config/linear-agent.yml

# REQUIRED: Linear project identifier (name, slug, or ID)
linear_project: "My Project"

# REQUIRED: Linear team name or key
linear_team: "Engineering"

# OPTIONAL: Base branch to create feature branches from (auto-detected if omitted)
base_branch: ""

# OPTIONAL: Deploy command to run before pushing (e.g., build check)
build_command: ""

# OPTIONAL: Dev server command for local testing
dev_command: "npm run dev"

# OPTIONAL: Test command
test_command: ""

# OPTIONAL: Lint/format command
lint_command: ""

# OPTIONAL: Port for dev server
dev_port: 3000

# OPTIONAL: Issue auto-pick priority order (default shown)
priority_order: [1, 2, 3, 4, 0]  # Urgent, High, Normal, Low, None

# OPTIONAL: Deployment platform specifics
deployment:
  platform: "vercel"  # vercel | netlify | github-pages | custom | none
  preview_url_pattern: ""  # e.g., "https://{branch}.my-app.vercel.app"
```

### Loading Config

1. Read `.agents/config/linear-agent.yml` from the current workspace root.
2. If missing, copy the template and **ask the user** to fill in `linear_project` and `linear_team`.
3. For optional fields, use sensible defaults or auto-detect where possible.

---

## Agent Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                     AGENT LIFECYCLE                             │
│                                                                 │
│  ┌──────────┐   ┌───────────┐   ┌──────────┐   ┌───────────┐  │
│  │  INIT    │──▶│ DISCOVER  │──▶│  PLAN    │──▶│ IMPLEMENT │  │
│  │ Phase 0  │   │  Phase 1  │   │ Phase 2  │   │  Phase 3  │  │
│  └──────────┘   └───────────┘   └──────────┘   └───────────┘  │
│                                                      │         │
│                                                      ▼         │
│  ┌──────────┐   ┌───────────┐   ┌──────────┐   ┌───────────┐  │
│  │  CLOSE   │◀──│  DEPLOY   │◀──│ APPROVAL │◀──│ QUALITY   │  │
│  │ Phase 7  │   │  Phase 6  │   │ Phase 5  │   │  Phase 4  │  │
│  └──────────┘   └───────────┘   └──────────┘   └───────────┘  │
│       │                              │                         │
│       │                              │ (changes requested)     │
│       │                              └──────▶ Phase 3          │
│       │                                                        │
│       └──────▶ Phase 1 (next issue)                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 0: Initialization

**Goal**: Set up the environment and validate everything is ready.

### Steps

1. **Load Config**
   - Read `.agents/config/linear-agent.yml`.
   - If missing, create from template and ask user to configure.

2. **Validate Prerequisites**
   - Run `gh auth status` — must be authenticated.
   - Run `git remote -v` — must have a GitHub remote.
   - Test Linear MCP connectivity: call `list_teams`.

3. **Detect Base Branch**
   - If `base_branch` is not set in config:
     ```bash
     git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
     ```
   - Fallback: check for `main`, then `master`.
   - **Tell the user**: "📋 Detected base branch: `{branch}`"

4. **Sync Local Repo**
   ```bash
   git fetch origin
   git checkout {base_branch}
   git pull origin {base_branch}
   ```
   - **Tell the user**: "✅ Repo synced to latest `{base_branch}`"

5. **Fetch Linear Project Info**
   - Call `get_project` with the configured project name.
   - Store the project ID for subsequent calls.
   - **Tell the user**: "🔗 Connected to Linear project: **{project_name}**"

---

## Phase 1: Issue Discovery

**Goal**: Find all To-Do issues and let the user pick one (or auto-pick).

### Steps

1. **Fetch To-Do Issues**
   - Call `list_issues` with:
     - `project`: configured project name
     - `state`: "Todo" (also try "To Do", "Backlog" if no results — check with `list_issue_statuses` first)
   - Sort by priority (configured `priority_order`).

2. **Present Issues to User**
   - Format as a numbered table:
     ```
     📋 To-Do Issues in "{project_name}":

     | #  | ID      | Priority | Title                          |
     |----|---------|----------|--------------------------------|
     | 1  | LIN-42  | 🔴 Urgent | Fix login page crash          |
     | 2  | LIN-58  | 🟠 High   | Add dark mode support         |
     | 3  | LIN-61  | 🟡 Normal  | Update footer links           |
     ```

3. **Selection Mode**
   - Ask the user:
     > "Would you like me to **auto-pick** the highest priority issue, or would you like to **choose** one? (Type a number, 'auto', or 'skip' to skip an issue)"
   - **Auto-pick**: Select the first issue by priority order.
   - **Manual pick**: Wait for user to specify a number or issue ID.

4. **Lock the Issue**
   - Once selected, update the Linear issue:
     - Set state to **"In Progress"**
     - Assign to **"me"** (the authenticated user)
   - **Tell the user**: "🚀 Starting work on **{issue_id}: {title}** — marked as In Progress"

---

## Phase 2: Planning

**Goal**: Analyze the issue, understand requirements, and create an implementation plan.

### Steps

1. **Read the Full Issue**
   - Call `get_issue` with `includeRelations: true`.
   - Read the description, comments, labels, and any linked issues.
   - If the description contains images, call `extract_images` to view them.

2. **Read Issue Comments**
   - Call `list_comments` on the issue to get full context.
   - Look for acceptance criteria, edge cases, or additional context.

3. **Analyze the Codebase**
   - Based on the issue description, identify:
     - Which files/components are likely affected.
     - Dependencies and related code.
     - Existing tests that might need updating.
   - Use `grep_search`, `find_by_name`, `view_file_outline` to explore.

4. **Create Implementation Plan**
   - Write a structured plan as an **artifact** (`implementation_plan.md`):
     ```markdown
     # Implementation Plan: {issue_id} — {title}

     ## Understanding
     {summary of what the issue asks for}

     ## Affected Areas
     - File 1: reason
     - File 2: reason

     ## Approach
     1. Step 1
     2. Step 2
     3. Step 3

     ## Testing Strategy
     - What to test
     - How to verify

     ## Risks & Considerations
     - Risk 1
     - Risk 2
     ```

5. **Post Plan to Linear**
   - Add a comment on the issue with the plan summary:
     ```
     🤖 **Agent: Implementation Plan**

     **Approach**: {brief summary}

     **Files to modify**:
     - `file1.ts` — {reason}
     - `file2.ts` — {reason}

     **Estimated changes**: {small/medium/large}

     Starting implementation now.
     ```

6. **Tell the user**:
   > "📝 I've analyzed the issue and created an implementation plan. Here's what I'm thinking: {brief summary}. The full plan is in the artifact. Proceeding to implementation."

---

## Phase 3: Implementation

**Goal**: Write the code, transparently showing every step.

### Steps

1. **Create Feature Branch**
   ```bash
   git checkout {base_branch}
   git pull origin {base_branch}
   git checkout -b feature/{issue_id_lowercase}-{slugified_title}
   ```
   - Example: `feature/lin-42-fix-login-page-crash`
   - **Tell the user**: "🌿 Created branch: `feature/{branch_name}`"

2. **Implement Changes**
   - Follow the implementation plan from Phase 2.
   - For **every file change**, tell the user:
     > "✏️ Modifying `{filename}`: {what and why}"
   - Use the appropriate file editing tools.
   - Keep changes focused on the issue — no unrelated refactors.

3. **Commit Incrementally**
   - Make logical, atomic commits:
     ```bash
     git add {files}
     git commit -m "{type}({scope}): {description}

     Refs: {issue_id}"
     ```
   - Commit types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `chore`
   - **Tell the user** after each commit:
     > "💾 Committed: `{commit_message}`"

4. **Transparency Rules During Implementation**
   - Before editing: explain **what** you're changing and **why**
   - After editing: summarize **what** changed
   - If you hit an unexpected issue: **stop and explain**, ask for guidance
   - If you deviate from the plan: **explain why**
   - Show relevant code snippets when helpful

---

## Phase 4: Quality Gate

**Goal**: Run all quality checks and report results transparently.

### Steps

1. **Run Linter** (if configured)
   ```bash
   {lint_command}
   ```
   - **Tell the user**: "🔍 Running linter..."
   - Show the full output.
   - If there are errors: fix them, then re-run.
   - **Tell the user**: "✅ Lint: passed" or "⚠️ Lint: {N} warnings (non-blocking)"

2. **Run Tests** (if configured)
   ```bash
   {test_command}
   ```
   - **Tell the user**: "🧪 Running tests..."
   - Show the full output.
   - If tests fail:
     - Analyze the failure.
     - Fix if clearly related to the changes.
     - If unclear, **stop and ask the user**.
   - **Tell the user**: "✅ Tests: {X}/{Y} passed" or "❌ Tests: {N} failed — {summary}"

3. **Run Build** (if configured)
   ```bash
   {build_command}
   ```
   - **Tell the user**: "🏗️ Running build..."
   - Show relevant output (errors/warnings).
   - **Tell the user**: "✅ Build: successful" or "❌ Build: failed — {summary}"

4. **Quality Summary**
   - Present a summary:
     ```
     ✅ Quality Gate Summary:
     ├── Lint:   ✅ Passed
     ├── Tests:  ✅ 24/24 passed
     └── Build:  ✅ Successful
     ```

---

## Phase 5: Ready for Review

**Goal**: Push the branch, create a PR, notify the user, and wait for approval.

### Steps

1. **Push Branch to GitHub**
   ```bash
   git push origin feature/{branch_name}
   ```
   - **Tell the user**: "📤 Pushed branch to GitHub"

2. **Create Pull Request**
   ```bash
   gh pr create \
     --title "{issue_id}: {issue_title}" \
     --body "{pr_body}" \
     --base {base_branch} \
     --head feature/{branch_name}
   ```
   - **PR Body Template**:
     ```markdown
     ## Summary
     {Brief description of changes}

     ## Linear Issue
     {issue_url}

     ## Changes Made
     - {change 1}
     - {change 2}

     ## Testing
     - [ ] Lint passes
     - [ ] Tests pass
     - [ ] Build succeeds
     - [ ] Manual testing: {what to test}

     ## Screenshots
     {if applicable}

     ---
     🤖 _This PR was created by the Linear Issue Agent_
     ```
   - **Tell the user**: "🔗 PR created: {pr_url}"

3. **Start Dev Server for Testing** (if configured)
   ```bash
   {dev_command}
   ```
   - **Tell the user**: "🖥️ Dev server running at `http://localhost:{dev_port}`"

4. **Take Screenshots** (if applicable)
   - Use the browser subagent to navigate to the relevant pages.
   - Capture screenshots of the changes.
   - Save screenshots to the artifacts directory.

5. **Notify on Linear**
   - Update issue state to a review state (e.g., "In Review" or "Ready for Testing")
     - First check available statuses with `list_issue_statuses`
     - Use the closest matching status
   - Add a comment on the Linear issue:
     ```markdown
     🤖 **Agent: Ready for Review**

     **Pull Request**: {pr_url}
     **Branch**: `feature/{branch_name}`

     **Changes Summary**:
     - {change 1}
     - {change 2}

     **Quality Gate**: ✅ All checks passed

     **How to Test**:
     1. {step 1}
     2. {step 2}

     **Screenshots**:
     {embedded screenshots if taken}

     ---
     ⏳ Waiting for approval to deploy.
     @{user_mention} — please review and approve.
     ```
   - This comment will trigger a Linear notification (email/app based on user's Linear notification settings).

6. **Wait for Approval**
   - **Tell the user clearly**:
     > "🔔 **Ready for your review!**
     >
     > - **PR**: {pr_url}
     > - **Linear**: Issue updated to 'In Review'
     > - **Dev server**: running at localhost:{port}
     >
     > Please test and let me know:
     > - ✅ **'approved'** — I'll proceed to deployment
     > - 🔄 **'changes needed: {description}'** — I'll make the changes
     > - ❌ **'cancel'** — I'll stop and move the issue back to To-Do"

7. **Handle Response**
   - **Approved**: Proceed to Phase 6.
   - **Changes needed**: Go back to Phase 3, apply requested changes, re-run Phase 4, return here.
   - **Cancel**: Move issue back to "Todo", delete branch, notify on Linear.

---

## Phase 6: Deployment

**Goal**: The PR branch is on GitHub. Deployment is branch-based (merging is manual).

### Steps

1. **Confirm Deployment**
   - **Tell the user**:
     > "🚀 Deploying branch `feature/{branch_name}` to GitHub..."

2. **Ensure Branch is Up-to-Date**
   ```bash
   git fetch origin {base_branch}
   git rebase origin/{base_branch}
   git push origin feature/{branch_name} --force-with-lease
   ```
   - If rebase conflicts: **stop and ask user for help**.

3. **Verify PR Status**
   ```bash
   gh pr view --json state,statusCheckRollup,url
   ```
   - Report CI status to user.
   - If CI fails: investigate and fix, or ask user.

4. **Get Deployment URL** (if applicable)
   - For Vercel/Netlify: check for preview deployment URL in PR checks.
     ```bash
     gh pr checks
     ```
   - **Tell the user**: "🌐 Preview deployment: {preview_url}"

5. **Tell the user**:
   > "✅ **Deployment complete!**
   >
   > - **PR**: {pr_url}
   > - **Preview URL**: {preview_url} (if available)
   > - **Branch**: `feature/{branch_name}`
   >
   > The PR is ready for you to merge when you're satisfied. Proceeding to close the Linear issue."

---

## Phase 7: Closure

**Goal**: Close the Linear issue with comprehensive details and learnings.

### Steps

1. **Take Final Screenshots** (if applicable)
   - If there's a preview URL, use the browser subagent to capture screenshots.
   - Save to artifacts.

2. **Gather All Details**
   - PR URL and number
   - Branch name
   - Commit hashes (all commits in the PR)
   - Files changed (list)
   - Preview/deployment URL
   - Screenshots taken

3. **Post Closure Comment on Linear**
   - Add a detailed comment:
     ```markdown
     🤖 **Agent: Implementation Complete**

     ## Summary
     {What was done and how}

     ## Pull Request
     🔗 {pr_url}
     📌 Branch: `feature/{branch_name}`

     ## Changes
     | File | Change |
     |------|--------|
     | `file1.ts` | {description} |
     | `file2.ts` | {description} |

     ## Commits
     - `{hash_short}` — {message}
     - `{hash_short}` — {message}

     ## Deployment
     🌐 Preview: {preview_url}
     _(PR is ready to merge for production deployment)_

     ## Screenshots
     {embedded screenshots}

     ## Learnings & Notes
     {Any insights, gotchas, alternative approaches considered, or
      recommendations for future work. This is context-specific and
      aims to help future development on this project.}

     Examples:
     - "Used X library instead of Y because of Z constraint"
     - "The component structure made this change straightforward —
        consider this pattern for similar features"
     - "Found a pre-existing issue in {file} that should be
        addressed separately: {detail}"
     - "This area of the codebase would benefit from {suggestion}"

     ---
     ✅ _Completed by Linear Issue Agent_
     ```

4. **Update Linear Issue State**
   - Move issue to **"Done"** status.
   - Verify available statuses first with `list_issue_statuses`.

5. **Cleanup**
   - Stop any running dev server.
   - Switch back to base branch:
     ```bash
     git checkout {base_branch}
     git pull origin {base_branch}
     ```

6. **Report to User**
   - **Tell the user**:
     > "✅ **{issue_id}: {title}** — Complete!
     >
     > - Linear issue: closed with full details
     > - PR: ready to merge
     > - All details posted to the Linear issue
     >
     > Would you like me to pick up the next issue, or are we done for now?"

---

## Error Handling

### General Rules
- **Never silently fail**. Always report errors to the user with full context.
- **Never guess**. If unsure about the user's intent, ask.
- **Rollback on failure**. If a phase fails mid-way:
  - Git: stash or reset changes as appropriate
  - Linear: revert status changes
  - Inform the user what happened and what state things are in.

### Common Scenarios

| Scenario | Action |
|----------|--------|
| Linear MCP not connected | Stop. Ask user to configure. |
| GitHub CLI not authenticated | Stop. Ask user to run `gh auth login`. |
| Config file missing | Create from template. Ask user to fill in. |
| Base branch detection fails | Ask user to specify in config. |
| Merge/rebase conflicts | Stop. Show conflicts. Ask user for resolution. |
| Tests fail | Analyze. Fix if related to changes. Ask user if unclear. |
| Build fails | Analyze. Fix if possible. Ask user if unclear. |
| Issue has no description | Ask user for requirements before planning. |
| Network/API errors | Retry once. If still failing, report to user. |

---

## Transparency Rules

> These rules are **non-negotiable**. The agent must never operate as a black box.

1. **Announce every phase**: Before starting each phase, tell the user what you're about to do.
2. **Show all command output**: When running terminal commands (tests, lint, build), show the full output.
3. **Explain every file change**: Before editing a file, explain what you're changing and why.
4. **Report results immediately**: After running any check, report the result right away.
5. **Flag deviations**: If you need to deviate from the plan, explain why before doing it.
6. **Ask, don't assume**: If there's ambiguity, ask the user rather than guessing.
7. **Show your reasoning**: When making architectural or design decisions, explain the tradeoffs.
8. **Progress updates**: For long operations, provide periodic status updates.
9. **Error transparency**: If something goes wrong, explain what happened, why, and what the options are.
10. **Summary at each gate**: At the end of each major phase, provide a concise summary.

---

## Invocation

This skill is triggered via the `/linear-agent` workflow command, or by asking:
- "Work on my Linear issues"
- "Pick up the next Linear issue"
- "Start the Linear agent for project X"

The workflow file at `.agents/workflows/linear-agent.md` provides the entry point.
