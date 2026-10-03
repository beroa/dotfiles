# Pi configuration

This directory contains the shareable, non-secret Pi configuration. `setup.sh`
links these files and the extension into `~/.pi/agent`, while keeping Pi's
installation, sessions, and credentials local to each machine.

## Assistant modes

`extensions/modes.ts` provides **normal**, **ask**, and **plan** modes. Use
**Shift+Tab** to cycle or `/mode` to choose/set one directly. Ask disables
tools; plan keeps tools available for research while remaining non-mutating.
Plan mode loads the `grill-me` skill every turn, explores options and tradeoffs,
and recommends an option when appropriate. The active mode is always shown
in the two-line footer, alongside model, price, and context used/total with
percentage. Mode and prior tool set are restored with the session. Shift+Tab
replaces Pi's built-in thinking-level cycle in `keybindings.json`.

## Model switcher

`extensions/model-switcher.ts` provides a searchable switcher on **Ctrl+L** or
`/model-switcher`. Select a model with Enter; press Tab on a reasoning model to
choose its thinking level. The extension replaces the built-in Ctrl+L binding;
the tree's labeled-only filter moves to **Ctrl+Shift+L**. Pi's `/model`
command remains available for its native picker, including saving a default
model.

## Themes

The custom `light-blue` theme is selected by default. Switch themes with
`/settings` → **Theme**; Pi also includes `system`, `dark`, and `light` themes.
The custom theme preserves the terminal's default foreground for regular text.

## Shared skills

Store selected skills in the repository's top-level `skills/<name>/SKILL.md`.
`setup.sh` links each skill into `~/.agents/skills`, the shared global skill
location supported by Pi, Codex, Devin CLI, and Cursor CLI, whether or not
those CLIs are installed yet. Pi also links its skill resource path directly
to this repository. Skill files remain canonical here; rerun setup after
adding a new skill. Unrelated installed skills are preserved. Existing
`grill-me` and `grilling` copies are backed up before their dotfiles versions
are linked; other same-name conflicts are preserved, reported, and stop setup until resolved.

## Other files

- `settings.json` — personal Pi settings
- `keybindings.json` — terminal and application shortcuts
- `models.json` — compatible/custom model endpoints (keep credentials out)
- `extensions/`, `prompts/`, `themes/` — optional Pi resources; shared skills live in `../skills/`

Run `~/dotfiles/setup.sh` after cloning or pulling this repository on another
device. Log in to providers separately with `/login`; never commit
`~/.pi/agent/auth.json` or session files. Review `models.json` for literal keys
or other secrets before committing.
