# Paste harness

Diagnose and verify Ctrl+V paste through VS Code/Cursor integrated terminal and tmux.

## Commands

```bash
paste-harness run tmux    # headless; agent-safe, no Accessibility needed
paste-harness run gui     # drives Cursor/VS Code; run from iTerm
paste-harness run all     # both layers
paste-harness probe       # interactive byte logger (Ctrl+V, then Enter)
```

## One-time setup

1. Run `~/dotfiles/setup.sh` (or ensure `~/.local/bin` is on PATH).
2. Reload Cursor/VS Code window after keybinding changes.
3. `tmux source-file ~/.tmux.conf` or `Prefix+r`.
4. For GUI tests: **System Settings → Privacy & Security → Accessibility** → enable **iTerm** and **osascript**.

## GUI layer

Run from **iTerm** (not Cursor's agent terminal):

```bash
paste-harness run gui
# or target VS Code:
PASTE_HARNESS_APP=Code paste-harness run gui
```

## Logs

- `/tmp/tmux-paste.log` — tmux clipboard paste script
- `/tmp/paste-probe-bytes.log` — probe output
