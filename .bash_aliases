alias ch='clear ; tmux clear-history'

alias gc0='git checkout -'
alias gco='git checkout'
alias gl='git log'
alias gs='git status'
alias git-delete-merged='git branch --merged main | grep -v "^\* main" | xargs -n 1 -r git branch -d'
alias g-b-d="git for-each-ref --sort='committerdate:iso8601' --format=' %(committerdate:iso8601)%09%(refname)' refs/heads"
