#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
X_TERMINAL_REPO_DIR="$HOME/terminal-x"
X_TERMINAL_REPO_SSH_URL="git@github.com:davidfant/terminal-x.git"
ZSH_INSTALLED_DURING_SETUP=0

link_dotfile() {
    local source_file target_file
    source_file="$1"
    target_file="$2"

    if [[ ! -e "$source_file" ]]; then
        echo "Skipping missing dotfile: $source_file"
        return 0
    fi

    if ! ln -sfn "$source_file" "$target_file"; then
        echo "Failed to link $target_file -> $source_file"
        return 1
    fi

    echo "Linked $target_file -> $source_file"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

delete_lines_matching() {
    local pattern target tmp_file
    pattern="$1"
    target="$2"
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-sed.XXXXXX")" || return 1

    if sed "$pattern" "$target" > "$tmp_file"; then
        if mv "$tmp_file" "$target"; then
            return 0
        fi
    fi

    rm -f "$tmp_file"
    return 1
}

remove_oh_my_zsh() {
    local omz_dir
    omz_dir="$HOME/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        if rm -rf "$omz_dir"; then
            echo "Removed Oh My Zsh directory: $omz_dir"
        else
            echo "Failed to remove Oh My Zsh directory: $omz_dir"
            return 1
        fi
    else
        echo "Oh My Zsh directory not found: $omz_dir"
    fi
}

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif has_cmd sudo; then
        sudo "$@"
    else
        echo "Root privileges are required to run: $*"
        return 1
    fi
}

install_zsh() {
    if has_cmd zsh; then
        return 0
    fi

    if has_cmd apt-get; then
        run_as_root apt-get update && run_as_root apt-get install -y zsh
    elif has_cmd dnf; then
        run_as_root dnf install -y zsh
    elif has_cmd yum; then
        run_as_root yum install -y zsh
    elif has_cmd pacman; then
        run_as_root pacman -Sy --noconfirm zsh
    elif has_cmd zypper; then
        run_as_root zypper --non-interactive install zsh
    elif has_cmd brew; then
        brew install zsh
    else
        echo "No supported package manager found for zsh installation."
        return 1
    fi

    if has_cmd zsh; then
        ZSH_INSTALLED_DURING_SETUP=1
        return 0
    fi

    return 1
}

switch_to_zsh_if_on_bash() {
    if [[ "${SHELL##*/}" != "bash" ]]; then
        return 1
    fi

    if ! install_zsh; then
        echo "zsh installation failed; keeping current shell."
        return 1
    fi

    if ! command -v chsh >/dev/null 2>&1; then
        echo "chsh is not available; install zsh manually and change your login shell."
        return 1
    fi

    local zsh_path
    zsh_path="$(command -v zsh)"

    if chsh -s "$zsh_path" "$USER"; then
        echo "Default shell switched to zsh. Open a new terminal session to use it."
        return 0
    fi

    echo "Could not switch shell automatically; run: chsh -s $zsh_path"
    return 1
}

migrate_bash_history_to_zsh() {
    local bash_history zsh_history
    bash_history="$HOME/.bash_history"
    zsh_history="$HOME/.zsh_history"

    if [[ -s "$zsh_history" ]]; then
        echo "Existing ~/.zsh_history found; skipping history migration."
        return 0
    fi

    if [[ ! -f "$bash_history" ]]; then
        echo "No ~/.bash_history found; skipping history migration."
        return 0
    fi

    # Overwrite zsh history with bash history, dropping bash timestamp markers.
    if ! awk '!/^#[0-9]{10,}$/' "$bash_history" > "$zsh_history"; then
        echo "Failed to migrate Bash history to Zsh history."
        return 1
    fi
    chmod 600 "$zsh_history"
    echo "Migrated Bash history to Zsh history: $zsh_history"

    if [[ "$ZSH_INSTALLED_DURING_SETUP" -eq 1 ]]; then
        if rm -f "$bash_history"; then
            echo "Deleted ~/.bash_history after successful migration."
        else
            echo "Could not delete ~/.bash_history after migration."
        fi
    fi
}

reload_runtime_config() {
    local shell_rc
    shell_rc="$HOME/.zshrc"

    if has_cmd tmux; then
        echo "Reload: tmux source-file $HOME/.tmux.conf"
        if tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1; then
            echo "Reload: tmux config reloaded."
        else
            echo "Reload: tmux config reload skipped (no reachable tmux server/client)."
        fi
    else
        echo "Reload: tmux not found; skipping tmux config reload."
    fi

    # If this script is sourced, reload now in the current shell process.
    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        echo "Reload: sourcing $shell_rc in current shell."
        # shellcheck disable=SC1090
        source "$shell_rc"
        echo "Reload: sourced $shell_rc."
        return 0
    fi

    # Avoid sending keystrokes into the active pane; this can be consumed by later prompts.
    if has_cmd tmux && [[ -n "$TMUX_PANE" ]]; then
        echo "Reload: tmux pane detected; skipping queued shell reload."
        echo "Reload: run 'source $shell_rc' after setup completes."
        return 0
    fi

    echo "Reload: run 'source $shell_rc' to reload this shell."
}

restart_shell_if_interactive() {
    local next_shell

    if [[ ! -t 0 || ! -t 1 ]]; then
        echo "Restart: non-interactive shell detected; skipping shell restart."
        return 0
    fi

    if has_cmd zsh; then
        next_shell="$(command -v zsh)"
    else
        next_shell="${SHELL:-/bin/bash}"
    fi

    echo "Restart: launching fresh login shell: $next_shell -l"
    exec "$next_shell" -l
}

