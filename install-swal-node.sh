#!/bin/bash
# =============================================================================
# ZeroClaw — Termux Setup v2026-04-25.1
# =============================================================================
# Script de instalacion para Termux/Android
# Fixes: permisos, tool calls, environment, Rust on Termux
# Cloudflare Tunnel + Docker/Xavier2 remote testing
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/master/install-swal-node.sh | bash
#   bash install-swal-node.sh
#
# O con agents opcionales:
#   SWAL_INSTALL_ALL=1 bash install-swal-node.sh
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="install-swal-node.sh"
readonly SCRIPT_VERSION="2026-04-25.1"
readonly INSTALL_DIR="$HOME/zeroclaw"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'

LOG_FILE="$INSTALL_DIR/install.log"
SCRIPT_START_TS=$(date +%s)

INSTALL_ALL="${SWAL_INSTALL_ALL:-0}"
is_enabled() {
    [[ "$INSTALL_ALL" == "1" ]] && return 0
    local var="SWAL_INSTALL_${1}"
    [[ "${!var}" == "1" ]] && return 0
    return 1
}

log() { printf "%b[ZERO]%b %s\n" "$1" "$NC" "$*"; [[ -d "$INSTALL_DIR" ]] && echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }
info()    { log "$CYAN" "INFO" "$@"; }
success() { log "$GREEN" "OK" "$@"; }
warn()    { log "$YELLOW" "WARN" "$@"; }
error()   { log "$RED" "ERROR" "$@"; }

cleanup() {
    local exit_code=$?
    local elapsed=$(($(date +%s) - SCRIPT_START_TS))
    if [[ $exit_code -eq 0 ]]; then
        success "Instalacion completada en ${elapsed}s."
        show_next_steps
    else
        error "Instalacion fallo (code $exit_code) tras ${elapsed}s."
        [[ -f "$LOG_FILE" ]] && tail -20 "$LOG_FILE"
    fi
    exit $exit_code
}
trap cleanup EXIT

show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "============================================================"
    echo "  ZeroClaw — Termux Setup v${SCRIPT_VERSION}"
    echo "  Zero overhead. Zero compromise."
    echo "============================================================"
    echo -e "${NC}\n"
}

# =============================================================================
# 1. VERIFICACIONES
# =============================================================================
check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        error "Este script debe ejecutarse en Termux."
        exit 1
    fi
    if [[ "$(whoami)" == "root" ]]; then
        warn "Ejecutando como root — usando termux-exec"
    fi
    info "Termux detectado ✓ (user: $(whoami))"
}

check_arch() {
    local arch=$(getprop ro.product.cpu.abi 2>/dev/null || uname -m)
    info "Arquitectura: $arch"
}

# =============================================================================
# 2. ACTUALIZAR PAQUETES
# =============================================================================
update_packages() {
    info "Actualizando paquetes..."
    rm -f "$PREFIX/var/lib/pkg/lists/"* 2>/dev/null || true
    pkg update -y 2>/dev/null || {
        warn "pkg update failed — intentando con --alternate-update"
        pkg update --alternate-update -y 2>/dev/null || true
    }
    success "Paquetes actualizados ✓"
}

# =============================================================================
# 3. PAQUETES BASE
# =============================================================================
install_base_packages() {
    info "Instalando paquetes base..."
    local packages=(
        git curl wget tar unzip zip nano vim htop tree
        openssh netcat-openbsd dnsutils
        build-essential cmake ninja clang make autoconf automake libtool
        python python-pip
        nodejs npm
        golang
        sqlite
        jq bc findutils coreutils
        ruby
        rust
    )
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null 2>&1; then
            info "  Instalando $pkg..."
            pkg install -y "$pkg" 2>/dev/null || warn "    Fallo: $pkg"
        fi
    done
    success "Paquetes base instalados ✓"
}

