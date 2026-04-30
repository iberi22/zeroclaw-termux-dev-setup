#!/bin/bash
# =============================================================================
# SWAL Node v4.2 — Termux Installer & Status Dashboard
# =============================================================================
# SouthWest AI Labs
# Interactive menu: install, status, tunnel, gestalt, docker, xavier2
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

readonly VERSION="2026-04-24.2"
readonly SCRIPT_DIR="$HOME/.swal-node"
readonly LOG="$SCRIPT_DIR/install.log"
readonly SWAL_V="v4.2"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; PURPLE='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

mkdir -p "$SCRIPT_DIR"

# =============================================================================
# LOGGING
# =============================================================================
log() { printf "${BOLD}[SWAL]${NC} %b %s\n" "$1" "$*"; echo "[$(date '+%H:%M:%S')] $*" >> "$LOG" 2>/dev/null || true; }
info()    { log "$CYAN" "INFO" "$@"; }
success() { log "$GREEN" "OK" "$@"; }
warn()    { log "$YELLOW" "WARN" "$@"; }
error()   { log "$RED" "ERROR" "$@"; }

# =============================================================================
# HELPERS
# =============================================================================
cmd_exists() { command -v "$1" &>/dev/null 2>&1; }
is_running() { pgrep -x "$1" > /dev/null 2>&1; }
get_pid()     { pgrep -x "$1" 2>/dev/null || echo "—"; }

# =============================================================================
# BANNER
# =============================================================================
banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║ ██╗ ██╗███████╗██╗ ██████╗ ██████╗ ███╗ ███╗ ║"
    echo "║ ██║ ██║██╔════╝██║ ██╔════╝██╔═══██╗████╗ ████║ ║"
    echo "║ ██║ █╗ ██║█████╗ ██║ ██║ ██║ ██║██╔████╔██║ ║"
    echo "║ ██║███╗██║██╔══╝ ██║ ██║ ██║ ██║██║╚██╔╝██║ ║"
    echo "║ ╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║ ║"
    echo "║ ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝ ╚═╝ ║"
    echo "║ SouthWest AI Labs - SWAL Node ${SWAL_V} ${NC}║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

