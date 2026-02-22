#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
ZSH_INSTALLED_DURING_SETUP=0

ln -sf "$DOTFILES_DIR/.zshrc2" "$HOME/.zshrc2"
ln -sf "$DOTFILES_DIR/.bashrc2" "$HOME/.bashrc2"

ln -sf "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"

install_zsh() {
    if command -v zsh >/dev/null 2>&1; then
        return 0
    fi

    run_as_root() {
        if [[ "$(id -u)" -eq 0 ]]; then
            "$@"
        elif command -v sudo >/dev/null 2>&1; then
            sudo "$@"
        else
            echo "Root privileges are required to install zsh."
            return 1
        fi
    }

    if command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update && run_as_root apt-get install -y zsh
    elif command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y zsh
    elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y zsh
    elif command -v pacman >/dev/null 2>&1; then
        run_as_root pacman -Sy --noconfirm zsh
    elif command -v zypper >/dev/null 2>&1; then
        run_as_root zypper --non-interactive install zsh
    elif command -v brew >/dev/null 2>&1; then
        brew install zsh
    else
        echo "No supported package manager found for zsh installation."
        return 1
    fi

    if command -v zsh >/dev/null 2>&1; then
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

install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "git is required to install Oh My Zsh."
        return 1
    fi

    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
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

    if command -v tmux >/dev/null 2>&1; then
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
    if command -v tmux >/dev/null 2>&1 && [[ -n "$TMUX_PANE" ]]; then
        echo "Reload: tmux pane detected; skipping queued shell reload."
        echo "Reload: run 'source $shell_rc' after setup completes."
        return 0
    fi

    echo "Reload: run 'source $shell_rc' to reload this shell."
}

install_x_terminal() {
    local x_repo
    x_repo="$HOME/terminal-x"

    if [[ ! -d "$x_repo" ]]; then
        echo "x-terminal setup: $x_repo not found; skipping x-terminal install."
        return 0
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo "x-terminal setup: node is required; skipping x-terminal install."
        return 1
    fi

    if ! command -v npm >/dev/null 2>&1; then
        echo "x-terminal setup: npm is required; skipping x-terminal install."
        return 1
    fi

    echo "x-terminal setup: installing dependencies and linking x from $x_repo."
    if (
        cd "$x_repo" &&
        npm install &&
        npm link
    ); then
        echo "x-terminal setup: linked command 'x' successfully."
        return 0
    fi

    echo "x-terminal setup: install/link failed in $x_repo."
    return 1
}

init_x_terminal_api_key() {
    local init_choice normalized_choice key_file

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

    normalized_choice="$(printf '%s' "$init_choice" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    case "$normalized_choice" in
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

SHELL_RC="$HOME/.zshrc"
BASH_RC="$HOME/.bashrc"

touch "$SHELL_RC"
touch "$BASH_RC"

if install_oh_my_zsh; then
    if ! grep -Eq '^[[:space:]]*source[[:space:]]+\$ZSH/oh-my-zsh\.sh[[:space:]]*$' "$SHELL_RC"; then
        if ! grep -Eq '^[[:space:]]*export[[:space:]]+ZSH=' "$SHELL_RC"; then
            echo 'export ZSH="$HOME/.oh-my-zsh"' >> "$SHELL_RC"
        fi
        echo 'source $ZSH/oh-my-zsh.sh' >> "$SHELL_RC"
    fi
else
    echo "Oh My Zsh installation failed; continuing without it."
fi

sed -i '/^[[:space:]]*source[[:space:]]\+~\/\.zshrc2[[:space:]]*$/d' "$SHELL_RC"
echo 'source ~/.zshrc2' >> "$SHELL_RC"

sed -i '/^[[:space:]]*source[[:space:]]\+~\/\.bashrc2[[:space:]]*$/d' "$BASH_RC"
echo 'source ~/.bashrc2' >> "$BASH_RC"

if [[ "${SHELL##*/}" == "bash" ]]; then
    migrate_bash_history_to_zsh
fi

if ! install_x_terminal; then
    echo "x-terminal setup: continuing without x-terminal."
fi

echo "Dotfiles have been set up and symlinked!"

reload_runtime_config
init_x_terminal_api_key