install_x_terminal() {
    local repo_dir origin_url npm_log

    if ! has_cmd git; then
        echo "x-terminal setup: git is required; skipping x-terminal install."
        return 1
    fi

    repo_dir="$X_TERMINAL_REPO_DIR"

    if [[ -d "$repo_dir/.git" ]]; then
        origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
        if [[ "$origin_url" =~ ^https?://github\.com/davidfant/terminal-x(/)?(\.git)?$ ]]; then
            echo "x-terminal setup: switching origin remote to SSH."
            if ! git -C "$repo_dir" remote set-url origin "$X_TERMINAL_REPO_SSH_URL"; then
                echo "x-terminal setup: could not switch origin remote to SSH."
                return 1
            fi
        fi
    elif [[ -e "$repo_dir" ]]; then
        echo "x-terminal setup: $repo_dir exists but is not a git repository; skipping clone."
    else
        echo "x-terminal setup: cloning x-terminal via SSH to $repo_dir."
        if ! git clone "$X_TERMINAL_REPO_SSH_URL" "$repo_dir"; then
            echo "x-terminal setup: failed to clone $X_TERMINAL_REPO_SSH_URL."
            return 1
        fi
    fi

    if ! has_cmd node; then
        echo "x-terminal setup: node is required; skipping x-terminal install."
        return 1
    fi

    if ! has_cmd npm; then
        echo "x-terminal setup: npm is required; skipping x-terminal install."
        return 1
    fi

    npm_log="$(mktemp)"
    if (
        cd "$repo_dir" &&
        npm install >"$npm_log" 2>&1 &&
        npm link >>"$npm_log" 2>&1
    ); then
        rm -f "$npm_log"
        echo "x-terminal setup: linked command 'x' successfully."
        return 0
    fi

    rm -f "$npm_log"
    echo "x-terminal setup: install/link failed in $repo_dir."
    return 1
}

init_x_terminal_api_key() {
    local init_choice key_file

    echo "Final step for x-terminal setup: API key initialization."

    if ! command -v x >/dev/null 2>&1; then
        echo "x-terminal setup: command 'x' is not available; run setup again after install."
        return 0
    fi

    key_file="$HOME/.x"
    if [[ -f "$key_file" ]]; then
        echo "x-terminal setup: existing $key_file detected; using existing key and skipping initialization."
        return 0
    fi

    if [[ ! -t 0 ]]; then
        echo "x-terminal setup: no interactive input available; skipping API key initialization."
        return 0
    fi

    init_choice=""
    if ! read -r -p "Initialize x-terminal API key now? [Y/n]: " init_choice; then
        echo "x-terminal setup: no input received; skipping API key initialization."
        return 0
    fi

    case "$(printf '%s' "$init_choice" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')" in
        ""|"y"|"yes")
            if x init; then
                echo "x-terminal setup: API key initialized."
            else
                echo "x-terminal setup: x init failed; run 'x init' later."
            fi
            ;;
        "n"|"no")
            echo "x-terminal setup: skipped API key initialization."
            ;;
        *)
            echo "x-terminal setup: unrecognized input; skipping API key initialization."
            ;;
    esac

    return 0
}

switch_to_zsh_if_on_bash || true

link_dotfile "$DOTFILES_DIR/.zshrc2" "$HOME/.zshrc2" || exit 1
link_dotfile "$DOTFILES_DIR/.bashrc2" "$HOME/.bashrc2" || exit 1
link_dotfile "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf" || exit 1
link_dotfile "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc" || exit 1

SHELL_RC="$HOME/.zshrc"
BASH_RC="$HOME/.bashrc"

touch "$SHELL_RC"
touch "$BASH_RC"

remove_oh_my_zsh

delete_lines_matching '/^[[:space:]]*export[[:space:]]\{1,\}ZSH=.*oh-my-zsh[[:space:]]*$/d' "$SHELL_RC"
delete_lines_matching '/^[[:space:]]*source[[:space:]]\{1,\}\$ZSH\/oh-my-zsh\.sh[[:space:]]*$/d' "$SHELL_RC"
delete_lines_matching '/^[[:space:]]*source[[:space:]]\{1,\}.*oh-my-zsh\/oh-my-zsh\.sh[[:space:]]*$/d' "$SHELL_RC"

delete_lines_matching '/^[[:space:]]*source[[:space:]]\{1,\}~\/\.zshrc2[[:space:]]*$/d' "$SHELL_RC"
delete_lines_matching '/^[[:space:]]*\[ -f ~\/\.zshrc2 \] && source[[:space:]]\{1,\}~\/\.zshrc2[[:space:]]*$/d' "$SHELL_RC"
echo '[ -f ~/.zshrc2 ] && source ~/.zshrc2' >> "$SHELL_RC"

delete_lines_matching '/^[[:space:]]*source[[:space:]]\{1,\}~\/\.bashrc2[[:space:]]*$/d' "$BASH_RC"
delete_lines_matching '/^[[:space:]]*\[ -f ~\/\.bashrc2 \] && source[[:space:]]\{1,\}~\/\.bashrc2[[:space:]]*$/d' "$BASH_RC"
echo '[ -f ~/.bashrc2 ] && source ~/.bashrc2' >> "$BASH_RC"

if [[ "${SHELL##*/}" == "bash" ]]; then
    migrate_bash_history_to_zsh
fi

if ! install_x_terminal; then
    echo "x-terminal setup: continuing without x-terminal."
fi

echo "Dotfiles have been set up and symlinked!"

reload_runtime_config
init_x_terminal_api_key
restart_shell_if_interactive
