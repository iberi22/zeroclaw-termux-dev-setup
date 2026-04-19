#!/bin/bash
# =============================================================================
# ZeroClaw SWARM Node — Replicate
# =============================================================================
# Descarga y configura un nuevo nodo idéntico en otra máquina
# Usage:
#   ./replicate.sh                              # Interactivo
#   ./replicate.sh --source ssh://user@host:2222  # Desde nodo existente
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; NC='\033[0m'

log() { printf "%b[REPLICATE]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

# ── Help ─────────────────────────────────────────────────────────────────────
show_help() {
    cat << 'EOF'
ZeroClaw SWARM Node — Replicate

Descarga y configura un nuevo nodo ZeroClaw idéntico en otra máquina.

Uso:
  ./replicate.sh [opciones]

Opciones:
  --source SSH_URL   Nodo fuente para replicar config (ej: ssh://root@192.168.1.100:2222)
  --ip IP            IP del nodo fuente
  --ssh-port PORT    Puerto SSH del nodo fuente (default: 2222)
  --dir DIR          Directorio de instalación (default: ~/zeroclaw-swan-node)
  --skip-copy        No copiar config del nodo fuente (solo clonar repo)
  --help             Mostrar ayuda

Ejemplos:
  # Interactivo
  ./replicate.sh

  # Desde nodo existente en 192.168.1.100
  ./replicate.sh --ip 192.168.1.100

  # Desde SSH custom
  ./replicate.sh --source ssh://root@mi-nodo.com:2222

  # Solo clonar repo sin copiar config
  ./replicate.sh --skip-copy

El script:
  1. Verifica Docker en la máquina destino
  2. Clona el repositorio del nodo
  3. Copia config/keys del nodo fuente via SSH
  4. Build + start del nuevo nodo
EOF
}

# ── Parse args ───────────────────────────────────────────────────────────────
SOURCE_IP=""
SOURCE_SSH_PORT="2222"
SOURCE_SSH_USER="root"
INSTALL_DIR=""
SKIP_COPY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            SOURCE_URL="$2"
            # Parse user@host:port from URL or SSH style
            if [[ "$SOURCE_URL" =~ ^ssh://([^@]+)@([^:]+):([0-9]+)$ ]]; then
                SOURCE_SSH_USER="${BASH_REMATCH[1]}"
                SOURCE_IP="${BASH_REMATCH[2]}"
                SOURCE_SSH_PORT="${BASH_REMATCH[3]}"
            elif [[ "$SOURCE_URL" =~ ^([^@]+)@([^:]+):([0-9]+)$ ]]; then
                SOURCE_SSH_USER="${BASH_REMATCH[1]}"
                SOURCE_IP="${BASH_REMATCH[2]}"
                SOURCE_SSH_PORT="${BASH_REMATCH[3]}"
            elif [[ "$SOURCE_URL" =~ ^ssh://([^@]+)@([^:/]+)(:[0-9]+)?$ ]]; then
                SOURCE_SSH_USER="${BASH_REMATCH[1]}"
                SOURCE_IP="${BASH_REMATCH[2]}"
                SOURCE_SSH_PORT="${BASH_REMATCH[3]:1:-1:-1:-1}"
                SOURCE_SSH_PORT="${SOURCE_SSH_PORT:-2222}"
            elif [[ "$SOURCE_URL" =~ ^([^@]+)@([^:]+)$ ]]; then
                SOURCE_SSH_USER="${BASH_REMATCH[1]}"
                SOURCE_IP="${BASH_REMATCH[2]}"
            fi
            shift 2 ;;
        --ip) SOURCE_IP="$2"; shift 2 ;;
        --ssh-port) SOURCE_SSH_PORT="$2"; shift 2 ;;
        --dir) INSTALL_DIR="$2"; shift 2 ;;
        --skip-copy) SKIP_COPY=true; shift ;;
        --help) show_help; exit 0 ;;
        *) shift ;;
    esac
done

# ── Banner ───────────────────────────────────────────────────────────────────
echo -e "${CYAN}"
echo "============================================================"
echo "  ZeroClaw SWARM Node — Replicate"
echo "============================================================"
echo -e "${NC}\n"

# ── 1. Verificar Docker ───────────────────────────────────────────────────────
info "Verificando Docker..."
if ! command -v docker &>/dev/null; then
    error "Docker no instalado. Instalar primero:"
    echo "  curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! docker info &>/dev/null; then
    error "Docker no está corriendo. Iniciar Docker Desktop."
    exit 1
fi
success "Docker ✓"

