#!/bin/bash
# =============================================================================
# ZeroClaw — Migrate from OpenClaw
# =============================================================================
# Migra el workspace de OpenClaw (EditorOne/host) a ZeroClaw Docker
# y arranca ZeroClaw como agente accesible via HTTP API
#
# Uso:
#   ./migrate-from-openclaw.sh           # Interactive
#   ./migrate-from-openclaw.sh --dry-run
#   ./migrate-from-openclaw.sh --force
# =============================================================================

set -Eeuo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
# Workspace de OpenClaw en el HOST (Windows)
OPENCLAW_HOST_WORKSPACE="C:/Users/belal/.openclaw/workspace"
#OPENCLAW_HOST_WORKSPACE="$HOME/.openclaw/workspace"  # Linux/Mac

# Donde se monta en el Docker
ZEROCLAW_WORKSPACE="/zeroclaw-workspace/openclaw-migrated"

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[MIGRATE]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

# ── Help ─────────────────────────────────────────────────────────────────────
show_help() {
    cat << 'EOF'
ZeroClaw — Migrate from OpenClaw

Opciones:
  --dry-run    Preview sin hacer cambios
  --force      Saltar confirmaciones
  --help       Mostrar esta ayuda

Ambiente:
  OPENCLAW_WORKSPACE   Override del path del workspace de OpenClaw
  ZEROCLAW_API_KEY    API key para el provider

Ejemplos:
  ./migrate-from-openclaw.sh --dry-run
  ./migrate-from-openclaw.sh --force
  OPENCLAW_WORKSPACE=/custom/path ./migrate-from-openclaw.sh
EOF
}

# ── Parse args ───────────────────────────────────────────────────────────────
DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force) FORCE=true ;;
        --help) show_help; exit 0 ;;
    esac
done

# ── Verificar que Docker esté corriendo ──────────────────────────────────────
info "Verificando Docker..."
if ! docker info &>/dev/null; then
    error "Docker no está corriendo. Inicia Docker Desktop."
    exit 1
fi
success "Docker ✓"

# ── Detectar workspace de OpenClaw ─────────────────────────────────────────
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-${OPENCLAW_HOST_WORKSPACE}}"

if [[ ! -d "$OPENCLAW_WORKSPACE" ]]; then
    error "Workspace de OpenClaw no encontrado: $OPENCLAW_WORKSPACE"
    error "Configura OPENCLAW_WORKSPACE si tu path es diferente."
    exit 1
fi

info "Workspace OpenClaw: $OPENCLAW_WORKSPACE"

# Listar contenido
echo ""
info "Contenido del workspace:"
ls -la "$OPENCLAW_WORKSPACE"
echo ""

# ── Verificar que ZeroClaw image exista ─────────────────────────────────────
info "Verificando imagen swal-zeroclaw..."
if docker images swal-zeroclaw &>/dev/null; then
    success "Imagen swal-zeroclaw encontrada ✓"
else
    warn "Imagen swal-zeroclaw no existe."
    warn "Ejecuta primero: docker build -f Dockerfile.swal -t swal-zeroclaw ."
    echo ""
    echo -e "${YELLOW}Construir imagen ahora? [y/N]${NC}"
    if [[ "$FORCE" == "false" ]]; then read -r answer; else answer="y"; fi
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        docker build -f Dockerfile.swal -t swal-zeroclaw . || {
            error "Build falló"
            exit 1
        }
    else
        exit 1
    fi
fi

# ── Crear docker-compose para migración ─────────────────────────────────────
info "Creando docker-compose para migración..."

cat > docker-compose.migrate.yml << EOF
# Migrate OpenClaw → ZeroClaw
services:
  zeroclaw-migrate:
    image: swal-zeroclaw
    container_name: swal-zeroclaw-migrate
    environment:
      - API_KEY=\${API_KEY:-}
      - PROVIDER=\${PROVIDER:-openrouter}
      - DEFAULT_MODEL=\${DEFAULT_MODEL:-anthropic/claude-sonnet-4-20250514}
      - RUST_LOG=info,zeroclaw=debug
    volumes:
      # Montar workspace de OpenClaw como solo-lectura para migración
      - "${OPENCLAW_WORKSPACE}:/zeroclaw-workspace/openclaw-migrated:ro"
      # Workspace destino de ZeroClaw (donde se migra)
      - swal-zeroclaw-data:/zeroclaw-data
    command: >
      sh -c "echo 'Workspace de OpenClaw montado.'
             && echo 'Ejecutando migración...'
             && zeroclaw migrate openclaw
               --source /zeroclaw-workspace/openclaw-migrated
               ${DRY_RUN:+--dry-run}"
    deploy:
      resources:
        limits:
          memory: 1G

volumes:
  swal-zeroclaw-data:
EOF

# ── Dry run ──────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    info "MODO DRY RUN — no se harán cambios"
    echo ""
    docker compose -f docker-compose.migrate.yml config 2>/dev/null && success "Compose válido ✓"
    echo ""
    info "El comando de migración sería:"
    echo "  zeroclaw migrate openclaw --source /zeroclaw-workspace/openclaw-migrated"
    echo ""
    info "dry-run activado — saliendo"
    exit 0
fi

# ── Confirmación ──────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  Se migrará el workspace de OpenClaw a ZeroClaw${NC}"
echo -e "${YELLOW}  Origen:   $OPENCLAW_WORKSPACE${NC}"
echo -e "${YELLOW}  Destino:  /zeroclaw-data/workspace (en Docker volume)${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${RED}  ADVERTENCIA: Esto importará memories y configuración${NC}"
echo -e "${RED}  al workspace de ZeroClaw. Se hará backup automático.${NC}"
echo ""

if [[ "$FORCE" == "false" ]]; then
    echo -e "${CYAN}Continuar? [y/N]${NC}"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        info "Cancelado por usuario."
        exit 0
    fi
fi

# ── Ejecutar migración ───────────────────────────────────────────────────────
echo ""
info "Iniciando migración..."

# Limpiar containers anteriores
docker compose -f docker-compose.migrate.yml down &>/dev/null || true

# Run migration
if docker compose -f docker-compose.migrate.yml up --remove-orphans; then
    success "Migración completada ✓"
else
    error "Migración falló"
    exit 1
fi

# ── Mostrar resultado ───────────────────────────────────────────────────────
echo ""
info "Memoria migrada — verificando..."
docker compose -f docker-compose.migrate.yml run --rm zeroclaw-migrate \
    zeroclaw memory list 2>/dev/null || true

echo ""
success "Migración lista!"
echo ""
echo -e "${CYAN}Para iniciar ZeroClaw como agente:${NC}"
echo "  docker compose -f docker-compose.swal.yml up -d"
echo ""
echo -e "${CYAN}Gateway estará en: http://localhost:42617${NC}"
