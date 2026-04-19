#!/bin/bash
# =============================================================================
# ZeroClaw SWAL Node — Termux Installer
# =============================================================================
# SouthWest AI Labs — ZeroClaw + Gestalt Swarm + Cortex para Termux
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/main/install-swal-node.sh | bash
#
# O localmente:
#   bash install-swal-node.sh
#
# Requisitos:
#   - Termux (Android o emulador)
#   - Git, curl, tar instalados via pkg
#   - API keys para providers (OpenRouter, Groq, etc.)
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="install-swal-node.sh"
readonly SCRIPT_VERSION="2026-04-19.1"
readonly REPO_OWNER="iberi22"
readonly REPO_NAME="zeroclaw-termux-dev-setup"
readonly BRANCH="main"
readonly INSTALL_DIR="$HOME/zeroclaw-swal"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Log
LOG_FILE="$INSTALL_DIR/install.log"

log() {
    local color="$1"; shift
    printf "%b%s%b %s\n" "$color" "[SWAL]" "$NC" "$*"
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
    fi
}
info()    { log "$CYAN" "INFO" "$@"; }
success() { log "$GREEN" "OK" "$@"; }
warn()    { log "$YELLOW" "WARN" "$@"; }
error()   { log "$RED" "ERROR" "$@"; }

cleanup() {
    local exit_code=$?
    local elapsed=$(($(date +%s) - SCRIPT_START_TS))
    if [[ $exit_code -eq 0 ]]; then
        success "Instalación completada en ${elapsed}s."
        show_next_steps
    else
        error "Instalación falló (code $exit_code) tras ${elapsed}s."
        error "Revisa $LOG_FILE para detalles."
    fi
    exit $exit_code
}
trap cleanup EXIT

SCRIPT_START_TS=$(date +%s)

# =============================================================================
# Banner
# =============================================================================
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "============================================================"
    echo "  ZeroClaw SWAL Node — Termux Installer v${SCRIPT_VERSION}"
    echo "  SouthWest AI Labs ⚡"
    echo "============================================================"
    echo -e "${NC}\n"
}

# =============================================================================
# Verificaciones
# =============================================================================
check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        error "Este script debe ejecutarse en Termux."
        exit 1
    fi
    info "Termux detectado ✓"
}

check_dependencies() {
    info "Verificando dependencias..."

    local tools=("git" "curl" "tar")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            info "Instalando ${tool}..."
            pkg update -y && pkg install -y "$tool" 2>/dev/null || {
                error "No se pudo instalar ${tool}."
                exit 1
            }
        fi
    done
    success "Dependencias verificadas ✓"
}

# =============================================================================
# Clonación del repositorio
# =============================================================================
setup_repo() {
    info "Preparando repositorio SWAL..."

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "Repositorio existente — actualizando..."
        git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH" 2>/dev/null || \
            warn "No se pudo actualizar. Usando versión existente."
    elif [[ -d "$INSTALL_DIR" ]]; then
        warn "Directorio existente sin repo. Moviendo..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date '+%Y%m%d%H%M%S')"
    fi

    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
        info "Clonando zeroclaw-termux-dev-setup..."
        git clone --depth 1 --branch "$BRANCH" \
            "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" \
            "$INSTALL_DIR" || {
            error "Falló el clone del repositorio."
            exit 1
        }
    fi

    mkdir -p "$INSTALL_DIR/logs"
    success "Repositorio listo ✓"
}

# =============================================================================
# Instalación de Rust
# =============================================================================
install_rust() {
    if command -v rustc >/dev/null 2>&1; then
        local rustv=$(rustc --version | awk '{print $2}')
        info "Rust ${rustv} ya instalado ✓"
        return 0
    fi

    info "Instalando Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable 2>/dev/null || {
        error "Falló instalación de Rust."
        exit 1
    }

    # Activar rust en sesión actual
    export PATH="$HOME/.cargo/bin:$PATH"
    source "$HOME/.cargo/env" 2>/dev/null || true

    success "Rust instalado ✓"
}

