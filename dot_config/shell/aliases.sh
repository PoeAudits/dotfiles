# Shell aliases - shared between bash and zsh
# Sourced by both ~/.bashrc and ~/.zshrc

# ------------------------------------------------------------------------------
# Navigation
# ------------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# ------------------------------------------------------------------------------
# Directory listing (eza - modern ls replacement)
# ------------------------------------------------------------------------------
if command -v eza &>/dev/null; then
    alias ls='eza --color=auto --group-directories-first'
    alias ll='eza -la --group-directories-first'
    alias la='eza -a --group-directories-first'
    alias l='eza -l --group-directories-first'
    alias lt='eza --tree --level=2'
else
    alias ls='ls --color=auto'
    alias ll='ls -la --color=auto'
    alias la='ls -a --color=auto'
    alias l='ls -l --color=auto'
fi

# ------------------------------------------------------------------------------
# Better cat (bat)
# ------------------------------------------------------------------------------
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    alias catp='bat'  # bat with paging
fi

# ------------------------------------------------------------------------------
# Chezmoi shortcuts
# ------------------------------------------------------------------------------
alias cz='chezmoi'
alias cza='chezmoi apply'
alias czd='chezmoi diff'
alias cze='chezmoi edit'
alias czs='chezmoi status'
alias czcd='cd ~/.local/share/chezmoi'
alias czup='chezmoi update'
alias czadd='chezmoi add'

# ------------------------------------------------------------------------------
# Grep with colors
# ------------------------------------------------------------------------------
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ------------------------------------------------------------------------------
# Common utilities
# ------------------------------------------------------------------------------
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias mkdir='mkdir -pv'

# Quick edit
alias v='${EDITOR:-nvim}'
alias vi='${EDITOR:-nvim}'
alias vim='${EDITOR:-nvim}'

# OpenCode - see functions.sh for oc, oc-remote, oc-stop, oc-status

# Misc
alias path='echo -e ${PATH//:/\\n}'
alias myip='curl -s ifconfig.me'
