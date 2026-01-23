# Shell functions - shared between bash and zsh
# Sourced by both ~/.bashrc and ~/.zshrc

# ------------------------------------------------------------------------------
# Directory utilities
# ------------------------------------------------------------------------------

# Create directory and cd into it
mkcd() {
    if [[ -z "$1" ]]; then
        echo "Usage: mkcd <directory>" >&2
        return 1
    fi
    mkdir -p "$1" && cd "$1" || return 1
}

# Create a temporary directory and cd into it
mktmp() {
    local tmpdir
    tmpdir=$(mktemp -d) || return 1
    echo "Created: $tmpdir"
    cd "$tmpdir" || return 1
}

# ------------------------------------------------------------------------------
# Pass (password-store) integration
# ------------------------------------------------------------------------------

# Get a secret from pass
# Usage: passget path/to/secret
passget() {
    if [[ -z "$1" ]]; then
        echo "Usage: passget <path/to/secret>" >&2
        return 1
    fi

    # Check if pass is available
    if ! command -v pass &>/dev/null; then
        echo "Error: pass is not installed" >&2
        return 1
    fi

    # Check if PASSWORD_STORE_DIR is set and exists
    if [[ -n "${PASSWORD_STORE_DIR:-}" && ! -d "$PASSWORD_STORE_DIR" ]]; then
        echo "Error: PASSWORD_STORE_DIR does not exist: $PASSWORD_STORE_DIR" >&2
        return 1
    fi

    # Get the secret, suppress errors for missing entries
    pass show "$1" 2>/dev/null
}

# Load secrets from pass as environment variables
# Usage: passenv path/to/env-file
# The pass entry should contain KEY=VALUE pairs, one per line
passenv() {
    if [[ -z "$1" ]]; then
        echo "Usage: passenv <path/to/env-file>" >&2
        return 1
    fi

    # Check if pass is available
    if ! command -v pass &>/dev/null; then
        return 0  # Silently skip if pass not available
    fi

    local content
    content=$(pass show "$1" 2>/dev/null) || return 0

    # Export each KEY=VALUE pair
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Only export valid KEY=VALUE pairs
        if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            export "$line"
        fi
    done <<< "$content"
}

# Load a single secret as an environment variable
# Usage: passvar VAR_NAME path/to/secret
passvar() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: passvar <VAR_NAME> <path/to/secret>" >&2
        return 1
    fi

    local var_name="$1"
    local secret_path="$2"

    # Check if pass is available
    if ! command -v pass &>/dev/null; then
        return 0  # Silently skip if pass not available
    fi

    local value
    value=$(pass show "$secret_path" 2>/dev/null) || return 0

    export "$var_name=$value"
}

# ------------------------------------------------------------------------------
# File utilities
# ------------------------------------------------------------------------------

# Extract various archive formats
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive>" >&2
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file" >&2
        return 1
    fi

    case "$1" in
        *.tar.bz2)   tar xjf "$1"     ;;
        *.tar.gz)    tar xzf "$1"     ;;
        *.tar.xz)    tar xJf "$1"     ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar x "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xf "$1"      ;;
        *.tbz2)      tar xjf "$1"     ;;
        *.tgz)       tar xzf "$1"     ;;
        *.zip)       unzip "$1"       ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *.zst)       unzstd "$1"      ;;
        *)           echo "Error: Unknown archive format '$1'" >&2; return 1 ;;
    esac
}

# Create a compressed archive
compress() {
    if [[ -z "$1" ]]; then
        echo "Usage: compress <file_or_directory>" >&2
        return 1
    fi
    tar -czf "${1%/}.tar.gz" "${1%/}"
}

# Find files by name (named findfile to avoid conflict with omarchy's ff alias)
findfile() {
    if [[ -z "$1" ]]; then
        echo "Usage: findfile <pattern>" >&2
        return 1
    fi
    find . -type f -iname "*$1*" 2>/dev/null
}

# Find directories by name (named finddir to avoid conflict with fd tool)
finddir() {
    if [[ -z "$1" ]]; then
        echo "Usage: finddir <pattern>" >&2
        return 1
    fi
    find . -type d -iname "*$1*" 2>/dev/null
}

# ------------------------------------------------------------------------------
# Process utilities
# ------------------------------------------------------------------------------

# Find process by name
psg() {
    if [[ -z "$1" ]]; then
        echo "Usage: psg <process_name>" >&2
        return 1
    fi
    ps aux | grep -i "$1" | grep -v grep
}

# Kill process by name (with confirmation)
psk() {
    if [[ -z "$1" ]]; then
        echo "Usage: psk <process_name>" >&2
        return 1
    fi
    local pids
    pids=$(pgrep -f "$1")
    if [[ -z "$pids" ]]; then
        echo "No processes found matching '$1'"
        return 0
    fi
    echo "Found processes:"
    ps -p "$pids" -o pid,user,comm,args
    echo
    read -rp "Kill these processes? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$pids" | xargs kill
        echo "Killed."
    fi
}

# ------------------------------------------------------------------------------
# Network utilities
# ------------------------------------------------------------------------------

# Show listening ports
ports() {
    if command -v ss &>/dev/null; then
        ss -tuln
    else
        netstat -tuln
    fi
}

# Quick HTTP server in current directory
serve() {
    local port="${1:-8000}"
    echo "Serving on http://localhost:$port"
    if command -v python3 &>/dev/null; then
        python3 -m http.server "$port"
    elif command -v python &>/dev/null; then
        python -m SimpleHTTPServer "$port"
    else
        echo "Error: Python not found" >&2
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Git utilities
# ------------------------------------------------------------------------------

# Git clone and cd into directory
gclone() {
    if [[ -z "$1" ]]; then
        echo "Usage: gclone <repo_url>" >&2
        return 1
    fi
    local repo_name
    repo_name=$(basename "$1" .git)
    git clone "$1" && cd "$repo_name" || return 1
}

# Show git branch in prompt (for shells without starship)
git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# ------------------------------------------------------------------------------
# Misc utilities
# ------------------------------------------------------------------------------

# Calculator
calc() {
    if [[ -z "$1" ]]; then
        echo "Usage: calc <expression>" >&2
        return 1
    fi
    echo "scale=4; $*" | bc -l
}

# Weather
weather() {
    local location="${1:-}"
    curl -s "wttr.in/${location}?format=3"
}

# Cheat sheet
cheat() {
    if [[ -z "$1" ]]; then
        echo "Usage: cheat <command>" >&2
        return 1
    fi
    curl -s "cheat.sh/$1"
}

# Backup a file with timestamp
backup() {
    if [[ -z "$1" ]]; then
        echo "Usage: backup <file>" >&2
        return 1
    fi
    cp "$1" "${1}.backup.$(date +%Y%m%d_%H%M%S)"
}
