#!/bin/bash
# =============================================================================
# Cloudflare Tunnel + SSH Setup for Termux
# =============================================================================
# Configures a Cloudflare Tunnel to enable SSH to Termux from anywhere
# without requiring a public IP or port forwarding.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/master/cloudflared-ssh-tunnel.sh | bash
#   bash cloudflared-ssh-tunnel.sh
#
# Prerequisites:
#   - Termux from F-Droid (not Google Play)
#   - Cloudflare account (free at cloudflare.com)
#   - cloudflared installed on the PC side
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="cloudflared-ssh-tunnel.sh"
readonly SCRIPT_VERSION="2026-04-24.1"
readonly CF_TUNNEL_NAME="termux-ssh"
readonly CF_SSH_HOSTNAME="termux-ssh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'

LOG_FILE="$HOME/cloudflared-tunnel/install.log"
INSTALL_DIR="$HOME/cloudflared-tunnel"

log() { printf "%b[CF]%b %s\n" "$1" "$NC" "$*"; [[ -d "$INSTALL_DIR" ]] && echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }
info()    { log "$CYAN" "INFO" "$@"; }
success() { log "$GREEN" "OK" "$@"; }
warn()    { log "$YELLOW" "WARN" "$@"; }
error()   { log "$RED" "ERROR" "$@"; }

# Colors for output
info "Cloudflare Tunnel + SSH Setup v${SCRIPT_VERSION}"
info "============================================"

# =============================================================================
# CHECKS
# =============================================================================

check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        error "This script must run inside Termux on Android."
        exit 1
    fi
    info "Termux detected ✓"
}

check_sshd() {
    if ! pgrep -x sshd > /dev/null 2>&1; then
        warn "sshd is not running. Starting sshd..."
        sshd
        sleep 1
        if pgrep -x sshd > /dev/null 2>&1; then
            success "sshd started ✓"
        else
            error "Failed to start sshd. Run 'sshd' manually."
            exit 1
        fi
    else
        success "sshd is running ✓"
    fi
}

# =============================================================================
# INSTALL CLOUDFLARED
# =============================================================================

install_cloudflared() {
    if command -v cloudflared &> /dev/null; then
        local ver=$(cloudflared --version 2>/dev/null | head -1)
        success "cloudflared already installed: $ver"
        return 0
    fi

    info "Installing cloudflared..."

    # Detect architecture
    local arch=$(uname -m)
    case "$arch" in
        aarch64|arm64) local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
        armv7l|arm)    local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;;
        x86_64)        local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
        i686|386)      local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386" ;;
        *)             error "Unsupported architecture: $arch"; exit 1 ;;
    esac

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    info "Downloading cloudflared for $arch..."
    if ! curl -fsSL "$url" -o cloudflared; then
        error "Failed to download cloudflared."
        exit 1
    fi

    chmod +x cloudflared
    mv cloudflared "$PREFIX/bin/cloudflared"

    success "cloudflared installed ✓"
}

# =============================================================================
# AUTHENTICATE WITH CLOUDFLARE
# =============================================================================

authenticate_cloudflare() {
    info "Checking Cloudflare authentication..."

    # Check if already authenticated
    if [[ -f "$HOME/.cloudflared/config.yml" ]]; then
        success "Already authenticated with Cloudflare ✓"
        return 0
    fi

    warn "Cloudflare authentication required."
    echo ""
    echo "IMPORTANT: You need a Cloudflare account."
    echo ""
    echo "Steps:"
    echo "1. Create account at https://dash.cloudflare.com/sign-up"
    echo "2. Run: cloudflared tunnel login"
    echo "3. Authorize the connection in the browser"
    echo ""
    echo "Alternatively, you can authenticate non-interactively:"
    echo "  cloudflared tunnel login --url ssh://localhost:8022"
    echo ""
    echo "After authentication, run this script again."
    echo ""

    # Attempt non-interactive auth
    read -p "Press Enter to open browser for authentication, or Ctrl+C to exit... "
    cloudflared tunnel login || {
        error "Authentication failed or was cancelled."
        exit 1
    }
}

# =============================================================================
# CREATE TUNNEL
# =============================================================================

