# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-27

### Added
- **Email notifications**: Configurable email alerts via msmtp/sendmail/mail/custom script when human attention is required
- **Email notifications**: Gmail SMTP setup guide with msmtp in SKILL.md
- **Email notifications**: Notifications at Phase 2 (plan approval), Phase 5 (review approval), error escalation, conflict escalation, CI failure
- **Email notifications**: `notification_email`, `notification_method`, `notification_script`, `notify_on.*` config fields
- **Auto error resolution**: Structured retry loop for lint, test, and build failures (up to `max_auto_fix_attempts`, default 3)
- **Auto error resolution**: Progressive fix strategies per check type (auto-fix command → manual analysis → pattern matching)
- **Auto error resolution**: Oscillation detection prevents infinite fix-undo loops
- **Auto error resolution**: `max_auto_fix_attempts`, `lint_fix_command` config fields
- **Proactive local CI**: New Phase 5B runs quality gates locally after PR push, in parallel with GitHub Actions
- **Proactive local CI**: Auto-fixes issues before GH CI reports them, pushes fixes to update PR
- **Proactive local CI**: Monitors GitHub CI status and addresses failures proactively
- **Proactive local CI**: `proactive_local_ci` config field
- **Conflict resolution**: Automatic classification of merge conflicts (imports, whitespace, non-overlapping, lock files, same-line, structural)
- **Conflict resolution**: Auto-resolves simple conflicts (import ordering, whitespace, lock file regeneration)
- **Conflict resolution**: Intelligent merge attempts for same-line modifications using commit context
- **Conflict resolution**: Quality gates re-run after conflict resolution to catch regressions
- **Conflict resolution**: `proactive_conflict_resolution` config field
- **State tracking**: `auto_fix_attempts`, `conflict_resolution`, `notifications_sent`, `sub_phase` fields in state schema
- **Phase 2 checkpoint**: Formalized as a proper STOP-and-wait checkpoint with email notification (was previously auto-proceeding)

### Changed
- **Phase 4**: Completely rewritten with auto-fix loop — agent tries up to 3 fix strategies before escalating to user
- **Phase 5**: Added email notification trigger at the approval checkpoint
- **Phase 6**: Conflict handling upgraded from "stop and ask" to automatic resolution algorithm
- **Error handling table**: Updated all failure scenarios to reflect auto-fix behavior
- **Lifecycle diagram**: Updated to show Phase 5B, conflict resolution, and notification points
- **Workflow file**: Updated step descriptions to reflect new capabilities
- **README**: Updated with new config fields, features, and setup instructions
- **Config template**: Expanded from 115 to 165+ lines with notification and auto-resolution sections

## [1.1.0] - 2026-02-27

### Added
- **Platform compatibility**: Tool Mapping Table for multi-IDE support (Gemini, Claude Code, Cursor, Windsurf)
- **Platform compatibility**: Documented `// turbo-all` directive with IDE compatibility notes
- **State management**: Schema validation & corruption recovery on every state file load
- **State management**: Concurrent access protection via `.lock` files
- **State management**: Backup strategy (`.bak` files) before every state write
- **Git strategy**: Abort / Cleanup Procedure for cancelled or failed work
- **Git strategy**: Force push safeguards with multi-contributor detection
- **Git strategy**: `prefer_merge_over_rebase` config option
- **Resilience**: Screenshot fallback chain (browser subagent → playwright CLI → graceful skip)
- **Resilience**: `skip_screenshots` config option
- **Scalability**: Linear API pagination, rate limiting with exponential backoff
- **Scalability**: `max_issues_display` and `linear_labels` config options
- **Config**: PR settings (`pr_draft`, `pr_reviewers`, `pr_labels`)
- **Config**: `auto_pick_highest` for automatic issue selection
- **Documentation**: Supported IDEs table in README
- **Documentation**: Linear MCP setup guide with verification steps
- **Documentation**: Required auth scopes for GitHub and Linear
- **Repo hygiene**: `.editorconfig` for consistent formatting
- **Repo hygiene**: `CHANGELOG.md` (this file)
- **Repo hygiene**: `LICENSE` (MIT)

### Changed
- **Branch naming**: Standardized to `{branch_prefix}{issue_id}-{slug}` — eliminates double-prefix bug
- **Branch naming**: Added slug sanitization rules (lowercase, 40-char cap, strip special chars)
- **Tool references**: Replaced hardcoded Gemini tool names with capability-based language
- **Phase 1**: Now respects `max_issues_display`, `linear_labels`, and `auto_pick_highest` config
- **Phase 5**: Cancel handler now references the Abort / Cleanup Procedure
- **Phase 6**: Rebase/push now checks for multiple contributors before force pushing
- **README**: Expanded from 87 to 149+ lines with comprehensive setup instructions
- **Config template**: Expanded from 80 to 115+ lines with new sections
- **State schema**: `phase_status` now includes `cancelled`, `waiting_approval`, `changes_requested`

### Fixed
- **Branch naming**: Fixed potential `feature/feature/` double-prefix in PR creation and deployment phases

## [1.0.0] - 2026-02-26

### Added
- Initial release of Linear Issue Agent
- 8-phase lifecycle: Init → Discover → Plan → Implement → Quality Gate → Review → Deploy → Close
- State management with YAML-based session persistence
- Configurable per-repository settings
- Linear MCP integration for issue management
- GitHub CLI integration for PR creation
- Conventional commit message format
- Human-in-the-loop approval gates
