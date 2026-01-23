#!/bin/bash
# Docker test script for dotfiles
# Runs the bootstrap in a fresh container to test installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[TEST]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
    cat <<EOF
Docker test script for dotfiles bootstrap

Usage:
    $0 [OPTIONS] [DISTRO]

DISTRO:
    arch        Test on Arch Linux (default)
    ubuntu      Test on Ubuntu 22.04
    both        Test on both distros

OPTIONS:
    -m, --mode MODE     Set installation mode (desktop/server)
    -i, --interactive   Run interactive shell after bootstrap
    -l, --local         Use local files instead of GitHub
    -h, --help          Show this help message

Examples:
    $0                  # Test on Arch with desktop mode
    $0 ubuntu           # Test on Ubuntu
    $0 -m server arch   # Test server mode on Arch
    $0 -i ubuntu        # Interactive Ubuntu container
    $0 -l arch          # Test with local files (mount volume)
EOF
}

# Default values
DISTRO="arch"
MODE="desktop"
INTERACTIVE=false
USE_LOCAL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -l|--local)
            USE_LOCAL=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        arch|ubuntu|both)
            DISTRO="$1"
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# Docker images
ARCH_IMAGE="archlinux:latest"
UBUNTU_IMAGE="ubuntu:22.04"

# Build test command
build_test_command() {
    local distro="$1"
    local cmd=""
    
    if [[ "$distro" == "arch" ]]; then
        cmd="pacman -Sy --noconfirm curl git sudo"
    else
        cmd="apt-get update && apt-get install -y curl git sudo"
    fi
    
    if [[ "$USE_LOCAL" == "true" ]]; then
        # Use mounted local files
        cmd="$cmd && cd /dotfiles && bash install.sh --mode $MODE"
    else
        # Fetch from GitHub (requires repo to be pushed first)
        cmd="$cmd && curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode $MODE"
    fi
    
    echo "$cmd"
}

run_test() {
    local distro="$1"
    local image=""
    
    if [[ "$distro" == "arch" ]]; then
        image="$ARCH_IMAGE"
    else
        image="$UBUNTU_IMAGE"
    fi
    
    log_info "Testing on $distro ($image)..."
    log_info "Mode: $MODE"
    log_info "Interactive: $INTERACTIVE"
    log_info "Use local: $USE_LOCAL"
    echo ""
    
    local docker_args=("-it" "--rm")
    
    if [[ "$USE_LOCAL" == "true" ]]; then
        docker_args+=("-v" "$SCRIPT_DIR:/dotfiles:ro")
    fi
    
    local test_cmd
    test_cmd=$(build_test_command "$distro")
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        # Run bootstrap then drop to shell
        docker run "${docker_args[@]}" "$image" bash -c "$test_cmd; exec bash"
    else
        # Just run bootstrap and exit
        docker run "${docker_args[@]}" "$image" bash -c "$test_cmd"
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "$distro test PASSED"
    else
        log_error "$distro test FAILED (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Main
log_info "Dotfiles Docker Test"
log_info "===================="
echo ""

if [[ "$DISTRO" == "both" ]]; then
    log_info "Testing on both distros..."
    echo ""
    
    run_test "arch"
    arch_result=$?
    
    echo ""
    echo "----------------------------------------"
    echo ""
    
    run_test "ubuntu"
    ubuntu_result=$?
    
    echo ""
    log_info "Results:"
    [[ $arch_result -eq 0 ]] && log_info "  Arch: PASSED" || log_error "  Arch: FAILED"
    [[ $ubuntu_result -eq 0 ]] && log_info "  Ubuntu: PASSED" || log_error "  Ubuntu: FAILED"
    
    [[ $arch_result -eq 0 && $ubuntu_result -eq 0 ]] && exit 0 || exit 1
else
    run_test "$DISTRO"
fi
