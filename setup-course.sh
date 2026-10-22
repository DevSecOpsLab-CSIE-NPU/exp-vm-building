#!/usr/bin/env bash
# setup-course.sh - first-boot setup for the AI coding lab VM.
#
# Idempotent: safe to run more than once.
# Stores no secrets in the image. The OpenRouter key is entered at run time
# and kept in a chmod 600 file under $HOME.
#
# Usage:
#   ./setup-course.sh
#
# Optional overrides:
#   COURSE_REPO=owner/name COURSE_DIR=$HOME/ai-coding-lab ./setup-course.sh

set -euo pipefail

# TODO: replace with the real course repository (owner/name, used by `gh repo clone`).
COURSE_REPO="${COURSE_REPO:-DevSecOpsLab-CSIE-NPU/exp-vm-building}"
COURSE_DIR="${COURSE_DIR:-$HOME/ai-coding-lab}"

ENV_DIR="$HOME/.config/ai-coding"
ENV_FILE="$ENV_DIR/env"
LOCAL_BIN="$HOME/.local/bin"

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

check_prereqs() {
  log "Checking prerequisites"
  local missing=()
  local cmd
  for cmd in git gh curl php sqlite3 node npm; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    die "missing: ${missing[*]} (install with: sudo apt install -y git gh curl sqlite3 php-cli php-sqlite3 nodejs npm)"
  fi
  echo "All prerequisites found."
}

ensure_shell_hooks() {
  log "Updating ~/.bashrc"
  local line
  local lines=(
    'export PATH="$HOME/.local/bin:$PATH"'
    '[ -f "$HOME/.config/ai-coding/env" ] && . "$HOME/.config/ai-coding/env"'
  )
  touch "$HOME/.bashrc"
  for line in "${lines[@]}"; do
    grep -qxF "$line" "$HOME/.bashrc" || echo "$line" >> "$HOME/.bashrc"
  done
  # Make the current script run see the new PATH as well.
  export PATH="$LOCAL_BIN:$PATH"
}

install_opencode() {
  log "Installing or updating OpenCode"
  # Installs under ~/.local, so no sudo is needed.
  # TODO: confirm the package name and install method against the current
  # OpenCode documentation before the class. The official install script
  # is an alternative.
  npm install -g --prefix "$HOME/.local" opencode-ai@latest
  if command -v opencode >/dev/null 2>&1; then
    echo "opencode: $(opencode --version 2>/dev/null || echo 'installed')"
  else
    die "opencode not found on PATH after install (check $LOCAL_BIN)"
  fi
}

setup_api_key() {
  log "OpenRouter API key"
  if [ -s "$ENV_FILE" ] && grep -q '^export OPENROUTER_API_KEY=' "$ENV_FILE"; then
    echo "Already configured at $ENV_FILE. Delete that file to re-enter the key."
    return
  fi
  if [ ! -t 0 ]; then
    warn "No terminal attached; skipping the key prompt. Re-run this script in a terminal."
    return
  fi

  local key=""
  read -r -s -p "Paste your OpenRouter API key (input is hidden, Enter to skip): " key
  echo
  if [ -z "$key" ]; then
    warn "No key entered; skipping. OpenCode will not work until a key is set."
    return
  fi

  mkdir -p "$ENV_DIR"
  (
    umask 077
    printf 'export OPENROUTER_API_KEY=%q\n' "$key" > "$ENV_FILE"
  )
  chmod 600 "$ENV_FILE"
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  echo "Saved to $ENV_FILE (mode 600)."
}

setup_github() {
  log "GitHub login"
  if gh auth status >/dev/null 2>&1; then
    echo "Already logged in to GitHub."
    return 0
  fi
  if [ -t 0 ]; then
    echo "Starting 'gh auth login' (follow the prompts)."
    gh auth login || warn "gh auth login did not complete. Re-run later with: gh auth login"
  else
    warn "Not logged in. Run: gh auth login"
  fi
  gh auth status >/dev/null 2>&1
}

clone_course() {
  log "Cloning the course repository"
  if [ -d "$COURSE_DIR/.git" ]; then
    echo "Already cloned at $COURSE_DIR. Pulling latest."
    git -C "$COURSE_DIR" pull --ff-only || warn "git pull failed; check your network or local changes."
    return
  fi
  if ! gh auth status >/dev/null 2>&1; then
    warn "Not logged in to GitHub; cannot clone $COURSE_REPO yet. Run gh auth login, then re-run this script."
    return
  fi
  gh repo clone "$COURSE_REPO" "$COURSE_DIR"
}

print_summary() {
  log "Done"
  cat <<EOF
Next steps:
  1. Open a new terminal (or run: source ~/.bashrc) so PATH and the API key load.
  2. cd $COURSE_DIR
  3. opencode
EOF
}

main() {
  check_prereqs
  ensure_shell_hooks
  install_opencode
  setup_api_key
  setup_github
  clone_course
  print_summary
}

main "$@"