# =============================================================================
# STATUS DASHBOARD
# =============================================================================
status_dashboard() {
    banner
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🚀 Core Services${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # ZeroClaw
    local zc_pid=$(get_pid zeroclaw)
    if [[ "$zc_pid" != "—" ]] && [[ -n "$zc_pid" ]]; then
        echo -e "  ZeroClaw  ✅ running (PID: $zc_pid)"
    else
        echo -e "  ZeroClaw  ❌ not running"
    fi

    # SSH
    if is_running sshd; then
        echo -e "  SSH Server ✅ running (PID: $(get_pid sshd))"
    else
        echo -e "  SSH Server ❌ not running"
    fi

    # Docker (via network)
    if curl -sf http://localhost:8006/health >/dev/null 2>&1; then
        echo -e "  Xavier2   ✅ running (port 8006)"
    else
        echo -e "  Xavier2   ❌ not reachable"
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🤖 AI Tools${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # GH
    if cmd_exists gh; then
        echo -e "  GH (GitHub) ✅ installed"
    else
        echo -e "  GH (GitHub) ❌ missing"
    fi

    # Git
    if cmd_exists git; then
        echo -e "  Git       ✅ installed ($(git --version 2>/dev/null | sed 's/git version //'))"
    else
        echo -e "  Git       ❌ missing"
    fi

    # Python
    if cmd_exists python; then
        echo -e "  Python    ✅ installed ($(python --version 2>&1 | sed 's/Python //'))"
    else
        echo -e "  Python    ❌ missing"
    fi

    # Node
    if cmd_exists node; then
        echo -e "  Node.js   ✅ installed ($(node --version 2>&1 | sed 's/v//'))"
    else
        echo -e "  Node.js   ❌ missing"
    fi

    # Rust
    if cmd_exists cargo; then
        echo -e "  Rust      ✅ installed ($(cargo --version 2>&1 | sed 's/cargo //'))"
    else
        echo -e "  Rust      ❌ missing"
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 📦 SWAL Quick Install Commands${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  pkg install nodejs"
    echo "  pkg install docker"
    echo "  pkg install rust"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🔧 Useful Commands${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  zeroclaw daemon     Start ZeroClaw"
    echo "  swal-node.sh        Show this dashboard"
    echo "  swal-node.sh install   Full install"
    echo "  swal-node.sh tunnel    Setup Cloudflare Tunnel"
    echo "  swal-node.sh gestalt   Compile/deploy Gestalt"
    echo "  swal-node.sh docker    Docker container status"
    echo "  swal-node.sh xavier2   Xavier2 memory engine test"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  Last check: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  SWAL Node ${SWAL_V} - SouthWest AI Labs"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# INSTALLER
# =============================================================================
check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        error "This script must run in Termux on Android."
        exit 1
    fi
    info "Termux detected"
}

update_packages() {
    info "Updating packages..."
    rm -f "$PREFIX/var/lib/pkg/lists/"* 2>/dev/null || true
    pkg update -y 2>/dev/null || pkg update --alternate-update -y 2>/dev/null || true
    success "Packages updated"
}

install_packages() {
    info "Installing base packages..."
    for pkg in git curl wget tar unzip zip nano vim htop tree openssh netcat-openbsd dnsutils build-essential cmake ninja clang make autoconf automake libtool python python-pip nodejs npm golang sqlite jq bc findutils coreutils ruby rust; do
        if ! cmd_exists "$pkg"; then
            info "  Installing $pkg..."
            pkg install -y "$pkg" 2>/dev/null || warn "  Failed: $pkg"
        fi
    done
    success "Base packages installed"
}

setup_ssh() {
    info "Setting up SSH..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    mkdir -p "$PREFIX/var/run"
    cat > "$PREFIX/etc/ssh/sshd_config" << 'EOF'
Port 8022
AuthorizedKeysFile %h/.ssh/authorized_keys
PasswordAuthentication no
PermitRootLogin yes
UseDNS no
PubkeyAuthentication yes
EOF
    if ! is_running sshd; then
        $PREFIX/bin/sshd 2>/dev/null || true
        sleep 1
    fi
    success "SSH configured (port 8022)"
}

install_cloudflared() {
    if cmd_exists cloudflared; then
        success "cloudflared already installed"
        return 0
    fi
    info "Installing cloudflared..."
    local arch=$(uname -m)
    local url=""
    case "$arch" in
        aarch64|arm64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
        armv7l|arm)    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;;
        x86_64)       url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
        i686|386)     url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386" ;;
        *)            error "Unsupported arch: $arch"; return 1 ;;
    esac
    mkdir -p "$SCRIPT_DIR/tunnel"
    cd "$SCRIPT_DIR/tunnel"
    if curl -fsSL "$url" -o cloudflared; then
        chmod +x cloudflared
        mv cloudflared "$PREFIX/bin/cloudflared"
        success "cloudflared installed for $arch"
    else
        error "cloudflared download failed"
        return 1
    fi
}

authenticate_cf() {
    info "Checking Cloudflare auth..."
    if [[ -f "$HOME/.cloudflared/cert.pem" ]] || [[ -f "$HOME/.cloudflared/config.yml" ]]; then
        success "Already authenticated with Cloudflare"
        return 0
    fi
    echo ""
    echo -e "${YELLOW}⚠️  Cloudflare authentication required${NC}"
    echo ""
    echo "  1. On your PC (logged into Cloudflare):"
    echo "     https://dash.cloudflare.com/profile/api-tokens"
    echo ""
    echo "  2. Create token with 'Edit Tunnel' permissions"
    echo ""
    echo "  3. Or on PC: cloudflared tunnel login"
    echo ""
    echo "  4. Then copy credentials to Termux:"
    echo "     scp -P 8022 -i ~/.ssh/termux_ed25519 \\"
    echo "       PC_HOST:.cloudflared/cert.pem \\"
    echo "       ~/.cloudflared/"
    echo ""
    read -p "Do you have Cloudflare auth ready? (y/n): " confirm
    [[ "$confirm" == "y" ]] || warn "Run 'bash swal-node.sh tunnel' when ready"
}

