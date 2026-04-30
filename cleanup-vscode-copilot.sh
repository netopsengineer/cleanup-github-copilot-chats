#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=true
INCLUDE_GLOBAL=false

usage() {
  cat <<'EOF'
Usage:
  ./cleanup-vscode-copilot.sh [options]

Options:
  --delete           Move matching folders to ~/.Trash
  --dry-run          Show what would be moved. Default.
  --include-global   Also clean Copilot folders from globalStorage
  -h, --help         Show this help text

Examples:
  ./cleanup-vscode-copilot.sh
  ./cleanup-vscode-copilot.sh --delete
  ./cleanup-vscode-copilot.sh --delete --include-global
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete)
      DRY_RUN=false
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --include-global)
      INCLUDE_GLOBAL=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

timestamp="$(date '+%Y%m%d-%H%M%S')"
trash_root="$HOME/.Trash/vscode-copilot-cleanup-$timestamp"
targets_file="$(mktemp)"

cleanup() {
  rm -f "$targets_file"
}
trap cleanup EXIT

add_target() {
  local path="$1"

  [[ -e "$path" ]] || return 0

  if ! grep -Fxq "$path" "$targets_file" 2>/dev/null; then
    printf '%s\n' "$path" >>"$targets_file"
  fi
}

collect_workspace_targets() {
  local workspace_storage="$1"

  [[ -d "$workspace_storage" ]] || return 0

  find "$workspace_storage" \
    \( \
    -name "chatSessions" \
    -o -name "chatEditingSessions" \
    -o -iname "*copilot*" \
    \) \
    -type d \
    -prune \
    -print 2>/dev/null | while IFS= read -r path; do
    add_target "$path"
  done
}

collect_global_targets() {
  local global_storage="$1"

  [[ -d "$global_storage" ]] || return 0

  find "$global_storage" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -iname "*copilot*" \
    -print 2>/dev/null | while IFS= read -r path; do
    add_target "$path"
  done
}

move_to_trash() {
  local source="$1"
  local relative_path="${source#/}"
  local destination="$trash_root/$relative_path"

  mkdir -p "$(dirname "$destination")"
  mv "$source" "$destination"
}

echo "Checking VS Code Copilot workspace storage..."

collect_workspace_targets "$HOME/Library/Application Support/Code/User/workspaceStorage"
collect_workspace_targets "$HOME/Library/Application Support/Code - Insiders/User/workspaceStorage"

if [[ "$INCLUDE_GLOBAL" == true ]]; then
  collect_global_targets "$HOME/Library/Application Support/Code/User/globalStorage"
  collect_global_targets "$HOME/Library/Application Support/Code - Insiders/User/globalStorage"
fi

if [[ ! -s "$targets_file" ]]; then
  echo "No matching Copilot or chat session folders found."
  exit 0
fi

echo
echo "Matching folders:"
cat "$targets_file"

echo
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run only. Nothing was moved."
  echo
  echo "To move these folders to Trash:"
  echo "  ./cleanup-vscode-copilot.sh --delete"
  echo
  echo "To also include Copilot folders from globalStorage:"
  echo "  ./cleanup-vscode-copilot.sh --delete --include-global"
  exit 0
fi

echo "Moving matching folders to:"
echo "  $trash_root"
echo

while IFS= read -r target; do
  if [[ -e "$target" ]]; then
    echo "Moving: $target"
    move_to_trash "$target"
  fi
done <"$targets_file"

echo
echo "Done. Matching folders were moved to Trash."