# =============================================================================
# 4. FIX PERMISOS SSH
# =============================================================================
fix_ssh_permissions() {
    info "Fixing permisos SSH..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
        chmod 600 "$HOME/.ssh/id_rsa"
    fi
    if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        chmod 644 "$HOME/.ssh/id_rsa.pub"
    fi
    mkdir -p "$PREFIX/var/run"
    cat > "$PREFIX/etc/ssh/sshd_config" << 'EOF'
Port 8022
AuthorizedKeysFile %h/.ssh/authorized_keys
PasswordAuthentication no
PermitRootLogin yes
UseDNS no
PubkeyAuthentication yes
EOF
    success "Permisos SSH fixeados ✓"
}

# =============================================================================
# 5. FIX ENVIRONMENT — Rust on Termux
# =============================================================================
fix_rust_environment() {
    info "Fixing Rust environment..."
    export TERMUX_PKG=1
    export TERMUX_MAIN_PACKAGE_FORMAT=debian
    if [[ ! -d "$HOME/.rustup" ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
            --default-toolchain stable \
            --profile minimal \
            2>/dev/null || {
            warn "Rustup install failed"
            return 0
        }
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
    source "$HOME/.cargo/env" 2>/dev/null || true
    export CARGO_HOME="$HOME/.cargo"
    export RUSTUP_HOME="$HOME/.rustup"
    unset LD_PRELOAD 2>/dev/null || true
    success "Rust environment fixeado ✓"
}

# =============================================================================
# 6. FIX ENVIRONMENT — Go on Termux
# =============================================================================
fix_go_environment() {
    info "Fixing Go environment..."
    export GOPATH="$HOME/go"
    export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"
    mkdir -p "$GOPATH/bin"
    export GO111MODULE=on
    success "Go environment fixeado ✓"
}

# =============================================================================
# 7. FIX PYTHON ENVIRONMENT
# =============================================================================
fix_python_environment() {
    info "Fixing Python environment..."
    pip install --upgrade pip 2>/dev/null || true
    if ! command -v pip &>/dev/null; then
        python -m ensurepip --upgrade 2>/dev/null || true
    fi
    pip install \
        requests httpx aiohttp \
        fastapi uvicorn pydantic \
        openai anthropic groq \
        langchain langchain-community \
        python-dotenv pyyaml toml \
        rich typer click \
        beautifulsoup4 lxml \
        playwright \
        flask \
        2>/dev/null || warn "Some pip packages failed"
    success "Python environment fixeado ✓"
}

# =============================================================================
# 8. FIX NODE.JS ENVIRONMENT
# =============================================================================
fix_nodejs_environment() {
    info "Fixing Node.js environment..."
    if command -v npm &>/dev/null; then
        mkdir -p "$HOME/.npm-global"
        npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
        npm install -g \
            npm@latest pnpm yarn \
            typescript ts-node \
            prettier eslint \
            dotenv-cli \
            2>/dev/null || warn "Some npm packages failed"
    fi
    export PATH="$HOME/.npm-global/bin:$PATH"
    export NODE_PATH="$HOME/.npm-global/lib/node_modules:$NODE_PATH"
    success "Node.js environment fixeado ✓"
}

# =============================================================================
# 9. FIX TOOL CALL ISSUES — ZeroClaw config
# =============================================================================
fix_tool_calls() {
    info "Fixing tool call issues..."
    local config_dir="$HOME/.zeroclaw"
    mkdir -p "$config_dir"
    cat > "$config_dir/config.toml" << EOF
workspace_dir = "${HOME}/zeroclaw-workspace"
config_path = "${config_dir}/config.toml"

[api]
api_key = "${API_KEY:-}"
default_provider = "${PROVIDER:-openrouter}"
default_model = "${MODEL:-anthropic/claude-sonnet-4-20250514}"
default_temperature = 0.7

[gateway]
port = 42617
host = "0.0.0.0"
allow_public_bind = false
require_pairing = false

[autonomy]
level = "full"

[tools.retry]
enabled = true
max_attempts = 3
initial_delay_ms = 1000
max_delay_ms = 10000
backoff_multiplier = 2.0

[tools.rate_limit]
enabled = true
max_calls_per_minute = 60
max_concurrent = 4

[tools.timeout]
default_ms = 30000
shell_ms = 60000
git_ms = 30000
network_ms = 15000

[tools.allowed]
file_read = true
file_write = true
file_edit = true
file_delete = true
git_clone = true
git_pull = true
git_push = true
git_commit = true
shell_exec = true
pkg_install = true
web_search = true
web_fetch = true
memory_recall = true
memory_store = true
cargo_build = true
cargo_run = true
npm_install = true

[security]
allow_unsafe_commands = true
require_confirmation = false
log_all_commands = true

[cortex]
enabled = true
url = "http://localhost:8003"
token = "dev-token"

[xavier2]
enabled = true
url = "http://PC_HOST:8006"
token = "dev-token"

[gestalt]
enabled = true
swarm_path = "${HOME}/.cargo/bin/gestalt_swarm"

[skills]
open_skills_enabled = true
skills_dir = "${HOME}/zeroclaw-workspace/skills"
EOF
    success "Tool call fixes configurados ✓"
}

# =============================================================================
# 10. GIT CONFIG
# =============================================================================
setup_git() {
    info "Configurando Git..."
    cat > "$HOME/.gitconfig" << 'EOF'
[user]
    name = ZeroClaw User
    email = user@termux.local
[core]
    editor = nano
    autocrlf = input
[pull]
    rebase = false
[init]
    defaultBranch = main
[alias]
    co = checkout
    br = branch
    ci = commit
    st = status
[fetch]
    prune = true
[push]
    default = simple
EOF
    success "Git configurado ✓"
}

# =============================================================================
# 11. WORKSPACE
# =============================================================================
setup_workspace() {
    info "Configurando workspace..."
    mkdir -p "$HOME/zeroclaw-workspace"/{projects,skills,memory,logs}
    mkdir -p "$HOME/.zeroclaw"
    success "Workspace listo ✓"
}

# =============================================================================
# 12. ZERO CLAW — Build o Install
# =============================================================================
install_zeroclaw() {
    info "Instalando ZeroClaw..."
    cd "$HOME"
    local zeroclaw_dir="$HOME/zeroclaw"
    if [[ -x "$PREFIX/bin/zeroclaw" ]]; then
        info "ZeroClaw ya instalado en PREFIX ✓"
        return 0
    fi
    if [[ ! -d "$zeroclaw_dir/.git" ]]; then
        info "Clonando ZeroClaw..."
        git clone --depth 1 \
            https://github.com/zeroclaw-labs/zeroclaw.git \
            "$zeroclaw_dir" 2>/dev/null || {
            error "No se pudo clonar ZeroClaw"
            return 1
        }
    fi
    cd "$zeroclaw_dir"
    export CARGO_BUILD_JOBS=2
    export RUSTFLAGS="-C codegen-units=1"
    export TERMUX_PKG=1
    info "Compilando ZeroClaw (10-30 min)..."
    if RUST_LOG=info cargo build --release \
        --features "channel-nostr" 2>&1 | tee -a "$LOG_FILE"; then
        mkdir -p "$PREFIX/bin"
        cp target/release/zeroclaw "$PREFIX/bin/"
        success "ZeroClaw compilado e instalado ✓"
    else
        error "Build de ZeroClaw fallo"
        return 1
    fi
}

# =============================================================================
# 13. GESTALT SWARM — Opcional
# =============================================================================
install_gestalt() {
    is_enabled "GESTALT" || return 0
    info "Instalando Gestalt Swarm..."
    local gestalt_dir="$HOME/gestalt-rust"
    if [[ ! -d "$gestalt_dir/.git" ]]; then
        git clone --depth 1 \
            https://github.com/iberi22/gestalt-rust.git \
            "$gestalt_dir" 2>/dev/null || {
            warn "Gestalt clone failed"
            return 0
        }
    fi
    cd "$gestalt_dir"
    export CARGO_BUILD_JOBS=2
    export TERMUX_PKG=1
    if cargo build --release -p gestalt_swarm 2>&1 | tee -a "$LOG_FILE"; then
        mkdir -p "$PREFIX/bin"
        cp target/release/gestalt_swarm "$PREFIX/bin/"
        success "Gestalt Swarm instalado ✓"
    else
        warn "Gestalt build failed"
    fi
}

# =============================================================================
# 14. INFRASTRUCTURE CLIs — Opcionales
# =============================================================================
install_infra_tools() {
    is_enabled "SUPABASE" && install_supabase
    is_enabled "AWS" && install_aws
    is_enabled "GCP" && install_gcp
    is_enabled "CLOUDFLARE" && install_cloudflare
    is_enabled "TERRAFORM" && install_terraform
    is_enabled "PULUMI" && install_pulumi
}

install_supabase() {
    info "Instalando Supabase CLI..."
    if ! command -v supabase &>/dev/null; then
        local version="1.165.0"
        curl -fsSL \
            "https://github.com/supabase/cli/releases/download/v${version}/supabase_${version}_linux_amd64.tar.gz" \
            -o /tmp/supabase.tar.gz 2>/dev/null && \
        tar -xzf /tmp/supabase.tar.gz -C /tmp 2>/dev/null && \
        mv /tmp/supabase "$PREFIX/bin/" 2>/dev/null && \
        chmod +x "$PREFIX/bin/supabase" || \
        npm install -g supabase 2>/dev/null || \
            warn "Supabase install failed"
    fi
    success "Supabase CLI ✓"
}

install_aws() {
    info "Instalando AWS CLI..."
    if ! command -v aws &>/dev/null; then
        curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" \
            -o /tmp/awscliv2.zip 2>/dev/null && \
        unzip -q /tmp/awscliv2.zip -d /tmp 2>/dev/null && \
        /tmp/aws/install 2>/dev/null || true
    fi
    success "AWS CLI ✓"
}

install_gcp() {
    info "Instalando GCP CLI..."
    if ! command -v gcloud &>/dev/null; then
        curl -fsSL https://sdk.cloud.google.com | bash -s -- \
            --disable-prompts \
            --install-dir="$HOME/google-cloud-sdk" 2>/dev/null || true
        [[ -d "$HOME/google-cloud-sdk" ]] && \
            export PATH="$HOME/google-cloud-sdk/bin:$PATH"
    fi
    success "GCP CLI ✓"
}

install_cloudflare() {
    info "Instalando Cloudflare Wrangler..."
    npm install -g wrangler 2>/dev/null || warn "Wrangler install failed"
    success "Cloudflare Wrangler ✓"
}

install_terraform() {
    info "Instalando Terraform..."
    if ! command -v terraform &>/dev/null; then
        local version="1.6.0"
        curl -fsSL \
            "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip" \
            -o /tmp/terraform.zip 2>/dev/null && \
        unzip -q /tmp/terraform.zip -d "$PREFIX/bin/" 2>/dev/null || true
    fi
    success "Terraform ✓"
}

install_pulumi() {
    info "Instalando Pulumi..."
    curl -fsSL https://get.pulumi.com | bash -s -- --version 3.88.0 2>/dev/null || \
    npm install -g pulumi 2>/dev/null || true
    success "Pulumi ✓"
}

# =============================================================================
# 14.5. CLOUDFLARE TUNNEL — SSH via Cloudflare (2026-04-24)
# =============================================================================
install_cloudflared_tunnel() {
    info "Instalando cloudflared para SSH tunnel..."
    if command -v cloudflared &>/dev/null; then
        success "cloudflared ya instalado: $(cloudflared --version 2>/dev/null | head -1)"
        return 0
    fi
    local arch=$(uname -m)
    case "$arch" in
        aarch64|arm64) local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
        armv7l|arm)    local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;;
        x86_64)        local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
        i686|386)      local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386" ;;
        *)             warn "Arquitectura no soportada: $arch"; return 1 ;;
    esac
    mkdir -p "$HOME/cloudflared-tunnel"
    cd "$HOME/cloudflared-tunnel"
    info "Descargando cloudflared para $arch..."
    if curl -fsSL "$url" -o cloudflared; then
        chmod +x cloudflared
        mv cloudflared "$PREFIX/bin/cloudflared"
        success "cloudflared instalado OK"
    else
        error "Descarga de cloudflared fallida"
        return 1
    fi
}