# =============================================================================
# Build de ZeroClaw
# =============================================================================
build_zeroclaw() {
    info "Compilando ZeroClaw (puede tomar 10-30 minutos en Termux)..."

    cd "$INSTALL_DIR"

    # Features recomendados para Termux
    local features="channel-nostr"
    local build_cmd="cargo build --release --locked --features '${features}'"

    # En Termux con recursos limitados, usar single-threaded
    if [[ -d "/data/data/com.termux" ]]; then
        warn "Termux detectado — usando build optimizado para memoria baja..."
        export CARGO_BUILD_JOBS=2
        export RUSTFLAGS="-C codegen-units=1"
    fi

    # Build con logs
    if RUST_LOG=info cargo build --release --locked --features "${features}" 2>&1 | tee -a "$LOG_FILE"; then
        success "ZeroClaw compilado ✓"
    else
        error "Build de ZeroClaw falló."
        error "Revisa $LOG_FILE para detalles del error."
        return 1
    fi

    # Verificar binary
    local binary="$INSTALL_DIR/target/release/zeroclaw"
    if [[ ! -f "$binary" ]]; then
        error "Binary no encontrado después del build."
        return 1
    fi

    local size=$(stat -c%s "$binary" 2>/dev/null || echo "0")
    info "Binary: ${size} bytes"

    if [[ $size -lt 1000000 ]]; then
        warn "Binary muy pequeño — puede ser incompleto."
    fi

    # Install globally
    mkdir -p "$HOME/.local/bin"
    cp "$binary" "$HOME/.local/bin/zeroclaw"
    chmod +x "$HOME/.local/bin/zeroclaw"

    success "ZeroClaw instalado en ~/.local/bin/zeroclaw ✓"
}

# =============================================================================
# Build de Gestalt Swarm (opcional)
# =============================================================================
build_gestalt() {
    if [[ "${SWAL_INSTALL_GESTALT:-no}" != "si" ]]; then
        info "Gestalt Swarm omitido (usar SWAL_INSTALL_GESTALT=si para instalar)."
        return 0
    fi

    info "Compilando Gestalt Swarm..."

    local gestalt_dir="$HOME/gestalt-rust"
    if [[ ! -d "$gestalt_dir/.git" ]]; then
        git clone --depth 1 https://github.com/iberi22/gestalt-rust.git "$gestalt_dir" 2>/dev/null || {
            warn "No se pudo clonar gestalt-rust. Omitiendo."
            return 0
        }
    fi

    cd "$gestalt_dir"
    if cargo build --release -p gestalt_swarm 2>&1 | tee -a "$LOG_FILE"; then
        mkdir -p "$HOME/.local/bin"
        cp target/release/gestalt_swarm "$HOME/.local/bin/" 2>/dev/null
        chmod +x "$HOME/.local/bin/gestalt_swarm" 2>/dev/null
        success "Gestalt Swarm instalado ✓"
    else
        warn "Build de Gestalt Swarm falló. Continuando sin él."
    fi
}

# =============================================================================
# Configuración inicial
# =============================================================================
setup_config() {
    info "Configurando ZeroClaw SWAL Node..."

    local config_dir="$HOME/.zeroclaw"
    local workspace_dir="$HOME/.zeroclaw/workspace"
    local skills_dir="$workspace_dir/skills"

    mkdir -p "$config_dir" "$workspace_dir" "$skills_dir"

    # Detectar API key de ambiente si existe
    local api_key="${API_KEY:-}"
    local provider="${PROVIDER:-openrouter}"
    local model="${MODEL:-anthropic/claude-sonnet-4-20250514}"

    cat > "$config_dir/config.toml" << EOF
# ZeroClaw SWAL Node Configuration
# SouthWest AI Labs

workspace_dir = "${workspace_dir}"
config_path = "${config_dir}/config.toml"

# ── Provider ────────────────────────────────────────────────────────────────
api_key = "${api_key}"
default_provider = "${provider}"
default_model = "${model}"
default_temperature = 0.7

# ── Gateway ─────────────────────────────────────────────────────────────────
[gateway]
port = 42617
host = "127.0.0.1"
allow_public_bind = false
require_pairing = true

# ── Autonomy ─────────────────────────────────────────────────────────────────
[autonomy]
level = "supervised"
auto_approve = [
    "file_read",
    "memory_recall",
    "memory_store",
    "web_search_tool",
    "web_fetch",
    "calculator",
    "glob_search",
    "content_search",
    "weather"
]

# ── SWAL Cortex ──────────────────────────────────────────────────────────────
[cortex]
enabled = true
url = "http://localhost:8003"
token = "dev-token"

# ── SWAL Gestalt ─────────────────────────────────────────────────────────────
[gestalt]
enabled = false
swarm_path = "${HOME}/.local/bin/gestalt_swarm"

# ── Skills ──────────────────────────────────────────────────────────────────
[skills]
open_skills_enabled = true
EOF

    # Clonar SWAL skills si git disponible
    if command -v git >/dev/null 2>&1; then
        info "Clonando SWAL skills..."
        local swal_skills_dir="$workspace_dir/skills/swal"
        if [[ ! -d "$swal_skills_dir/.git" ]]; then
            git clone --depth 1 https://github.com/iberi22/swal-skills.git "$swal_skills_dir" 2>/dev/null || \
                warn "No se pudieron clonar SWAL skills."
        fi
    fi

    success "Configuración guardada ✓"
}

