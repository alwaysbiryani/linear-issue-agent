#!/usr/bin/env bash
# ==============================================================================
# Linear Issue Agent — Interactive Setup Script
# ==============================================================================
#
# Usage:
#   ./setup.sh [/path/to/your/project]
#
# This script guides you through:
#   1. Copying agent files into your project
#   2. Configuring your Linear project & team
#   3. Setting up email notifications via Gmail SMTP (optional)
#
# ==============================================================================

set -euo pipefail

# ─── Colors & Formatting ────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${BLUE}→${NC} $1"; }
step() { echo -e "\n${BOLD}${CYAN}[$1]${NC} ${BOLD}$2${NC}"; }

prompt() {
  local message="$1"
  local default="${2:-}"
  if [[ -n "$default" ]]; then
    echo -en "  ${message} ${DIM}(${default})${NC}: "
  else
    echo -en "  ${message}: "
  fi
}

confirm() {
  local message="$1"
  local default="${2:-n}"
  if [[ "$default" == "y" ]]; then
    echo -en "  ${message} ${DIM}[Y/n]${NC}: "
  else
    echo -en "  ${message} ${DIM}[y/N]${NC}: "
  fi
  read -r answer
  answer="${answer:-$default}"
  # macOS bash 3 compatible lowercase conversion
  answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
  [[ "$answer" == "y" || "$answer" == "yes" ]]
}

# ─── Resolve Script Directory ───────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify this script is in the linear-issue-agent repo
if [[ ! -d "$SCRIPT_DIR/.agents/skills/linear-agent" ]]; then
  fail "Cannot find .agents/skills/linear-agent/ relative to this script."
  fail "Make sure you're running this from the linear-issue-agent repo root."
  exit 1
fi

# ─── Header ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║        🤖 Linear Issue Agent — Setup Wizard         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  This wizard will set up the Linear Issue Agent in your project."
echo -e "  Each step is optional — press ${DIM}Enter${NC} to skip any prompt."

# ==============================================================================
# STEP 1: Copy agent files into target project
# ==============================================================================

step "1/3" "Copy agent files into your project"

TARGET_DIR="${1:-}"

if [[ -z "$TARGET_DIR" ]]; then
  echo ""
  prompt "Path to your project (absolute or relative)"
  read -r TARGET_DIR
fi

if [[ -z "$TARGET_DIR" ]]; then
  fail "No project path provided. Exiting."
  exit 1
fi

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
  fail "Directory does not exist: $TARGET_DIR"
  exit 1
}

# Don't install into self
if [[ "$TARGET_DIR" == "$SCRIPT_DIR" ]]; then
  fail "Target project cannot be the same as this repo."
  exit 1
fi

# Verify it's a git repo
if [[ ! -d "$TARGET_DIR/.git" ]]; then
  fail "$TARGET_DIR is not a git repository."
  echo -e "  ${DIM}Run 'git init' in your project first, then re-run this script.${NC}"
  exit 1
fi

ok "Target project: $TARGET_DIR"

# Check for existing .agents/ directory
if [[ -d "$TARGET_DIR/.agents" ]]; then
  warn "An .agents/ directory already exists in the target project."
  echo ""
  if confirm "Overwrite existing agent files? (config will be preserved)"; then
    info "Will overwrite skill & workflow files, but preserve existing config."
  else
    fail "Setup cancelled. Existing files left untouched."
    exit 0
  fi
fi

# Create directory structure
mkdir -p "$TARGET_DIR/.agents/skills/linear-agent"
mkdir -p "$TARGET_DIR/.agents/workflows"
mkdir -p "$TARGET_DIR/.agents/config"

# Copy skill files
cp "$SCRIPT_DIR/.agents/skills/linear-agent/SKILL.md" \
   "$TARGET_DIR/.agents/skills/linear-agent/SKILL.md"
ok "Copied SKILL.md"

cp "$SCRIPT_DIR/.agents/skills/linear-agent/config.template.yml" \
   "$TARGET_DIR/.agents/skills/linear-agent/config.template.yml"
ok "Copied config.template.yml"

# Copy workflow file
cp "$SCRIPT_DIR/.agents/workflows/linear-agent.md" \
   "$TARGET_DIR/.agents/workflows/linear-agent.md"
ok "Copied workflow: linear-agent.md"

# Create config from template (only if it doesn't exist)
CONFIG_FILE="$TARGET_DIR/.agents/config/linear-agent.yml"
if [[ ! -f "$CONFIG_FILE" ]]; then
  cp "$SCRIPT_DIR/.agents/skills/linear-agent/config.template.yml" "$CONFIG_FILE"
  ok "Created config: .agents/config/linear-agent.yml"