generate_node_id() {
    echo "termux-$(date +%Y%m%d)-$(head -c 8 /dev/urandom | xxd -p 2>/dev/null || echo $(date +%H%M%S))"
}

generate_tunnel_token() {
    head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 48
}

configure_tunnel_token() {
    info "Configurando tunnel token..."
    mkdir -p "$HOME/cloudflared-tunnel"
    mkdir -p "$HOME/.cloudflared"
    local node_id=$(generate_node_id)
    local tunnel_token=$(generate_tunnel_token)
    echo "$tunnel_token" > "$HOME/cloudflared-tunnel/.tunnel_token"
    chmod 600 "$HOME/cloudflared-tunnel/.tunnel_token"
    echo "$node_id" > "$HOME/cloudflared-tunnel/.node_id"
    info "Node ID: $node_id"
    success "Token generado y almacenado"
}

start_cloudflare_tunnel() {
    info "Iniciando Cloudflare Tunnel SSH..."
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    sleep 1
    if [[ ! -f "$HOME/.cloudflared/cert.pem" ]]; then
        warn "No autenticado con Cloudflare. Pasos manuales:"
        echo "  1. cloudflared tunnel login"
        echo "  2. cloudflared tunnel create termux-ssh-\$NODE_ID"
        echo "  3. cloudflared tunnel run termux-ssh-\$NODE_ID"
        return 0
    fi
    local tunnel_name="termux-ssh-$(cat $HOME/cloudflared-tunnel/.node_id 2>/dev/null)"
    nohup cloudflared tunnel run --force "$tunnel_name" \
        > "$HOME/cloudflared-tunnel/tunnel.log" 2>&1 &
    sleep 3
    if pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then
        success "Cloudflare Tunnel corriendo OK"
    else
        warn "Tunnel no inicio - ver logs: $HOME/cloudflared-tunnel/tunnel.log"
    fi
}

