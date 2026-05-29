#!/usr/bin/env bash
set -euo pipefail

CLOG_REPO="https://github.com/eimaj/clog"
INSTALL_PATH=""
DRY_RUN=false

usage() {
  echo "Usage: install-clog.sh --path <dir> [--dry-run]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)     INSTALL_PATH="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    *)          echo "Unknown argument: $1" >&2; usage ;;
  esac
done

run() {
  if "$DRY_RUN"; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

info() { echo "==> $*"; }

# Idempotency check
if command -v clog &>/dev/null; then
  info "clog already installed at $(command -v clog) — nothing to do"
  exit 0
fi
if [ -x "$HOME/.claude/hooks/clog.sh" ]; then
  info "clog already installed at ~/.claude/hooks/clog.sh — nothing to do"
  exit 0
fi

if [ -z "$INSTALL_PATH" ]; then
  echo "Error: --path <dir> is required when clog is not already installed." >&2
  usage
fi

info "Cloning clog into $INSTALL_PATH"
run git clone "$CLOG_REPO" "$INSTALL_PATH"

info "Running upstream setup"
run bash "$INSTALL_PATH/setup.sh"

info "Symlinking clog to ~/.claude/hooks/clog.sh"
run mkdir -p "$HOME/.claude/hooks"
run ln -sfn "$INSTALL_PATH/bin/clog" "$HOME/.claude/hooks/clog.sh"

info "done — orchestrator will auto-detect clog on next run"
