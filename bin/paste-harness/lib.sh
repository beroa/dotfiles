#!/usr/bin/env bash
set -euo pipefail

paste_harness_log() {
  printf '[paste-harness] %s\n' "$*" >&2
}

paste_harness_fail() {
  paste_harness_log "FAIL: $*"
  return 1
}

paste_harness_pass() {
  paste_harness_log "PASS: $*"
}

paste_harness_require_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      paste_harness_fail "required command not found: $cmd"
      exit 1
    fi
  done
}

paste_harness_marker() {
  printf 'PASTE_TEST_%s_%s' "$RANDOM" "$(date +%s)"
}

paste_harness_assert_c_v_bind() {
  local keys expected_script
  expected_script="${1:-tmux-paste-from-clipboard}"
  keys="$(tmux list-keys -T root 2>/dev/null || true)"
  if ! printf '%s\n' "$keys" | grep -Fq 'C-v'; then
    paste_harness_fail "tmux root table has no C-v binding"
    return 1
  fi
  if ! printf '%s\n' "$keys" | grep 'C-v' | grep -Fq "tmux-paste-from-clipboard"; then
    paste_harness_fail "C-v bind does not reference $expected_script"
    printf '%s\n' "$keys" | grep 'C-v' >&2 || true
    return 1
  fi
  paste_harness_pass "tmux C-v bind references $expected_script"
}

paste_harness_cleanup_session() {
  local session="$1"
  tmux kill-session -t "$session" 2>/dev/null || true
}
