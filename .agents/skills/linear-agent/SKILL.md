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
3. [State Management & Session Continuity](#state-management--session-continuity)
4. [Agent Lifecycle](#agent-lifecycle)
5. [Phase 0: Initialization](#phase-0-initialization)
6. [Phase 1: Issue Discovery](#phase-1-issue-discovery)
7. [Phase 2: Planning](#phase-2-planning)
8. [Phase 3: Implementation](#phase-3-implementation)
9. [Phase 4: Quality Gate](#phase-4-quality-gate)
10. [Phase 5: Ready for Review](#phase-5-ready-for-review)
11. [Phase 6: Deployment](#phase-6-deployment)
12. [Phase 7: Closure](#phase-7-closure)
13. [Error Handling](#error-handling)
14. [Transparency Rules](#transparency-rules)

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

### Tool Mapping (Multi-IDE Support) {#tool-mapping}

This skill uses **capability-based** language for code exploration. Map to your IDE's tools:

| Capability | Gemini | Claude Code | Cursor | Windsurf |
|------------|--------|-------------|--------|----------|
| **Search code for patterns** | `grep_search` | `Grep` | Search | Search |
| **Discover files by name** | `find_by_name` | `Glob` | Files | Files |
| **View file structure/outline** | `view_file_outline` | `Read` | Outline | Read |
| **View file contents** | `view_file` | `Read` | Read | Read |
| **Edit file** | `replace_file_content` | `Edit` | Edit | Edit |
| **Run terminal command** | `run_command` | `Bash` | Terminal | Terminal |

> **Note**: When this skill says "search for patterns in the codebase", "discover files matching…", or "view the file structure", use the equivalent tool from your IDE column above.

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

## State Management & Session Continuity

> **Core Principle**: The agent must be able to stop at any point and resume in a completely new session — even with zero prior context — by reading state files from disk.

### Why This Matters

- **Context window limits**: Long sessions fill up the AI context; state files keep things lean.
- **Session breaks**: User closes IDE, takes a break, switches machines — state survives on disk.
- **Multiple issues**: Each issue has its own isolated state file — no cross-contamination.
- **Crash recovery**: If the agent or IDE crashes mid-phase, progress is not lost.

### State Directory

All state files live in:
```
.agents/state/linear-agent/
├── _active.yml              # Points to the currently active issue (if any)
├── lin-42.yml               # State for LIN-42
├── lin-58.yml               # State for LIN-58
└── lin-61.yml               # State for LIN-61 (completed)
```

### State File Schema

Each issue gets a YAML state file (named `{issue-id-lowercase}.yml`):

```yaml
# .agents/state/linear-agent/lin-42.yml

# ─── Issue Identity ───────────────────────────────────────────────
issue_id: "LIN-42"
issue_title: "Fix login page crash"
issue_url: "https://linear.app/team/issue/LIN-42"
linear_issue_uuid: "abc-123-def"  # Internal Linear UUID

# ─── Progress Tracking ───────────────────────────────────────────
current_phase: 3               # 0-7, which phase we're in
phase_status: "in_progress"    # not_started | in_progress | completed | blocked | cancelled | waiting_approval | changes_requested
last_updated: "2026-02-26T23:30:00+05:30"
started_at: "2026-02-26T22:00:00+05:30"

# ─── Phase Completion Log ────────────────────────────────────────
phases_completed:
  - phase: 0
    completed_at: "2026-02-26T22:01:00+05:30"
    notes: "Config loaded, repo synced to main"
  - phase: 1
    completed_at: "2026-02-26T22:02:00+05:30"
    notes: "Auto-picked LIN-42 (Urgent priority)"
  - phase: 2
    completed_at: "2026-02-26T22:10:00+05:30"
    notes: "Plan created — 3 files to modify"

# ─── Git Context ─────────────────────────────────────────────────
branch_name: "feature/lin-42-fix-login-page-crash"  # Built as: {branch_prefix}{issue_id}-{slug}
base_branch: "main"
commits:
  - hash: "a1b2c3d"
    message: "fix(auth): handle null session token"
  - hash: "e4f5g6h"
    message: "test(auth): add login crash regression test"

# ─── Files Modified ──────────────────────────────────────────────
files_modified:
  - path: "src/auth/login.ts"
    change: "Added null check for session token"
  - path: "tests/auth/login.test.ts"
    change: "Added regression test for crash scenario"

# ─── Implementation Context ─────────────────────────────────────
# Key decisions, approach taken, and important context that helps
# a fresh session understand what's been done and what's left.
context: |
  The crash was caused by a null session token when the OAuth
  provider returns an error. Added defensive null checks in the
  login flow and a try-catch wrapper around the token exchange.
  
  Still need to: update the error UI to show a user-friendly message
  instead of a blank screen.

# ─── What's Left (for current phase) ────────────────────────────
remaining_work:
  - "Update error boundary UI in LoginPage component"
  - "Run full test suite"

# ─── Blockers / Questions ────────────────────────────────────────
blockers: []
  # - "Need clarification on error message copy from design team"

# ─── PR & Deployment (filled in Phases 5-7) ──────────────────────
pr_url: ""
pr_number: ""
preview_url: ""
screenshots: []

# ─── Learnings (filled in Phase 7) ───────────────────────────────
learnings: ""
```

### Active Issue Pointer

The `_active.yml` file tracks which issue is currently being worked on:

```yaml
# .agents/state/linear-agent/_active.yml
active_issue: "lin-42"
started_at: "2026-02-26T22:00:00+05:30"
```

If no issue is active, the file is empty or absent.

### State Persistence Rules

> **CRITICAL**: These rules MUST be followed at all times.

1. **Write state after EVERY phase completion**: When a phase finishes, update the state file immediately.
2. **Write state after EVERY significant action**: After commits, file changes, or key decisions — update the state.
3. **Write remaining_work BEFORE starting work**: Before implementing, list what needs to be done. Cross off items as they're completed.
4. **Write context continuously**: After making key decisions or taking non-obvious approaches, update the `context` field.
5. **Never rely on conversation memory alone**: Anything important must be in the state file.
6. **State file is the single source of truth**: If there's a conflict between conversation memory and the state file, the state file wins.

### Resume Protocol

When the agent starts (Phase 0), it MUST check for existing state:

1. **Check for `_active.yml`**:
   - If it exists and points to an issue → **resume that issue**.
   - If it doesn't exist → proceed to Phase 1 (fresh start).

2. **When resuming**, read the state file and:
   - **Tell the user**: 
     > "🔄 **Resuming work on {issue_id}: {title}**
     > 
     > Last session ended at Phase {N} ({phase_status}).
     > Here's where we left off: {context summary}
     > 
     > Remaining work:
     > - {item 1}
     > - {item 2}
     > 
     > Shall I continue, or would you like to do something else?"
   - Checkout the correct branch.
   - Pick up from where `current_phase` and `remaining_work` indicate.

3. **When resuming mid-phase**:
   - Read `remaining_work` to know what's left.
   - Read `context` to understand decisions already made.
   - Read `files_modified` to know what's already been changed.
   - Read `commits` to know what's already been committed.
   - **Do NOT redo completed work**.

### Session Handoff

If the user needs to end a session mid-work:

1. **Save everything to state**:
   - Current phase and status
   - All remaining work items
   - Detailed context of approach and decisions
   - Any uncommitted changes (note in `remaining_work`)
2. **Commit any WIP** (if there are uncommitted changes):
   ```bash
   git add -A
   git commit -m "wip({scope}): {what's in progress}

   Refs: {issue_id}"
   ```
3. **Tell the user**:
   > "💾 **Session saved!** State file updated at `.agents/state/linear-agent/{issue_id}.yml`
   >
   > Next time you run `/linear-agent`, I'll pick up right where we left off."

### State File Maintenance

- **Completed issues**: Keep state files for completed issues (they serve as a log). Mark `phase_status: completed`.
- **Cancelled issues**: Mark `phase_status: cancelled` with a note in `context`.
- **Cleaning up**: The user can delete old state files manually if the directory gets large.

### Schema Validation & Corruption Recovery

> **CRITICAL**: State files can become malformed due to partial writes, crashes, or manual edits. The agent MUST validate before trusting.

**On every state file load**, validate these required fields exist and have valid types:

| Field | Type | Valid Values |
|-------|------|-------------|
| `issue_id` | string | Non-empty |
| `current_phase` | integer | 0–7 |
| `phase_status` | string | `not_started`, `in_progress`, `completed`, `blocked`, `cancelled`, `waiting_approval`, `changes_requested` |
| `branch_name` | string | Non-empty (if phase ≥ 3) |
| `base_branch` | string | Non-empty |

**If validation fails**:

1. **Tell the user**:
   > "⚠️ **State file corrupted**: `.agents/state/linear-agent/{issue_id}.yml`
   >
   > The file could not be loaded properly. This may be due to a crash or partial write.
   >
   > Options:
   > 1. **Restore from backup** — Use `.bak` file if available
   > 2. **Start fresh** — Delete state and begin this issue from scratch
   > 3. **Skip** — Ignore this issue and pick a different one
   >
   > What would you like to do?"

2. **If backup exists** (`.agents/state/linear-agent/{issue_id}.yml.bak`):
   - Validate the backup too.
   - If backup is valid: offer to restore it.
   - If backup is also corrupt: offer fresh start or skip.

3. **Never silently proceed** with a corrupt state file.

### Concurrent Access Protection

> Prevents data corruption when two IDE sessions access the same state file.

**Write Locking Protocol**:

1. **Before writing** any state file, create a lock file:
   ```
   .agents/state/linear-agent/{issue_id}.yml.lock
   ```
   - Lock file contents:
     ```yaml
     locked_by: "{session_identifier}"
     locked_at: "{ISO-8601 timestamp}"
     ```

2. **Before writing**, check if a `.lock` file already exists:
   - If it exists and is **less than 5 minutes old**: **warn the user**:
     > "⚠️ Another session may be writing to this state file. Last locked at {locked_at}. Proceed anyway?"
   - If it exists and is **more than 5 minutes old**: treat as stale, overwrite the lock.
   - If it doesn't exist: create the lock and proceed.

3. **After writing**: delete the `.lock` file.

4. **On crash**: Stale locks (>5 min) are auto-cleaned on next access.

### Backup Strategy

> One bad write should never destroy the entire session context.

**Before every state file write**:

1. **Create a backup** of the current file:
   ```bash
   cp {state_file}.yml {state_file}.yml.bak
   ```

2. **Write the updated state** to the original file.

3. **Validate the write** by re-reading and validating the file:
   - If valid: keep the `.bak` (it will be overwritten next time).
   - If invalid: **restore from backup**:
     ```bash
     cp {state_file}.yml.bak {state_file}.yml
     ```
     - **Inform the user**: "⚠️ State write failed. Restored from backup. Please try again."

4. **Backup files are NOT gitignored** — they live alongside state files in `.agents/state/` (which is already gitignored).

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

**Goal**: Set up the environment, validate everything is ready, and check for resumed work.

### Steps

1. **Load Config**
   - Read `.agents/config/linear-agent.yml`.
   - If missing, create from template and ask user to configure.

2. **Validate Prerequisites**
   - Run `gh auth status` — must be authenticated.
   - Run `git remote -v` — must have a GitHub remote.
   - Test Linear MCP connectivity: call `list_teams`.

3. **🔄 Check for Resumed Work** _(State Management)_
   - Check if `.agents/state/linear-agent/_active.yml` exists.
   - If it does:
     - Read the active issue ID.
     - Read the corresponding state file.
     - Follow the **Resume Protocol** (see State Management section).
     - **Skip to the appropriate phase** based on `current_phase`.
   - If it doesn't: proceed normally (fresh start).

4. **Detect Base Branch**
   - If `base_branch` is not set in config:
     ```bash
     git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
     ```
   - Fallback: check for `main`, then `master`.
   - **Tell the user**: "📋 Detected base branch: `{branch}`"

5. **Sync Local Repo**
   ```bash
   git fetch origin
   git checkout {base_branch}
   git pull origin {base_branch}
   ```
   - **Tell the user**: "✅ Repo synced to latest `{base_branch}`"

6. **Fetch Linear Project Info**
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
     - `label`: filter by `linear_labels` from config (if set)
     - `limit`: use `max_issues_display` from config (default: 20)
   - Sort by priority (configured `priority_order`).

   **Pagination**: If more issues exist than the limit:
   - Fetch only up to `max_issues_display` results.
   - **Tell the user**: "Showing top {N} of {total} issues. Adjust `max_issues_display` in config to see more."

   **Rate Limiting**: If the Linear API returns a 429 (rate limit) error:
   - Wait with **exponential backoff**: 1s → 2s → 4s → 8s (max 3 retries).
   - If still failing after retries, **tell the user** and proceed with whatever results were fetched.

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
   - If `auto_pick_highest: true` in config: automatically select the highest priority issue.
   - Otherwise, ask the user:
     > "Would you like me to **auto-pick** the highest priority issue, or would you like to **choose** one? (Type a number, 'auto', or 'skip' to skip an issue)"
   - **Auto-pick**: Select the first issue by priority order.
   - **Manual pick**: Wait for user to specify a number or issue ID.

4. **Lock the Issue**
   - Once selected, update the Linear issue:
     - Set state to **"In Progress"**
     - Assign to **"me"** (the authenticated user)
   - **Tell the user**: "🚀 Starting work on **{issue_id}: {title}** — marked as In Progress"

5. **📝 Create State File** _(State Management)_
   - Create `.agents/state/linear-agent/{issue_id_lowercase}.yml` with initial values.
   - Create/update `.agents/state/linear-agent/_active.yml` to point to this issue.
   - Set `current_phase: 1`, `phase_status: completed`.

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
    - **Search for patterns** in the codebase to locate relevant code.
    - **Discover files** matching likely names or paths.
    - **View file structures** to understand module organization.
    - _(See [Tool Mapping Table](#tool-mapping) for IDE-specific tool names.)_

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

7. **📝 Update State File** _(State Management)_
   - Update `current_phase: 2`, `phase_status: completed`.
   - Write `remaining_work` with all implementation steps from the plan.
   - Write `context` with the approach summary and key decisions.

---

## Phase 3: Implementation

**Goal**: Write the code, transparently showing every step.

### Steps

1. **Create Feature Branch**
   - Build the branch name using the config's `branch_prefix` (default: `feature/`):
     ```
     {branch_prefix}{issue_id_lowercase}-{slugified_title}
     ```
   - **Slug rules** (applied to `slugified_title`):
     - Lowercase only
     - Replace spaces and special characters with `-`
     - Strip consecutive hyphens
     - Cap at **40 characters** (truncate, don't break mid-word)
   - Example: `feature/lin-42-fix-login-page-crash`
   ```bash
   git checkout {base_branch}
   git pull origin {base_branch}
   git checkout -b {branch_name}
   ```
   - **Tell the user**: "🌿 Created branch: `{branch_name}`"

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

5. **📝 Update State File Continuously** _(State Management)_
   - After **every commit**: update `commits` list in state file.
   - After **every file change**: update `files_modified` list.
   - After **every completed task**: remove from `remaining_work`.
   - After **key decisions**: update `context` with reasoning.
   - Keep `current_phase: 3`, `phase_status: in_progress`.
   - On phase completion: set `phase_status: completed`.

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

5. **📝 Update State File** _(State Management)_
   - Update `current_phase: 4`, `phase_status: completed`.
   - Note quality results in `context`.

---

## Phase 5: Ready for Review

**Goal**: Push the branch, create a PR, notify the user, and wait for approval.

### Steps

1. **Push Branch to GitHub**
   ```bash
   git push origin {branch_name}
   ```
   - **Tell the user**: "📤 Pushed branch to GitHub"

2. **Create Pull Request**
   ```bash
   gh pr create \
     --title "{issue_id}: {issue_title}" \
     --body "{pr_body}" \
     --base {base_branch} \
     --head {branch_name}
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
   - **Check `skip_screenshots`** in config — if `true`, skip this step entirely.
   - **Primary method**: Use the browser subagent to navigate to the relevant pages.
   - **Fallback** (if browser subagent is unavailable):
     ```bash
     npx playwright screenshot http://localhost:{dev_port} screenshot.png 2>/dev/null || true
     ```
   - **Graceful degradation**: If both methods fail:
     - Log: "⚠️ Screenshots could not be captured — continuing without them."
     - **Do NOT block** PR creation or review notification.
   - Save any captured screenshots to the artifacts directory.

5. **Notify on Linear**
   - Update issue state to a review state (e.g., "In Review" or "Ready for Testing")
     - First check available statuses with `list_issue_statuses`
     - Use the closest matching status
   - Add a comment on the Linear issue:
     ```markdown
     🤖 **Agent: Ready for Review**

     **Pull Request**: {pr_url}
     **Branch**: `{branch_name}`

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
   - **Cancel**: Run the **[Abort / Cleanup Procedure](#abort--cleanup-procedure)** below.

8. **📝 Update State File** _(State Management)_
   - Update `current_phase: 5`, `phase_status: completed` (or `waiting_approval`).
   - Record `pr_url`, `pr_number` in state file.
   - If changes requested: set `phase_status: changes_requested`, update `remaining_work`.

---

## Phase 6: Deployment

**Goal**: The PR branch is on GitHub. Deployment is branch-based (merging is manual).

### Steps

1. **Confirm Deployment**
   - **Tell the user**:
     > "🚀 Deploying branch `{branch_name}` to GitHub..."

2. **Ensure Branch is Up-to-Date**
   - **Step 1**: Check for other contributors on the branch:
     ```bash
     git log origin/{branch_name} --format='%ae' | sort -u
     ```
   - **If multiple contributors detected**:
     - ⚠️ **Warn the user**: "This branch has commits from multiple authors. Force pushing after rebase may overwrite their work."
     - **Prefer merge** over rebase:
       ```bash
       git fetch origin {base_branch}
       git merge origin/{base_branch}
       git push origin {branch_name}
       ```
   - **If single contributor (default path)**:
     ```bash
     git fetch origin {base_branch}
     git rebase origin/{base_branch}
     ```
     - Before force pushing, **tell the user**:
       > "⚠️ About to force push (with lease) to `{branch_name}` after rebase. This is safe for single-author branches. Proceed?"
     - On confirmation:
       ```bash
       git push origin {branch_name} --force-with-lease
       ```
   - If merge/rebase conflicts: **stop and ask user for help**.
   - **Config override**: If `prefer_merge_over_rebase: true` is set in config, always use merge instead of rebase.

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
   > - **Branch**: `{branch_name}`
   >
   > The PR is ready for you to merge when you're satisfied. Proceeding to close the Linear issue."

---

## Phase 7: Closure

**Goal**: Close the Linear issue with comprehensive details and learnings.

### Steps

1. **Take Final Screenshots** (if applicable)
   - **Check `skip_screenshots`** in config — if `true`, skip this step entirely.
   - **Primary method**: If there's a preview URL, use the browser subagent to capture screenshots.
   - **Fallback** (if browser subagent is unavailable):
     ```bash
     npx playwright screenshot {preview_url} final-screenshot.png 2>/dev/null || true
     ```
   - **Graceful degradation**: If screenshots fail, note "Screenshots unavailable" in the closure comment and continue.
   - Save any captured screenshots to artifacts.

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
     📌 Branch: `{branch_name}`

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

6. **📝 Finalize State File** _(State Management)_
   - Update `current_phase: 7`, `phase_status: completed`.
   - Record `learnings`, final `screenshots`, `preview_url`.
   - Clear `_active.yml` (remove or empty it) — no active issue.
   - The state file for this issue is kept as a **historical log**.

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

## Abort / Cleanup Procedure

**When to run**: When the user cancels, when implementation fails irrecoverably, or when abandoning an issue mid-work.

> This procedure prevents dangling branches, stuck Linear issues, and orphaned state files.

### Steps

1. **Ask User What to Clean Up**
   - **Tell the user**:
     > "🧹 **Cleanup required.** I'll clean up the following (confirm each):
     > 1. Delete local branch `{branch_name}`
     > 2. Delete remote branch `{branch_name}` (if pushed)
     > 3. Close PR #{pr_number} (if created)
     > 4. Reset Linear issue to 'Todo'
     > 5. Update state file as cancelled
     >
     > Type 'all' to do everything, or specify which items to skip."

2. **Git Branch Cleanup**
   ```bash
   # Switch to base branch first
   git checkout {base_branch}
   
   # Delete local branch
   git branch -D {branch_name}
   
   # Delete remote branch (if it exists)
   git push origin --delete {branch_name} 2>/dev/null || true
   ```

3. **Close PR** (if created)
   ```bash
   gh pr close {pr_number} --comment "Cancelled by Linear Issue Agent" 2>/dev/null || true
   ```

4. **Reset Linear Issue**
   - Move issue back to **"Todo"** status.
   - Remove agent assignment.
   - Add a comment:
     ```markdown
     🤖 **Agent: Issue Cancelled**

     This issue was returned to Todo.
     Reason: {user's reason or "cancelled by user"}

     Any partial work has been cleaned up.
     ```

5. **State File Cleanup**
   - Update the issue's state file: set `phase_status: cancelled`, add cancellation reason to `context`.
   - Clear `_active.yml` (remove or empty it).
   - **Keep** the state file as a historical log (do not delete).

6. **Report to User**
   - **Tell the user**:
     > "🧹 **Cleanup complete!**
     >
     > - ✅ Local branch deleted
     > - ✅ Remote branch deleted
     > - ✅ PR closed
     > - ✅ Linear issue reset to Todo
     > - ✅ State file updated (cancelled)
     >
     > Ready to pick up a different issue, or stop?"

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
| Linear API rate limit (429) | Exponential backoff: 1s → 2s → 4s → 8s. Max 3 retries. Report if still failing. |
| Screenshot capture fails | Log warning, continue without screenshots. Never block PR creation. |

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