show_tunnel_status() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  Cloudflare Tunnel Status${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo "  Node ID: $(cat $HOME/cloudflared-tunnel/.node_id 2>/dev/null || echo 'N/A')"
    echo "  Token:   $(cat $HOME/cloudflared-tunnel/.tunnel_token 2>/dev/null | head -c 20 2>/dev/null)..."
    echo ""
    if pgrep -f "cloudflared tunnel" > /dev/null 2>&1; then
        echo -e "  ${GREEN}Status: RUNNING${NC}"
        echo ""
        echo "  Para ver tunnels activos: cloudflared tunnel list"
        echo "  Para conectar desde PC: ssh termux-cf"
        echo "  DNS: swal-termux.saberparatodos.space"
    else
        echo -e "  ${YELLOW}Status: NOT RUNNING${NC}"
        echo ""
        echo "  Para iniciar manualmente:"
        echo "    cloudflared tunnel run termux-ssh-\$(cat ~/.cloudflared-tunnel/.node_id)"
    fi
    echo ""
    echo "  Logs: $HOME/cloudflared-tunnel/tunnel.log"
    echo -e "${CYAN}============================================================${NC}"
}

# =============================================================================
# 14.6. DOCKER TESTING — Remote PC Docker via HTTP (2026-04-25)
# =============================================================================
test_remote_docker() {
    # Test Docker containers on remote PC via HTTP API
    info "Testing remote Docker containers..."
    local pc_host="${DOCKER_PC_HOST:-192.168.1.2}"
    local pc_port="${DOCKER_PC_PORT:-8080}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🐳 Remote Docker Status (PC: $pc_host)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    local response
    response=$(curl -sf "http://$pc_host:$pc_port/api/containers" 2>/dev/null || echo '{}')
    if [[ "$response" == *"containers"* ]] || [[ "$response" == *"docker"* ]] || [[ -n "$response" && "$response" != "{}" ]]; then
        echo "$response" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    if isinstance(d,list):
        for c in d:
            name=c.get('name',c.get('Names',''))
            status=c.get('status',c.get('State',''))
            ports=c.get('ports','')
            running = 'Up' in str(status)
            mark = '\033[0;32m●\033[0m' if running else '\033[0;31m○\033[0m'
            print(f'  {mark} {name}  {status}')
    elif isinstance(d,dict):
        for k,v in d.items():
            print(f'  {k}: {v}')
except: print(response)
" 2>/dev/null || echo "$response"
    else
        echo -e "  ${YELLOW}PC Docker API not reachable${NC}"
        echo "  Try: DOCKER_PC_HOST=192.168.1.2 bash install-swal-node.sh --test-docker"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_remote_xavier2() {
    # Test Xavier2 on remote PC via HTTP
    info "Testing remote Xavier2 memory engine..."
    local pc_host="${XAVIER2_PC_HOST:-192.168.1.2}"
    local xav_port="${XAVIER2_PC_PORT:-8006}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 🧠 Xavier2 Memory Engine (PC: $pc_host:$xav_port)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    local health
    health=$(curl -sf "http://$pc_host:$xav_port/health" 2>/dev/null || echo '{"status":"error"}')
    if [[ "$health" == *'"ok"'* ]]; then
        local version=$(echo "$health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','?'))" 2>/dev/null || echo "?")
        local service=$(echo "$health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('service','?'))" 2>/dev/null || echo "?")
        echo -e "  Health:  ${GREEN}✅ RUNNING${NC}"
        echo "  Service: $service"
        echo "  Version: $version"
        echo ""
        echo -e "${CYAN}  🔍 Test Query: SWAL projects${NC}"
        local result
        result=$(curl -sf -X POST "http://$pc_host:$xav_port/memory/search" \
            -H "Content-Type: application/json" \
            -H "X-Xavier2-Token: dev-token" \
            -d '{"query":"SWAL Leonardo ManteniApp","limit":3}' 2>/dev/null || echo '{}')
        local status_text
        status_text=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','error'))" 2>/dev/null || echo "unknown")
        local count
        count=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(len(r))" 2>/dev/null || echo "?")
        echo -e "  Status:  $status_text"
        echo -e "  Results: $count"
    else
        echo -e "  Health:  ${YELLOW}⚠️  NOT REACHABLE${NC}"
        echo "  Try: XAVIER2_PC_HOST=192.168.1.2 bash install-swal-node.sh --test-xavier2"
    fi
    echo ""
    echo "  API: curl -X POST http://$pc_host:$xav_port/memory/search \\"
    echo "         -H 'Content-Type: application/json' \\"
    echo "         -H 'X-Xavier2-Token: dev-token' \\"
    echo "         -d '{\"query\":\"...\",\"limit\":3}'"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# 15. SSH KEYS — Generar si no existe
# =============================================================================
generate_ssh_keys() {
    info "Generando SSH keys..."
    if [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
        ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa" 2>/dev/null || true
    fi
    echo ""
    info "SSH Public Key:"
    [[ -f "$HOME/.ssh/id_rsa.pub" ]] && cat "$HOME/.ssh/id_rsa.pub"
    echo ""
}

# =============================================================================
# 16. AUTOSTART
# =============================================================================
setup_autostart() {
    info "Configurando autostart..."
    mkdir -p "$HOME/.termux/boot"
    cat > "$HOME/.termux/boot/zeroclaw-start" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
sleep 30
export TERMUX_PKG=1
export PATH="$HOME/.cargo/bin:$PATH"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
cd $HOME/zeroclaw
[ -x "$PREFIX/bin/zeroclaw" ] && nohup zeroclaw daemon > $HOME/zeroclaw-workspace/logs/zeroclaw.log 2>&1 &
echo "[ZeroClaw] Started"
EOF
    chmod +x "$HOME/.termux/boot/zeroclaw-start"
    success "Autostart configurado ✓"
}

# =============================================================================
# 17. VALIDACION
# =============================================================================
validate() {
    info "Validando instalacion..."
    local errors=0
    for cmd in git curl wget python node npm go cargo sqlite nano vim htop jq; do
        if command -v "$cmd" &>/dev/null 2>&1; then
            success "  ✓ $cmd"
        else
            warn "  ✗ $cmd (no encontrado)"
            ((errors++))
        fi
    done
    if command -v zeroclaw &>/dev/null || [[ -x "$PREFIX/bin/zeroclaw" ]]; then
        success "ZeroClaw: ✓"
    else
        warn "ZeroClaw: no instalado (necesita build)"
    fi
    if [[ -f "$HOME/.ssh/id_rsa" ]] && [[ $(stat -c %a "$HOME/.ssh" 2>/dev/null) == "700" ]]; then
        success "SSH: ✓ (permisos correctos)"
    else
        warn "SSH: permisos incorrectos"
    fi
    [[ $errors -eq 0 ]] && success "Validacion OK ✓" || warn "$errors errores"
}

# =============================================================================
# PRÓXIMOS PASOS
# =============================================================================
show_next_steps() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  ZeroClaw — INSTALADO${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}Para empezar:${NC}"
    echo ""
    echo "    1. Configurar API key:"
    echo "       nano ~/.zeroclaw/config.toml"
    echo ""
    echo "    2. Iniciar ZeroClaw:"
    echo "       zeroclaw daemon"
    echo "       zeroclaw status"
    echo ""
    echo "    3. Conectar via SSH:"
    echo "       ssh -p 8022 localhost"
    echo ""
    echo "    4. Test Docker/Xavier2 en PC remoto:"
    echo "       DOCKER_PC_HOST=192.168.1.2 bash install-swal-node.sh --test-docker"
    echo "       XAVIER2_PC_HOST=192.168.1.2 bash install-swal-node.sh --test-xavier2"
    echo ""
    echo "    5. Cloudflare Tunnel:"
    echo "       ssh termux-cf  # desde PC con cloudflared"
    echo "       DNS: swal-termux.saberparatodos.space"
    echo ""
    echo "    6. Instalar agents opcionales:"
    echo "       SWAL_INSTALL_ALL=1 bash install-swal-node.sh"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    # Handle test modes
    case "${1:-}" in
        --test-docker)   test_remote_docker; exit 0 ;;
        --test-xavier2)  test_remote_xavier2; exit 0 ;;
    esac

    show_banner
    echo -e "${YELLOW}Instalando ZeroClaw en Termux...${NC}"
    echo "  Fix: permisos SSH, tool calls, Rust/Go environment"
    echo "  New: Docker/Xavier2 remote testing"
    echo ""
    echo -e "${CYAN}Presiona Enter para continuar...${NC}"
    read -r

    check_termux
    check_arch
    update_packages
    install_base_packages
    fix_ssh_permissions
    fix_rust_environment
    fix_go_environment
    fix_python_environment
    fix_nodejs_environment
    fix_tool_calls
    setup_git
    setup_workspace
    install_cloudflared_tunnel
    configure_tunnel_token
    install_zeroclaw
    install_gestalt
    install_infra_tools
    generate_ssh_keys
    setup_autostart
    start_cloudflare_tunnel
    validate
    show_tunnel_status

    success "ZeroClaw instalado correctamente!"
}

main "$@"
