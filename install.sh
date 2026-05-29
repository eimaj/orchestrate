#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
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
warn() { echo "WARN: $*" >&2; }

link() {
  local target="$1"
  local link="$2"
  local link_dir
  link_dir="$(dirname "$link")"

  if [ ! -d "$link_dir" ]; then
    info "mkdir -p $link_dir"
    run mkdir -p "$link_dir"
  fi

  if [ -e "$link" ] || [ -L "$link" ]; then
    warn "$link already exists — skipping (remove manually to relink)"
    return
  fi

  info "ln -sfn $target $link"
  run ln -sfn "$target" "$link"
}

info "Installing orchestrate into ~/.claude"
"$DRY_RUN" && info "(dry-run mode — no changes will be made)"

link "$REPO_ROOT/skills/orchestrate"           "$HOME/.claude/skills/orchestrate"
link "$REPO_ROOT/skills/orchestrate-manifest"  "$HOME/.claude/skills/orchestrate-manifest"
link "$REPO_ROOT/skills/orchestrate-recipe"    "$HOME/.claude/skills/orchestrate-recipe"
link "$REPO_ROOT/skills/orchestrate-agent"     "$HOME/.claude/skills/orchestrate-agent"

# Create local config from example if not already present
if [ -f "$REPO_ROOT/config.json" ]; then
  info "config.json already exists — skipping"
elif "$DRY_RUN"; then
  info "cp $REPO_ROOT/config.example.json $REPO_ROOT/config.json"
else
  info "Creating config.json from config.example.json"
  cp "$REPO_ROOT/config.example.json" "$REPO_ROOT/config.json"
  info "Edit $REPO_ROOT/config.json to set artifact_root"
fi

info "Done."
