# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
