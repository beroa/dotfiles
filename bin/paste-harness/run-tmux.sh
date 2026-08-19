#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

paste_harness_require_cmd tmux pbcopy

run_tmux_layer() {
  local marker session pane_content attempts attempt

  marker="$(paste_harness_marker)"
  session="paste-harness-$$"
  attempts="${PASTE_HARNESS_TRIES:-3}"

  paste_harness_assert_c_v_bind "tmux-paste-from-clipboard" || return 1

  printf '%s' "$marker" | pbcopy

  tmux new-session -d -s "$session" -x 120 -y 20
  sleep 0.15
  pane_id="$(tmux list-panes -t "$session" -F '#{pane_id}' | head -1)"

  for attempt in $(seq 1 "$attempts"); do
    # send-keys C-v delivers ^V to the shell; it does not invoke tmux root binds.
    # Exercise the same pipeline the C-v bind uses (run-shell → tmux-paste-from-clipboard).
    TMUX_PANE="$pane_id" "$HOME/.local/bin/tmux-paste-from-clipboard" || true
    sleep 0.35
    pane_content="$(tmux capture-pane -p -t "$session" -S -50 2>/dev/null || true)"
    if printf '%s' "$pane_content" | grep -Fq "$marker"; then
      paste_harness_cleanup_session "$session"
      paste_harness_pass "tmux layer ($marker) attempt=$attempt"
      return 0
    fi
    paste_harness_log "attempt $attempt/$attempts: marker not in pane yet"
  done

  paste_harness_log "last pane capture:"
  printf '%s\n' "$pane_content" >&2
  paste_harness_log "tmux paste log tail:"
  tail -n 20 /tmp/tmux-paste.log 2>/dev/null >&2 || true
  paste_harness_cleanup_session "$session"
  paste_harness_fail "tmux layer: expected marker $marker in pane"
  return 1
}

run_tmux_layer