else
  ok "Config already exists — preserving: .agents/config/linear-agent.yml"
fi

# Add .agents/state/ to .gitignore
GITIGNORE="$TARGET_DIR/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -qF '.agents/state/' "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Linear Issue Agent state files (session data, not for version control)" >> "$GITIGNORE"
    echo ".agents/state/" >> "$GITIGNORE"
    ok "Added .agents/state/ to .gitignore"
  else
    ok ".agents/state/ already in .gitignore"
  fi
else
  echo "# Linear Issue Agent state files (session data, not for version control)" > "$GITIGNORE"
  echo ".agents/state/" >> "$GITIGNORE"
  ok "Created .gitignore with .agents/state/"
fi

ok "Agent files installed successfully!"

# ==============================================================================
# STEP 2: Configure Linear project & team
# ==============================================================================

step "2/3" "Configure Linear project & team"

echo ""
echo -e "  ${DIM}Find your project name in Linear's sidebar or URL.${NC}"
echo -e "  ${DIM}Find your team name/key in Linear → Settings → Teams.${NC}"
echo ""

# Linear project
prompt "Linear project name (e.g., 'My App' or 'MY-APP')"
read -r LINEAR_PROJECT

if [[ -n "$LINEAR_PROJECT" ]]; then
  # Escape special characters for sed
  ESCAPED_PROJECT=$(printf '%s\n' "$LINEAR_PROJECT" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/^linear_project: \".*\"/linear_project: \"${ESCAPED_PROJECT}\"/" "$CONFIG_FILE"
  ok "Set linear_project: \"$LINEAR_PROJECT\""
else
  warn "Skipped — you'll need to set linear_project manually in the config."
fi

# Linear team
prompt "Linear team name or key (e.g., 'Engineering' or 'ENG')"
read -r LINEAR_TEAM

if [[ -n "$LINEAR_TEAM" ]]; then
  ESCAPED_TEAM=$(printf '%s\n' "$LINEAR_TEAM" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/^linear_team: \".*\"/linear_team: \"${ESCAPED_TEAM}\"/" "$CONFIG_FILE"
  ok "Set linear_team: \"$LINEAR_TEAM\""
else
  warn "Skipped — you'll need to set linear_team manually in the config."
fi

# Optional: Project commands
echo ""
echo -e "  ${DIM}Optional: Configure project commands (press Enter to skip any).${NC}"
echo ""

prompt "Dev server command (e.g., 'npm run dev')"
read -r DEV_CMD
if [[ -n "$DEV_CMD" ]]; then
  ESCAPED_CMD=$(printf '%s\n' "$DEV_CMD" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/^dev_command: \".*\"/dev_command: \"${ESCAPED_CMD}\"/" "$CONFIG_FILE"
  ok "Set dev_command: \"$DEV_CMD\""
fi

prompt "Test command (e.g., 'npm test')"
read -r TEST_CMD
if [[ -n "$TEST_CMD" ]]; then
  ESCAPED_CMD=$(printf '%s\n' "$TEST_CMD" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/^test_command: \".*\"/test_command: \"${ESCAPED_CMD}\"/" "$CONFIG_FILE"
  ok "Set test_command: \"$TEST_CMD\""
fi

prompt "Lint command (e.g., 'npm run lint')"
read -r LINT_CMD
if [[ -n "$LINT_CMD" ]]; then
  ESCAPED_CMD=$(printf '%s\n' "$LINT_CMD" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/^lint_command: \".*\"/lint_command: \"${ESCAPED_CMD}\"/" "$CONFIG_FILE"
  ok "Set lint_command: \"$LINT_CMD\""
fi

prompt "Build command (e.g., 'npm run build')"
read -r BUILD_CMD
if [[ -n "$BUILD_CMD" ]]; then
  ESCAPED_CMD=$(printf '%s\n' "$BUILD_CMD" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/^build_command: \".*\"/build_command: \"${ESCAPED_CMD}\"/" "$CONFIG_FILE"
  ok "Set build_command: \"$BUILD_CMD\""
fi

prompt "Lint auto-fix command (e.g., 'npm run lint -- --fix')"
read -r LINT_FIX_CMD
if [[ -n "$LINT_FIX_CMD" ]]; then
  ESCAPED_CMD=$(printf '%s\n' "$LINT_FIX_CMD" | sed 's/[&/\]/\\&/g')
  sed -i.bak "s/^lint_fix_command: \".*\"/lint_fix_command: \"${ESCAPED_CMD}\"/" "$CONFIG_FILE"
  ok "Set lint_fix_command: \"$LINT_FIX_CMD\""
fi

# Clean up sed backup files
rm -f "$CONFIG_FILE.bak"

ok "Linear configuration complete!"

# ==============================================================================
# STEP 3: Gmail SMTP setup (optional)
# ==============================================================================

step "3/3" "Email notifications via Gmail SMTP (optional)"

echo ""
echo -e "  ${DIM}Get notified by email when the agent needs your attention.${NC}"
echo -e "  ${DIM}Requires a Gmail account and an App Password.${NC}"
echo ""

if confirm "Set up email notifications? (recommended)" "n"; then

  # ── Check for msmtp ──
  if command -v msmtp &>/dev/null; then
    ok "msmtp is already installed: $(command -v msmtp)"
  else
    warn "msmtp is not installed."

    # Detect OS and offer to install
    if [[ "$(uname)" == "Darwin" ]]; then
      if confirm "Install msmtp via Homebrew?" "y"; then
        info "Running: brew install msmtp"
        brew install msmtp
        if command -v msmtp &>/dev/null; then
          ok "msmtp installed successfully!"
        else
          fail "msmtp installation failed. You can install it manually: brew install msmtp"
          warn "Skipping email setup."
          SKIP_EMAIL=true
        fi
      else
        warn "Skipping email setup. Install msmtp later: brew install msmtp"
        SKIP_EMAIL=true
      fi
    elif [[ "$(uname)" == "Linux" ]]; then
      if confirm "Install msmtp via apt?" "y"; then
        info "Running: sudo apt install -y msmtp"
        sudo apt install -y msmtp
        if command -v msmtp &>/dev/null; then
          ok "msmtp installed successfully!"
        else
          fail "msmtp installation failed. You can install it manually: sudo apt install msmtp"
          warn "Skipping email setup."
          SKIP_EMAIL=true
        fi
      else
        warn "Skipping email setup. Install msmtp later: sudo apt install msmtp"
        SKIP_EMAIL=true
      fi
    else
      fail "Unsupported OS for automatic msmtp installation."
      echo -e "  ${DIM}Install msmtp manually, then re-run this script.${NC}"
      SKIP_EMAIL=true
    fi
  fi

  if [[ "${SKIP_EMAIL:-false}" != "true" ]]; then

    # ── Get Gmail address ──
    echo ""
    prompt "Your Gmail address"
    read -r GMAIL_ADDRESS

    if [[ -z "$GMAIL_ADDRESS" ]]; then
      warn "No email provided. Skipping email setup."
    else

      # ── Generate App Password ──
      echo ""
      echo -e "  ${BOLD}Gmail App Password Setup${NC}"
      echo -e "  ${DIM}────────────────────────${NC}"
      echo -e "  You need a Gmail App Password (NOT your regular password)."
      echo -e "  ${DIM}Steps:${NC}"
      echo -e "    1. Go to ${CYAN}https://myaccount.google.com/apppasswords${NC}"
      echo -e "    2. Sign in to your Google account"
      echo -e "    3. Enter app name: ${BOLD}Linear Agent${NC}"
      echo -e "    4. Click ${BOLD}Create${NC} and copy the 16-character password"
      echo ""

      # Try to open the URL in the browser
      if [[ "$(uname)" == "Darwin" ]]; then
        open "https://myaccount.google.com/apppasswords" 2>/dev/null && \
          info "Opened App Password page in your browser." || true
      elif command -v xdg-open &>/dev/null; then
        xdg-open "https://myaccount.google.com/apppasswords" 2>/dev/null && \
          info "Opened App Password page in your browser." || true
      fi

      echo ""
      prompt "Paste your 16-character App Password (spaces are ok)"
      read -rs APP_PASSWORD
      echo ""

      if [[ -z "$APP_PASSWORD" ]]; then
        warn "No password provided. Skipping msmtp config."
        warn "You can set it up later — see SKILL.md 'Notification System' section."
      else
        # Remove spaces from the app password
        APP_PASSWORD="${APP_PASSWORD// /}"

        # ── Create or update ~/.msmtprc ──
        MSMTPRC="$HOME/.msmtprc"

        if [[ -f "$MSMTPRC" ]]; then
          warn "~/.msmtprc already exists."
          if confirm "Back up and replace it?" "y"; then
            cp "$MSMTPRC" "${MSMTPRC}.backup.$(date +%Y%m%d%H%M%S)"
            ok "Backed up existing config."
          else
            warn "Keeping existing ~/.msmtprc. Skipping msmtp config."
            APP_PASSWORD=""
          fi
        fi

        if [[ -n "$APP_PASSWORD" ]]; then
          cat > "$MSMTPRC" << MSMTPRC_EOF
# Linear Issue Agent — Gmail SMTP Configuration
# Generated by setup.sh on $(date +%Y-%m-%d)

defaults
auth           on
tls            on
tls_trust_file /etc/ssl/cert.pem
logfile        ~/.msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           ${GMAIL_ADDRESS}
user           ${GMAIL_ADDRESS}
password       ${APP_PASSWORD}

account default : gmail
MSMTPRC_EOF

          chmod 600 "$MSMTPRC"
          ok "Created ~/.msmtprc with Gmail SMTP config"
          ok "Set permissions: chmod 600"

          # ── Send test email ──
          echo ""
          if confirm "Send a test email to $GMAIL_ADDRESS?" "y"; then
            info "Sending test email..."
            if printf "To: %s\nSubject: [Linear Agent] Setup Complete\nContent-Type: text/plain\n\nYour Linear Issue Agent email notifications are working!\n\nThis is a test message from the setup script.\n" \
              "$GMAIL_ADDRESS" | msmtp "$GMAIL_ADDRESS" 2>/dev/null; then
              ok "Test email sent! Check your inbox."
            else
              fail "Test email failed. Check ~/.msmtp.log for details."
              warn "Common fixes: verify App Password, check internet connection."
            fi
          fi

          # ── Update config file ──
          ESCAPED_EMAIL=$(printf '%s\n' "$GMAIL_ADDRESS" | sed 's/[&/\]/\\&/g')
          sed -i.bak "s/^notification_email: \".*\"/notification_email: \"${ESCAPED_EMAIL}\"/" "$CONFIG_FILE"
          rm -f "$CONFIG_FILE.bak"
          ok "Set notification_email in config: \"$GMAIL_ADDRESS\""
        fi
      fi
    fi
  fi
else
  info "Skipped email notifications. You can set this up later."
fi

# ==============================================================================
# Validation & Summary
# ==============================================================================

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║               ✅ Setup Complete!                     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Prerequisites check ──
echo -e "${BOLD}Prerequisites:${NC}"

# GitHub CLI
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null 2>&1; then
    ok "GitHub CLI: authenticated"
  else
    warn "GitHub CLI: installed but not authenticated"
    echo -e "    ${DIM}Run: gh auth login${NC}"
  fi
else
  fail "GitHub CLI: not installed"
  echo -e "    ${DIM}Install: brew install gh${NC}"
fi

# Git remote
if git -C "$TARGET_DIR" remote get-url origin &>/dev/null 2>&1; then
  ok "Git remote: configured"
else
  warn "Git remote: no 'origin' remote found"
  echo -e "    ${DIM}Run: git remote add origin <your-github-repo-url>${NC}"
fi

# Linear MCP
echo ""
warn "Linear MCP: cannot auto-detect — verify manually"
echo -e "    ${DIM}Add to your IDE's MCP config:${NC}"
echo -e "    ${CYAN}npx mcp-remote https://mcp.linear.app/sse${NC}"
echo -e "    ${DIM}Then verify: ask your AI IDE \"List my Linear teams\"${NC}"

# ── Summary ──
echo ""
echo -e "${BOLD}What was set up:${NC}"
echo ""
ok "Agent files → $TARGET_DIR/.agents/"

if [[ -n "${LINEAR_PROJECT:-}" ]]; then
  ok "Linear project: \"$LINEAR_PROJECT\""
else
  warn "Linear project: not configured"
fi

if [[ -n "${LINEAR_TEAM:-}" ]]; then
  ok "Linear team: \"$LINEAR_TEAM\""
else
  warn "Linear team: not configured"
fi

if [[ -n "${GMAIL_ADDRESS:-}" && -n "${APP_PASSWORD:-}" ]]; then
  ok "Email notifications: $GMAIL_ADDRESS"
else
  info "Email notifications: not configured"
fi

# ── Config location ──
echo ""
echo -e "${BOLD}Config file:${NC}"
echo -e "  ${CYAN}$CONFIG_FILE${NC}"
echo -e "  ${DIM}Edit this file to customize all agent settings.${NC}"

# ── Next steps ──
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo -e "  1. Open your project in your AI IDE"
echo -e "  2. Run ${CYAN}/linear-agent${NC} or say ${CYAN}\"Work on my Linear issues\"${NC}"
echo -e "  3. The agent will pick up To-Do issues and start working!"
echo ""