create_tunnel() {
    info "Creating Cloudflare Tunnel..."
    mkdir -p "$HOME/.cloudflared"
    local node_id
    if [[ -f "$SCRIPT_DIR/.node_id" ]]; then
        node_id=$(cat "$SCRIPT_DIR/.node_id")
    else
        node_id=$(date +%H%M%S)
        echo "$node_id" > "$SCRIPT_DIR/.node_id"
    fi
    export node_id
    local tunnel_name="termux-ssh-$node_id"
    local existing=$(cloudflared tunnel list 2>/dev/null | grep "$tunnel_name" | awk '{print $1}' || true)
    if [[ -n "$existing" ]]; then
        export CF_TUNNEL_ID="$existing"
        success "Using existing tunnel: $CF_TUNNEL_ID"
        return 0
    fi
    CF_TUNNEL_ID=$(cloudflared tunnel create "$tunnel_name" 2>&1 | grep -o '[0-9a-f-]\{36\}' | head -1 || true)
    if [[ -z "$CF_TUNNEL_ID" ]]; then
        warn "Could not create tunnel. Check authentication."
        return 1
    fi
    export CF_TUNNEL_ID
    success "Tunnel created: $CF_TUNNEL_ID"
}

start_tunnel() {
    info "Starting Cloudflare Tunnel..."
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    sleep 1
    local node_id
    if [[ -f "$SCRIPT_DIR/.node_id" ]]; then
        node_id=$(cat "$SCRIPT_DIR/.node_id")
    else
        node_id=$(date +%H%M%S)
    fi
    local tunnel_name="termux-ssh-$node_id"
    nohup cloudflared tunnel run --force "$tunnel_name" > "$SCRIPT_DIR/tunnel/tunnel.log" 2>&1 &
    sleep 3
    if is_running cloudflared; then
        success "Cloudflare Tunnel running"
    else
        warn "Tunnel not started - check logs"
    fi
}

tunnel_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} ☁️  Cloudflare Tunnel Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if is_running cloudflared; then
        echo -e "  Status:  ✅ RUNNING"
        echo "  Node ID: $(cat "$SCRIPT_DIR/.node_id" 2>/dev/null || echo 'N/A')"
        cloudflared tunnel list 2>/dev/null | grep termux-ssh | head -1 || echo "  Tunnel: active"
    else
        echo -e "  Status:  ⚠️  NOT RUNNING"
        echo "  Run: bash swal-node.sh tunnel"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# GESTALT COMPILE
# =============================================================================
build_gestalt() {
    info "Building Gestalt for Termux (aarch64)..."
    local gestalt_dir="$HOME/gestalt-rust"
    if [[ ! -d "$gestalt_dir/.git" ]]; then
        git clone --depth 1 https://github.com/iberi22/gestalt-rust.git "$gestalt_dir" 2>/dev/null || {
            error "Clone failed"
            return 1
        }
    fi
    cd "$gestalt_dir"
    export CARGO_BUILD_JOBS=4
    export TERMUX_PKG=1
    export TERMUX_MAIN_PACKAGE_FORMAT=debian
    local target="aarch64-linux-android"
    if ! rustup target list 2>/dev/null | grep -q "$target.*installed"; then
        rustup target add "$target" 2>/dev/null || true
    fi
    info "Compiling (15-30 min)..."
    cargo build --release --target "$target" -p gestalt 2>&1 | tail -3
    local binary="$gestalt_dir/target/$target/release/gestalt"
    if [[ -f "$binary" ]]; then
        cp "$binary" "$PREFIX/bin/gestalt"
        chmod +x "$PREFIX/bin/gestalt"
        success "Gestalt deployed to $PREFIX/bin/gestalt"
    else
        error "Build failed"
        return 1
    fi
}

