#!/usr/bin/env bash
set -euo pipefail

resolve_source() {
  local source="$1"
  while [[ -L "$source" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ "$source" != /* ]] && source="$dir/$source"
  done
  printf '%s\n' "$(cd -P "$(dirname "$source")" && pwd)/$(basename "$source")"
}

BIN_DIR="$(cd "$(dirname "$(resolve_source "${BASH_SOURCE[0]}")")" && pwd)"
SCRIPT_DIR="$BIN_DIR/paste-harness"
LIB="$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  paste-harness run all     Run tmux then gui layers
  paste-harness run tmux    Headless tmux C-v paste test
  paste-harness run gui     GUI keystroke test (run from iTerm; needs Accessibility)
  paste-harness probe       Interactive byte logger (Ctrl+V then Enter)

Environment:
  PASTE_HARNESS_APP=Cursor|Code   Target editor for gui layer (default: Cursor)
  PASTE_HARNESS_TRIES=3           Headless retry count
  PASTE_HARNESS_GUI_TRIES=10      GUI success count required
EOF
}

if [[ ! -f "$LIB" ]]; then
  echo "paste-harness: missing lib at $LIB" >&2
  exit 1
fi

# shellcheck source=paste-harness/lib.sh
source "$LIB"

cmd="${1:-}"
sub="${2:-}"

case "$cmd" in
  run)
    case "$sub" in
      tmux)
        exec "$SCRIPT_DIR/run-tmux.sh"
        ;;
      gui)
        exec "$SCRIPT_DIR/run-gui.sh"
        ;;
      all)
        "$SCRIPT_DIR/run-tmux.sh" && "$SCRIPT_DIR/run-gui.sh"
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    ;;
  probe)
    exec python3 "$SCRIPT_DIR/probe.py" "${@:2}"
    ;;
  -h|--help|help|"")
    usage
    [[ -z "$cmd" ]] && exit 1
    ;;
  *)
    usage
    exit 1
    ;;
esac