# =============================================================================
# Instalación de API keys como secrets
# =============================================================================
setup_secrets() {
    info "Configurando API keys..."

    local secrets_file="$HOME/.zeroclaw/secrets.env"

    if [[ -f "$secrets_file" ]] && grep -q "API_KEY=" "$secrets_file" 2>/dev/null; then
        info "Secrets ya configurados. Omitiendo."
        return 0
    fi

    echo "# ZeroClaw SWAL — API Keys" > "$secrets_file"
    echo "# NO compartas este archivo!" >> "$secrets_file"
    echo "" >> "$secrets_file"
    echo "API_KEY=${API_KEY:-}" >> "$secrets_file"
    echo "GROQ_API_KEY=${GROQ_API_KEY:-}" >> "$secrets_file"
    echo "GEMINI_API_KEY=${GEMINI_API_KEY:-}" >> "$secrets_file"

    chmod 600 "$secrets_file"
    info "Secrets configurados (archivo: $secrets_file)"
    info "Edita el archivo para añadir tus API keys."
}

# =============================================================================
# Validación final
# =============================================================================
validate() {
    info "Validando instalación..."

    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

    if command -v zeroclaw >/dev/null 2>&1; then
        local ver=$(zeroclaw --version 2>/dev/null || echo "unknown")
        success "ZeroClaw: $ver ✓"
    else
        warn "ZeroClaw no está en PATH."
        warn "Añade a ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    if command -v gestalt_swarm >/dev/null 2>&1; then
        success "Gestalt Swarm: ✓"
    else
        info "Gestalt Swarm: no instalado (opcional)"
    fi

    success "Validación completada ✓"
}

# =============================================================================
# Próximos pasos
# =============================================================================
show_next_steps() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  Instalación SWAL Node completada!${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}Próximos pasos:${NC}"
    echo ""
    echo -e "  1. ${CYAN}Configurar API keys:${NC}"
    echo -e "     nano ~/.zeroclaw/secrets.env"
    echo ""
    echo -e "  2. ${CYAN}Activar PATH (si no está):${NC}"
    echo -e "     echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo -e "     source ~/.bashrc"
    echo ""
    echo -e "  3. ${CYAN}Iniciar ZeroClaw:${NC}"
    echo -e "     zeroclaw onboard --interactive"
    echo -e "     # o"
    echo -e "     zeroclaw daemon"
    echo ""
    echo -e "  4. ${CYAN}Comandos útiles:${NC}"
    echo -e "     zeroclaw status        # Estado del nodo"
    echo -e "     zeroclaw doctor         # Diagnóstico"
    echo -e "     zeroclaw skills list    # Skills instalados"
    echo -e "     zeroclaw agent -m 'Hi'  # Test rápido"
    echo ""
    echo -e "  5. ${CYAN}Integrar con Cortex (desde EditorOne):${NC}"
    echo -e "     # Asegúrate que Cortex esté corriendo"
    echo -e "     curl http://localhost:8003/health"
    echo ""
    echo -e "  ${YELLOW}Docker (en EditorOne/PC):${NC}"
    echo -e "     cd $INSTALL_DIR"
    echo -e "     cp env.swal.example .env.swal"
    echo -e "     # Editar .env.swal con API keys"
    echo -e "     docker compose -f docker-compose.swal.yml up -d"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================
main() {
    show_banner

    echo -e "${YELLOW}Este script instalará:${NC}"
    echo "  • ZeroClaw (Rust AI Agent Runtime)"
    echo "  • Gestalt Swarm CLI (opcional, con SWAL_INSTALL_GESTALT=si)"
    echo "  • SWAL Skills (cortex-memory, gestalt-swarm, etc.)"
    echo "  • Configuración inicial"
    echo ""
    echo -e "${CYAN}Presiona Enter para continuar...${NC}"
    read -r

    check_termux
    check_dependencies
    setup_repo
    install_rust
    build_zeroclaw
    build_gestalt
    setup_config
    setup_secrets
    validate

    echo ""
    success "ZeroClaw SWAL Node instalado correctamente!"
}

main "$@"