# =============================================================================
# DOCKER MANAGEMENT
# =============================================================================
docker_status() {
    banner
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🐳 Docker Containers${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    local containers
    containers=$(docker ps -a --format "{{.Names}}	{{.Status}}	{{.Ports}}" 2>/dev/null || echo "  Docker not available")
    echo "$containers" | while IFS=$'\t' read -r name status ports; do
        if [[ "$status" == *"Up"* ]]; then
            echo -e "  ${GREEN}●${NC} $name  $status"
        else
            echo -e "  ${RED}○${NC} $name  $status"
        fi
    done
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} ⚡ Quick Docker Actions${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "  start xavier2  →  docker start xavier2"
    echo "  start cortex    →  docker start cortex"
    echo "  logs xavier2    →  docker logs xavier2"
    echo "  shell xavier2   →  docker exec -it xavier2 sh"
    echo ""
}

# =============================================================================
# XAVIER2 STATUS & TEST
# =============================================================================
xavier2_status() {
    banner
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🧠 Xavier2 Memory Engine${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    local health
    health=$(curl -sf http://localhost:8006/health 2>/dev/null || echo '{"status":"error"}')
    if [[ "$health" == *'"ok"'* ]]; then
        echo -e "  Health:  ✅ RUNNING (port 8006)"
    else
        echo -e "  Health:  ⚠️  NOT REACHABLE"
    fi
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🔍 Test Memory Search${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Query: ${YELLOW}SWAL projects${NC}"
    local result
    result=$(curl -sf -X POST http://localhost:8006/memory/search \
        -H "Content-Type: application/json" \
        -H "X-Xavier2-Token: dev-token" \
        -d '{"query":"SWAL projects","limit":2}' 2>/dev/null || echo '{}')
    local status_text
    status_text=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','error'))" 2>/dev/null || echo "unknown")
    local count
    count=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(len(r))" 2>/dev/null || echo "?")
    echo -e "  Status: $status_text  |  Results: $count"
    echo ""
    echo "  Run: curl -X POST http://localhost:8006/memory/search \\"
    echo "         -H 'Content-Type: application/json' \\"
    echo "         -d '{\"query\":\"your query\",\"limit\":3}'"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# QUICK INSTALL
# =============================================================================
do_install() {
    banner
    echo -e "${YELLOW}Installing SWAL Node...${NC}"
    echo ""
    check_termux
    update_packages
    install_packages
    setup_ssh
    install_cloudflared
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}  SWAL Node ${SWAL_V} - Installation complete${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Cloudflare auth on PC: cloudflared tunnel login"
    echo "  2. Run: bash swal-node.sh tunnel"
    echo "  3. Run: bash swal-node.sh status"
    echo ""
}

# =============================================================================
# MENU
# =============================================================================
show_menu() {
    banner
    echo -e "${CYAN}SWAL Node ${SWAL_V} - Menu${NC}"
    echo ""
    echo "  1) Install      - Full installation"
    echo "  2) Status       - Node status dashboard"
    echo "  3) Tunnel       - Setup Cloudflare Tunnel"
    echo "  4) Gestalt      - Compile & deploy Gestalt"
    echo "  5) Restart      - Restart services"
    echo "  6) Logs         - View install log"
    echo "  7) Docker       - Docker container status"
    echo "  8) Xavier2      - Xavier2 memory engine test"
    echo "  0) Exit"
    echo ""
    echo -ne "${CYAN}Option: ${NC}"
}

menu_loop() {
    while true; do
        show_menu
        read -r choice
        case "$choice" in
            1) do_install; break ;;
            2) status_dashboard; break ;;
            3) install_cloudflared; authenticate_cf; create_tunnel; start_tunnel; tunnel_status; break ;;
            4) build_gestalt; break ;;
            5) pkill -f zeroclaw 2>/dev/null || true; pkill -f cloudflared 2>/dev/null || true; setup_ssh; success "Services restarted"; break ;;
            6) [[ -f "$LOG" ]] && less "$LOG" || echo "No logs yet"; break ;;
            7) docker_status; break ;;
            8) xavier2_status; break ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid option";;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    case "${1:-menu}" in
        install)  do_install ;;
        status)   status_dashboard ;;
        tunnel)   install_cloudflared; authenticate_cf; create_tunnel; start_tunnel; tunnel_status ;;
        gestalt)  build_gestalt ;;
        restart)  pkill -f zeroclaw 2>/dev/null; pkill -f cloudflared 2>/dev/null; setup_ssh; success "Restarted" ;;
        docker)   docker_status ;;
        xavier2)  xavier2_status ;;
        menu)     menu_loop ;;
        *)        echo "Usage: swal-node.sh {install|status|tunnel|gestalt|restart|docker|xavier2|menu}" ;;
    esac
}

main "$@"