# ── 2. Obtener info del nodo fuente ─────────────────────────────────────────
if [[ -z "$SOURCE_IP" ]]; then
    echo -e "${YELLOW}IP del nodo fuente:${NC}"
    read -rp "  IP/hostname: " SOURCE_IP
    SOURCE_IP="${SOURCE_IP:-}"
fi

if [[ -z "$SOURCE_IP" ]]; then
    warn "Sin nodo fuente — instalando desde repo (sin config)"
    SKIP_COPY=true
fi

# ── 3. Directorio de instalación ─────────────────────────────────────────────
if [[ -z "$INSTALL_DIR" ]]; then
    INSTALL_DIR="${INSTALL_DIR:-$HOME/zeroclaw-swan-node}"
fi

info "Directorio: $INSTALL_DIR"

# ── 4. Clonar repo ────────────────────────────────────────────────────────────
info "Clonando repositorio..."

# Detectar repo del nodo actual
REPO_URL="https://github.com/iberi22/zeroclaw-termux-dev-setup.git"
if [[ -d "$(dirname "$0")/.git" ]]; then
    REPO_URL=$(git -C "$(dirname "$0")" remote get-url origin 2>/dev/null || echo "$REPO_URL")
fi

if [[ -d "$INSTALL_DIR" ]]; then
    warn "Directorio existe — actualizando..."
    if command -v git &>/dev/null; then
        git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || \
            warn "No se pudo actualizar"
    fi
else
    git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
        error "No se pudo clonar repo"
        exit 1
    }
fi
success "Repo listo ✓"

cd "$INSTALL_DIR"

# ── 5. Copiar config del nodo fuente ─────────────────────────────────────────
if [[ "$SKIP_COPY" == "false" ]] && [[ -n "$SOURCE_IP" ]]; then
    info "Copiando config desde $SOURCE_SSH_USER@$SOURCE_IP:$SOURCE_SSH_PORT..."

    # SSH key del nodo fuente
    SSH_KEY=$(ssh-keyscan -H -p "$SOURCE_SSH_PORT" "$SOURCE_IP" 2>/dev/null | head -1)
    if [[ -n "$SSH_KEY" ]]; then
        mkdir -p "$HOME/.ssh"
        echo "$SSH_KEY" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
    fi

    # Copiar .env (con API keys)
    info "Copiando config..."
    if scp -P "$SOURCE_SSH_PORT" \
        "$SOURCE_SSH_USER@$SOURCE_IP:/zeroclaw-swan-node/config/.env" \
        "$INSTALL_DIR/config/.env" 2>/dev/null; then
        success "Config copiada ✓"
    else
        warn "No se pudo copiar config — usando .env.example"
        cp "$INSTALL_DIR/config/.env.example" \
           "$INSTALL_DIR/config/.env"
    fi

    # Copiar SSH keys
    info "Copiando SSH keys..."
    mkdir -p "$INSTALL_DIR/volumes/ssh"
    scp -P "$SOURCE_SSH_PORT" \
        "$SOURCE_SSH_USER@$SOURCE_IP:/zeroclaw-swan-node/volumes/ssh/id_rsa" \
        "$INSTALL_DIR/volumes/ssh/id_rsa" 2>/dev/null && \
    scp -P "$SOURCE_SSH_PORT" \
        "$SOURCE_SSH_USER@$SOURCE_IP:/zeroclaw-swan-node/volumes/ssh/id_rsa.pub" \
        "$INSTALL_DIR/volumes/ssh/id_rsa.pub" 2>/dev/null && \
        chmod 600 "$INSTALL_DIR/volumes/ssh/id_rsa" && \
        success "SSH keys copiadas ✓" || \
        warn "No se pudieron copiar SSH keys"
else
    info "Instalando sin config previa..."
    cp config/.env.example config/.env
    mkdir -p volumes/ssh
fi

# ── 6. Build + Start ─────────────────────────────────────────────────────────
info "Build de imagen Docker..."
docker build -t zeroclaw-swan-node:latest . || {
    error "Build falló"
    exit 1
}
success "Build ✓"

info "Iniciando nodo..."
if [[ -f scripts/start.sh ]]; then
    bash scripts/start.sh
else
    docker compose up -d
fi

echo ""
success "NODO REPLICADO!"
echo ""
echo -e "${CYAN}Gateway:${NC} http://localhost:42617"
echo -e "${CYAN}SSH:${NC} localhost:2222"
echo -e "${CYAN}Dir:${NC} $INSTALL_DIR"
echo ""
echo -e "Ver estado: cd $INSTALL_DIR && ./scripts/status.sh"
echo ""