create_tunnel() {
    info "Setting up Cloudflare Tunnel..."

    mkdir -p "$HOME/.cloudflared"

    # Check if tunnel already exists
    existing_tunnel=$(cloudflared tunnel list 2>/dev/null | grep "$CF_TUNNEL_NAME" | awk '{print $1}' || true)

    if [[ -n "$existing_tunnel" ]]; then
        info "Tunnel '$CF_TUNNEL_NAME' already exists: $existing_tunnel"
        CF_TUNNEL_ID="$existing_tunnel"
    else
        info "Creating new tunnel: $CF_TUNNEL_NAME"
        CF_TUNNEL_ID=$(cloudflared tunnel create "$CF_TUNNEL_NAME" 2>/dev/null | grep 'id:' | awk '{print $2}' || true)

        if [[ -z "$CF_TUNNEL_ID" ]]; then
            # Try different output format
            CF_TUNNEL_ID=$(cloudflared tunnel create "$CF_TUNNEL_NAME" 2>&1 | tail -1)
        fi

        if [[ -z "$CF_TUNNEL_ID" ]]; then
            error "Failed to create tunnel. Please run 'cloudflared tunnel login' first."
            exit 1
        fi

        success "Tunnel created: $CF_TUNNEL_ID"
    fi

    export CF_TUNNEL_ID
}

# =============================================================================
# CONFIGURE TUNNEL
# =============================================================================

configure_tunnel() {
    info "Configuring tunnel for SSH access..."

    cat > "$HOME/.cloudflared/config.yml" << 'CONFIG_EOF'
# Cloudflare Tunnel SSH Configuration
# Auto-generated by cloudflared-ssh-tunnel.sh

tunnel: TUNNEL_ID
credentials-file: CREDENTIALS_FILE

# SSH access via Cloudflare Access
ingress:
  - hostname: HOSTNAME
    service: ssh://localhost:8022
  - service: http://localhost:8080
CONFIG_EOF

    # Replace placeholders with actual values
    local cred_file="$HOME/.cloudflared/$CF_TUNNEL_NAME.json"
    local hostname="${CF_TUNNEL_NAME}.${CLOUDFLARE_EMAIL:+cf-access@}.dev"

    # Update config with real values
    sed -i "s|TUNNEL_ID|$CF_TUNNEL_ID|g" "$HOME/.cloudflared/config.yml"
    sed -i "s|CREDENTIALS_FILE|$cred_file|g" "$HOME/.cloudflared/config.yml"
    sed -i "s|HOSTNAME|$hostname|g" "$HOME/.cloudflared/config.yml"

    success "Tunnel configured ✓"
}

# =============================================================================
# START TUNNEL
# =============================================================================

start_tunnel() {
    info "Starting Cloudflare Tunnel..."

    # Kill existing tunnel process if any
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    sleep 1

    # Start tunnel in background
    nohup cloudflared tunnel run --force "$CF_TUNNEL_NAME" > "$INSTALL_DIR/tunnel.log" 2>&1 &
    sleep 3

    if pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then
        success "Cloudflare Tunnel is running ✓"
    else
        error "Failed to start tunnel. Check $INSTALL_DIR/tunnel.log"
        exit 1
    fi
}

# =============================================================================
# SHOW RESULTS
# =============================================================================

show_results() {
    echo ""
    echo -e "${GREEN}============================================================"
    echo "  Cloudflare Tunnel SSH Setup Complete!"
    echo "============================================================${NC}"
    echo ""
    echo -e "${CYAN}Tunnel Status:${NC}"
    cloudflared tunnel list
    echo ""
    echo -e "${CYAN}SSH Configuration for your PC:${NC}"
    echo ""
    echo "Add this to your ~/.ssh/config:"
    echo ""
    echo "# Cloudflare Tunnel SSH to Termux"
    echo "Host termux-cf"
    echo "    HostName ${CF_TUNNEL_NAME}.dev" 
    echo "    User u0_a$(id -u)"
    echo "    Port 8022"
    echo "    ProxyCommand cloudflared access ssh --hostname %h"
    echo "    StrictHostKeyChecking no"
    echo "    UserKnownHostsFile /dev/null"
    echo ""
    echo -e "${YELLOW}Note:${NC} Replace '%h' with the actual hostname from cloudflared tunnel list"
    echo ""
    echo "Connect with: ssh termux-cf"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    check_termux
    check_sshd
    install_cloudflared

    # Check if authenticated
    if [[ ! -f "$HOME/.cloudflared/credentials.json" ]] && [[ ! -f "$HOME/.cloudflared/cert.pem" ]]; then
        authenticate_cloudflare
    fi

    create_tunnel
    configure_tunnel
    start_tunnel
    show_results

    success "Setup complete! Your Termux is now accessible via Cloudflare Tunnel."
}

main "$@"