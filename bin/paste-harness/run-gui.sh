#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

paste_harness_require_cmd osascript pbcopy tmux

APP_NAME="${PASTE_HARNESS_APP:-Cursor}"
TRIES="${PASTE_HARNESS_GUI_TRIES:-10}"
MARKER=""
SESSION=""
PROBE_FILE=""

cleanup() {
  if [[ -n "$SESSION" ]]; then
    paste_harness_cleanup_session "$SESSION"
  fi
  [[ -n "$PROBE_FILE" && -f "$PROBE_FILE" ]] && rm -f "$PROBE_FILE"
}
trap cleanup EXIT

focus_and_paste() {
  local err_file
  err_file="$(mktemp)"
  if osascript <<EOF 2>"$err_file"
tell application "$APP_NAME" to activate
delay 0.4
tell application "System Events"
  tell process "$APP_NAME"
    set frontmost to true
    keystroke "v" using control down
  end tell
end tell
EOF
  then
    rm -f "$err_file"
    return 0
  fi
  if grep -q 'not allowed to send keystrokes' "$err_file" 2>/dev/null; then
    paste_harness_log "Grant Accessibility to iTerm and osascript (System Settings → Privacy & Security → Accessibility)."
    paste_harness_log "Then run from iTerm: paste-harness run gui"
  else
    paste_harness_log "osascript error:"
    cat "$err_file" >&2
  fi
  rm -f "$err_file"
  return 1
}

run_gui_layer() {
  local attempt pane_content passed=0

  MARKER="$(paste_harness_marker)"
  SESSION="paste-harness-gui-$$"
  PROBE_FILE="/tmp/paste-harness-gui-$$.txt"

  printf '%s' "$MARKER" | pbcopy

  osascript <<EOF >/dev/null
tell application "$APP_NAME" to activate
delay 0.5
tell application "System Events"
  tell process "$APP_NAME"
    keystroke "\`" using control down
  end tell
end tell
EOF

  sleep 0.8

  tmux new-session -d -s "$SESSION" -x 120 -y 20 "bash -lc 'cat > \"$PROBE_FILE\"'"
  sleep 0.3

  for attempt in $(seq 1 "$TRIES"); do
    focus_and_paste || {
      paste_harness_fail "osascript keystroke failed (grant Accessibility to iTerm/osascript)"
      return 1
    }
    sleep 0.5
    pane_content="$(tmux capture-pane -p -t "$SESSION" -S -50 2>/dev/null || true)"
    if printf '%s' "$pane_content" | grep -Fq "$MARKER"; then
      passed=$((passed + 1))
      paste_harness_log "gui attempt $attempt/$TRIES: marker visible in tmux pane"
    else
      paste_harness_log "gui attempt $attempt/$TRIES: marker missing"
      printf '%s\n' "$pane_content" >&2
    fi
    printf '%s' "$MARKER" | pbcopy
    tmux send-keys -t "$SESSION" C-u
    sleep 0.1
  done

  if [[ "$passed" -eq "$TRIES" ]]; then
    paste_harness_pass "gui layer $passed/$TRIES via $APP_NAME"
    return 0
  fi

  paste_harness_fail "gui layer $passed/$TRIES passed (need $TRIES/$TRIES)"
  return 1
}

run_gui_layer
