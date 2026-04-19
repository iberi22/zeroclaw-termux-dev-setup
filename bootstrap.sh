#!/bin/bash
# =============================================================================
# ZeroClaw SWARM Node — Bootstrap
# =============================================================================
# curl -fsSL https://tu-repo-interno.com/bootstrap.sh | bash
# =============================================================================
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[BOOT]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

REPO_URL="${REPO_URL:-https://github.com/iberi22/zeroclaw-termux-dev-setup.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/zeroclaw-swan-node}"

echo -e "${CYAN}"
echo "============================================================"
echo "  ZeroClaw SWARM Node — Bootstrap"
echo "  CLI Agents + Infrastructure Tools + Dev Environment"
echo "============================================================"
echo -e "${NC}\n"

# ── Docker ─────────────────────────────────────────────────────────────────
info "Verificando Docker..."
if ! command -v docker &>/dev/null; then
    echo -e "${YELLOW}Docker no instalado. Instalando...${NC}"
    curl -fsSL https://get.docker.com | sh || { error "Docker failed"; exit 1; }
fi
docker info &>/dev/null || { error "Docker no corriendo"; exit 1; }
success "Docker ✓"

# ── Git ────────────────────────────────────────────────────────────────────
command -v git &>/dev/null || apt-get install -y git 2>/dev/null || true

# ── Clone ─────────────────────────────────────────────────────────────────
info "Clonando proyecto..."
[[ -d "$INSTALL_DIR" ]] && git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || \
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || \
    { error "Clone failed"; exit 1; }
cd "$INSTALL_DIR"
success "Proyecto listo ✓"

# ── Config ─────────────────────────────────────────────────────────────────
[[ ! -f config/.env ]] && cp config/.env.example config/.env 2>/dev/null || true

echo ""
echo -e "${YELLOW}!!! IMPORTANTE !!!${NC}"
echo "Edita ${CYAN}config/.env${NC} y añade tu API_KEY"
echo "Sin API_KEY, el agente no tiene acceso a LLM."
echo -e "  nano config/.env"
echo ""

# ── Build args para agentes opcionales ───────────────────────────────────
DOCKER_BUILD_ARGS="--build-arg INSTALL_JULES=${INSTALL_JULES:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_CLAUDE_CODE=${INSTALL_CLAUDE_CODE:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_OPENCODE=${INSTALL_OPENCODE:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_GEMINI_CLI=${INSTALL_GEMINI_CLI:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_SUPABASE=${INSTALL_SUPABASE:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_AWS=${INSTALL_AWS:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_GCP=${INSTALL_GCP:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_CLOUDFLARE=${INSTALL_CLOUDFLARE:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_TERRAFORM=${INSTALL_TERRAFORM:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_PULUMI=${INSTALL_PULUMI:-true}"
DOCKER_BUILD_ARGS="$DOCKER_BUILD_ARGS --build-arg INSTALL_FLUTTER=${INSTALL_FLUTTER:-false}"

# ── Build ─────────────────────────────────────────────────────────────────
info "Build de imagen Docker (primera vez: 15-30 min)..."
echo "Instalando por defecto: ZeroClaw, Gestalt, Jules, Claude Code,"
echo "OpenCode, Gemini CLI, Supabase, AWS, GCP, Cloudflare,"
echo "Terraform, Pulumi, Bun, Deno, PHP/Composer, Rust/Cargo"

eval docker build $DOCKER_BUILD_ARGS -t zeroclaw-swan-node:latest . || {
    error "Build failed"
    exit 1
}
success "Build ✓"

# ── Start ─────────────────────────────────────────────────────────────────
info "Iniciando nodo..."
docker compose up -d
sleep 5

# ── Status ────────────────────────────────────────────────────────────────
if curl -sf http://localhost:42617/health &>/dev/null; then
    success "NODO CORRIENDO ✓"
else
    warn "Gateway no responde — verificar: docker compose logs"
fi

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  ZeroClaw SWARM — INSTALADO${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "  ${GREEN}Gateway:${NC}  http://localhost:42617"
echo -e "  ${GREEN}SSH:${NC}     localhost:2222"
echo -e "  ${GREEN}Dir:${NC}     $INSTALL_DIR"
echo ""
echo -e "  CLI Agents:   Jules, Claude Code, OpenCode, Gemini CLI"
echo -e "  Infra CLIs:  Supabase, AWS, GCP, Cloudflare, Terraform, Pulumi"
echo -e "  Dev:         Python, Node, Go, Rust, Bun, Deno, PHP"
echo ""
echo -e "  Comandos:"
echo -e "    cd $INSTALL_DIR && ./scripts/status.sh"
echo -e "    ./scripts/logs.sh / ./scripts/stop.sh"
echo ""
echo -e "${CYAN}============================================================${NC}"
