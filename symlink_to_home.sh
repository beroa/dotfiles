#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"

ln -sf "$DOTFILES_DIR/.bashrc2" "$HOME/.bashrc2"
ln -sf "$DOTFILES_DIR/.bash_aliases" "$HOME/.bash_aliases"

ln -sf "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"

if ! grep -q "source ~/.bashrc2" "$HOME/.bashrc"; then
    echo 'source ~/.bashrc2' >> "$HOME/.bashrc"
fi

if ! grep -q "source ~/.bash_aliases" "$HOME/.bashrc"; then
    echo 'source ~/.bash_aliases' >> "$HOME/.bashrc"
fi

echo "Dotfiles have been set up and symlinked!"
