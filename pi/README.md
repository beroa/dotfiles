# Pi configuration

This directory contains the shareable, non-secret Pi customization. The setup
script links it into `~/.pi/agent` while leaving Pi's installation, sessions,
and credentials local to each machine.

## Layout

- `settings.json` — personal Pi settings
- `keybindings.json` — terminal and application shortcuts
- `models.json` — compatible/custom model endpoints (keep credentials out)
- Optional `AGENTS.md`, `AGENTS.override.md`, `SYSTEM.md`, and `APPEND_SYSTEM.md`
- `extensions/` — executable extensions
- `skills/` — reusable skills
- `prompts/` — prompt templates
- `themes/` — custom themes

Run `~/dotfiles/setup.sh` after cloning or pulling this repository on another
device. Log in to providers separately with `/login`; never commit
`~/.pi/agent/auth.json` or session files.

## Model selection customization

Selecting a model normally uses Pi's default thinking level (`medium`, or the
closest level supported by that model). While a model is highlighted in the
model selector, press `Tab` to open that model's full thinking-level list.

`apply-model-selector-patch.sh` reapplies this customization to the currently
installed Pi release. The setup script installs Pi if missing, then applies
the patch. Run `~/dotfiles/setup.sh` again after `pi update` if an update
replaces the patched release.

Credentials (`auth.json`), trust decisions, and sessions intentionally remain
local to each device. Sign in separately on each device. Review `models.json`
for literal keys or other secrets before committing.
