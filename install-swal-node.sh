#!/bin/bash
# =============================================================================
# ZeroClaw SWAL Agent — Termux Full Setup
# =============================================================================
# Instalación completa para Termux con TODOS los privilegios
# El agente tendrá control total del sistema
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/main/install-swal-node.sh | bash
#
# O localmente:
#   bash install-swal-node.sh
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="install-swal-node.sh"
readonly SCRIPT_VERSION="2026-04-19.1"
readonly REPO_OWNER="iberi22"
readonly REPO_NAME="zeroclaw-termux-dev-setup"
readonly BRANCH="main"
readonly INSTALL_DIR="$HOME/zeroclaw-swal"

# ── Colores ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

LOG_FILE="$INSTALL_DIR/install.log"
SCRIPT_START_TS=$(date +%s)

# ── Logging ─────────────────────────────────────────────────────────────────
log() {
    local color="$1"; shift
    printf "%b[SWAL]%b %s\n" "$color" "$NC" "$*"
    [[ -d "$INSTALL_DIR" ]] && echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
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
        [[ -f "$LOG_FILE" ]] && tail -20 "$LOG_FILE"
    fi
    exit $exit_code
}
trap cleanup EXIT

# ── Banner ──────────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "============================================================"
    echo "  ZeroClaw SWAL Agent — Termux Full Setup v${SCRIPT_VERSION}"
    echo "  SouthWest AI Labs ⚡"
    echo "============================================================"
    echo -e "${NC}\n"
}

# ── 1. Verificaciones ───────────────────────────────────────────────────────
check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        error "Este script debe ejecutarse en Termux."
        exit 1
    fi
    info "Termux detectado ✓"
}

check_dependencies() {
    info "Instalando dependencias base..."

    pkg update -y 2>/dev/null || true

    local tools=(
        "git"
        "curl"
        "wget"
        "tar"
        " unzip"
        "openssh"
        "nodejs"
        "rust"
        "python"
        "make"
        "cmake"
        "clang"
        "ninja"
        "pkg-config"
        "libsqlite"
    )

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            info "Instalando ${tool}..."
            pkg install -y "$tool" 2>/dev/null || warn "No se pudo instalar ${tool}"
        fi
    done

    # Instalar python-pip si no existe
    if ! command -v pip &>/dev/null; then
        pkg install -y python-pip 2>/dev/null || true
    fi

    success "Dependencias base instaladas ✓"
}

# ── 2. Repositorio ───────────────────────────────────────────────────────────
setup_repo() {
    info "Descargando SWAL ZeroClaw..."

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "Repositorio existente — actualizando..."
        git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH" 2>/dev/null || \
            warn "No se pudo actualizar"
    elif [[ -d "$INSTALL_DIR" ]]; then
        mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date '+%Y%m%d%H%M%S')"
    fi

    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
        info "Clonando repositorio..."
        git clone --depth 1 --branch "$BRANCH" \
            "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" \
            "$INSTALL_DIR" || {
            error "Falló el clone"
            exit 1
        }
    fi

    mkdir -p "$INSTALL_DIR/logs"
    success "Repositorio listo ✓"
}

# ── 3. Desarrollo completo ─────────────────────────────────────────────────
setup_dev_environment() {
    info "Configurando entorno de desarrollo completo..."

    # ── Python ──────────────────────────────────────────────────────────────
    info "Python environment..."
    pip install --upgrade pip 2>/dev/null || true
    pip install requests httpx 2>/dev/null || true

    # ── Node.js ─────────────────────────────────────────────────────────────
    info "Node.js environment..."
    if command -v npm &>/dev/null; then
        npm install -g npm@latest 2>/dev/null || true
    fi

    # ── Rust ─────────────────────────────────────────────────────────────────
    info "Rust environment..."
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null || {
            warn "Rust installation failed"
        }
    fi

    # Activar rust en sesión actual
    export PATH="$HOME/.cargo/bin:$PATH"
    source "$HOME/.cargo/env" 2>/dev/null || true

    # ── Go ───────────────────────────────────────────────────────────────────
    if ! command -v go &>/dev/null; then
        pkg install -y golang 2>/dev/null || true
    fi

    # ── Build tools ─────────────────────────────────────────────────────────
    info "Build tools..."
    for tool in make cmake ninja binutils; do
        if ! command -v "$tool" &>/dev/null; then
            pkg install -y "$tool" 2>/dev/null || true
        fi
    done

    # ── Git configuration ──────────────────────────────────────────────────
    info "Git configuration..."
    if [[ ! -f "$HOME/.gitconfig" ]]; then
        cat > "$HOME/.gitconfig" << 'EOF'
[user]
    name = SWAL Agent
    email = agent@swal.local
[core]
    editor = nano
    autocrlf = input
[pull]
    rebase = false
[init]
    defaultBranch = main
EOF
    fi

    success "Entorno de desarrollo listo ✓"
}

# ── 4. Build ZeroClaw ───────────────────────────────────────────────────────
build_zeroclaw() {
    info "Compilando ZeroClaw (10-30 min en Termux)..."

    cd "$INSTALL_DIR"

    # Features completos
    local features="channel-nostr,channel-lark,whatsapp-web"

    # En Termux, limitar jobs por memoria
    export CARGO_BUILD_JOBS=2
    export RUSTFLAGS="-C codegen-units=1"

    # Build
    if RUST_LOG=info cargo build --release --locked --features "${features}" 2>&1 | tee -a "$LOG_FILE"; then
        success "ZeroClaw compilado ✓"
    else
        error "Build falló. Revisa $LOG_FILE"
        return 1
    fi

    local binary="$INSTALL_DIR/target/release/zeroclaw"
    if [[ ! -f "$binary" ]]; then
        error "Binary no encontrado"
        return 1
    fi

    local size=$(stat -c%s "$binary" 2>/dev/null || echo "0")
    info "Binary: ${size} bytes"

    # Install
    mkdir -p "$HOME/.local/bin"
    cp "$binary" "$HOME/.local/bin/zeroclaw"
    chmod +x "$HOME/.local/bin/zeroclaw"

    success "ZeroClaw instalado en ~/.local/bin/zeroclaw ✓"
}

# ── 5. Build Gestalt Swarm ──────────────────────────────────────────────────
build_gestalt() {
    info "Compilando Gestalt Swarm..."

    local gestalt_dir="$HOME/gestalt-rust"

    if [[ ! -d "$gestalt_dir/.git" ]]; then
        git clone --depth 1 https://github.com/iberi22/gestalt-rust.git "$gestalt_dir" 2>/dev/null || {
            warn "No se pudo clonar gestalt-rust"
            return 0
        }
    fi

    cd "$gestalt_dir"
    export CARGO_BUILD_JOBS=2
    export RUSTFLAGS="-C codegen-units=1"

    if cargo build --release -p gestalt_swarm 2>&1 | tee -a "$LOG_FILE"; then
        cp target/release/gestalt_swarm "$HOME/.local/bin/" 2>/dev/null
        chmod +x "$HOME/.local/bin/gestalt_swarm" 2>/dev/null
        success "Gestalt Swarm instalado ✓"
    else
        warn "Gestalt Swarm build failed — continuando sin él"
    fi
}

# ── 6. SSH Server ──────────────────────────────────────────────────────────
setup_ssh() {
    info "Configurando SSH para acceso remoto..."

    # Generar keys SSH si no existen
    if [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
        mkdir -p "$HOME/.ssh"
        ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa" 2>/dev/null || true
    fi

    # Configurar sshd
    mkdir -p "$PREFIX/var/run"
    mkdir -p "$PREFIX/etc/ssh"

    # Config sshd para Termux
    cat > "$PREFIX/etc/ssh/sshd_config" << 'EOF'
Port 8022
AuthorizedKeysFile %h/.ssh/authorized_keys
PasswordAuthentication no
PermitRootLogin yes
UseDNS no
EOF

    # Mostrar info de conexión
    echo ""
    info "SSH configurado:"
    echo "  Puerto: 8022"
    echo "  Host: $(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' || echo 'IP local')"
    echo "  Key pública:"
    [[ -f "$HOME/.ssh/id_rsa.pub" ]] && cat "$HOME/.ssh/id_rsa.pub"
    echo ""

    success "SSH listo ✓"
}

# ── 7. Zsh + Oh My Zsh ─────────────────────────────────────────────────────
setup_zsh() {
    info "Configurando Zsh + Oh My Zsh..."

    # Instalar zsh si no existe
    if ! command -v zsh &>/dev/null; then
        pkg install -y zsh 2>/dev/null || true
    fi

    # Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh 2>/dev/null | \
            sh -s -- --unattended 2>/dev/null || true
    fi

    # Plugins útiles
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$plugins_dir"

    # zsh-autosuggestions
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions" 2>/dev/null || true
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting" 2>/dev/null || true
    fi

    # Configurar .zshrc
    cat > "$HOME/.zshrc" << 'EOF'
# ── SWAL Agent Zsh Config ──────────────────────────────────────────────────

# Path
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# Rust
export RUST_BACKTRACE=1

# Editor
export EDITOR=nano

# Aliases útiles para el agente
alias sw='cd $HOME/zeroclaw-swal'
alias gs='git status'
alias gl='git log --oneline -10'
alias gp='git push'
alias gpl='git pull'
alias za='zeroclaw agent'
alias zs='zeroclaw status'
alias zd='zeroclaw daemon'
alias gg='gestalt_swarm'

# ZeroClaw
export ZEROCLAW_WORKSPACE=$HOME/zeroclaw-workspace
export ZEROCLAW_CONFIG=$HOME/.zeroclaw/config.toml

# Oh My Zsh
ZSH_THEME="robbyrussell"
plugins=(git docker node npm rust python)

# Cargar oh my zsh
export NVM_DIR="$HOME/.nvm"
EOF

    success "Zsh configurado ✓"
}

# ── 8. Workspace del Agente ────────────────────────────────────────────────
setup_workspace() {
    info "Creando workspace del agente..."

    local workspace="$HOME/zeroclaw-workspace"
    mkdir -p "$workspace"/{projects,skills,memory,logs}

    # Clonar proyectos SWAL como submodules del workspace
    local projects_dir="$workspace/projects"

    # Lista de proyectos a clonar
    declare -a SWAL_PROJECTS=(
        "https://github.com/iberi22/gestalt-rust.git"
        "https://github.com/iberi22/swal-skills.git"
        "https://github.com/iberi22/termux-dev-nvim-agents.git"
        "https://github.com/iberi22/isar_agent_memory.git"
    )

    for repo in "${SWAL_PROJECTS[@]}"; do
        local reponame=$(basename "$repo" .git)
        if [[ ! -d "$projects_dir/$reponame/.git" ]]; then
            info "Clonando $reponame..."
            git clone --depth 1 "$repo" "$projects_dir/$reponame" 2>/dev/null || \
                warn "No se pudo clonar $reponame"
        fi
    done

    # Clonar SWAL skills
    local skills_dir="$workspace/skills"
    if [[ ! -d "$skills_dir/swal/.git" ]]; then
        git clone --depth 1 https://github.com/iberi22/swal-skills "$skills_dir/swal" 2>/dev/null || true
    fi

    success "Workspace listo: $workspace ✓"
}

# ── 9. Configuración ZeroClaw ──────────────────────────────────────────────
setup_config() {
    info "Configurando ZeroClaw como agente SWAL..."

    local config_dir="$HOME/.zeroclaw"
    mkdir -p "$config_dir"

    # Detectar API key de ambiente
    local api_key="${API_KEY:-}"
    local provider="${PROVIDER:-openrouter}"
    local model="${MODEL:-anthropic/claude-sonnet-4-20250514}"

    # ── Config principal ────────────────────────────────────────────────────
    cat > "$config_dir/config.toml" << EOF
# ZeroClaw SWAL Agent Configuration
# Agente autónomo con control total del sistema

workspace_dir = "${HOME}/zeroclaw-workspace"
config_path = "${config_dir}/config.toml"

# ── Provider ────────────────────────────────────────────────────────────────
api_key = "${api_key}"
default_provider = "${provider}"
default_model = "${model}"
default_temperature = 0.7

# ── Gateway ─────────────────────────────────────────────────────────────────
[gateway]
port = 42617
host = "0.0.0.0"
allow_public_bind = false
require_pairing = true

# ── Autonomy ─────────────────────────────────────────────────────────────────
# Nivel máximo de autonomía para administración del sistema
[autonomy]
level = "full"
auto_approve = [
    # File operations
    "file_read",
    "file_write",
    "file_edit",
    "file_delete",
    "file_mkdir",
    # Git operations
    "git_clone",
    "git_pull",
    "git_push",
    "git_commit",
    "git_branch",
    "git_merge",
    # Shell execution
    "shell_exec",
    "shell_install",
    "shell_uninstall",
    "shell_update",
    "shell_configure",
    # Package management
    "pkg_install",
    "pkg_uninstall",
    "pkg_update",
    # System
    "sys_reboot",
    "sys_shutdown",
    "service_start",
    "service_stop",
    # Web
    "web_search",
    "web_fetch",
    "web_scrape",
    # Memory
    "memory_recall",
    "memory_store",
    "memory_forget",
    # Development
    "cargo_build",
    "cargo_test",
    "cargo_run",
    "npm_install",
    "npm_run",
    "npm_build",
    "python_run",
    "python_install",
]

# ── Tools ──────────────────────────────────────────────────────────────────
# HABILITAR TODAS las tools para control total del sistema
[tools]
enabled_all = true
allow_shell = true
allow_git = true
allow_file_write = true
allow_file_delete = true
allow_pkg_install = true
allow_network = true
allow_subprocess = true

# ── Security ─────────────────────────────────────────────────────────────────
# ADVERTENCIA: Esta config permite al agente ejecutar CUALQUIER comando
# Solo usar en entornos controlados
[security]
allow_unsafe_commands = true
require_confirmation = false
log_all_commands = true
audit_file = "${HOME}/zeroclaw-workspace/logs/audit.log"

# ── SWAL Cortex ──────────────────────────────────────────────────────────────
[cortex]
enabled = true
url = "http://localhost:8003"
token = "dev-token"

# ── SWAL Gestalt ─────────────────────────────────────────────────────────────
[gestalt]
enabled = true
swarm_path = "${HOME}/.local/bin/gestalt_swarm"

# ── Skills ──────────────────────────────────────────────────────────────────
[skills]
open_skills_enabled = true
skills_dir = "${HOME}/zeroclaw-workspace/skills"
EOF

    # ── Secrets ────────────────────────────────────────────────────────────
    cat > "$config_dir/secrets.env" << EOF
# API Keys — EDITAR ESTE ARCHIVO
API_KEY=${API_KEY:-}
GROQ_API_KEY=${GROQ_API_KEY:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
EOF

    chmod 600 "$config_dir/secrets.env"
    success "ZeroClaw configurado ✓"
}

# ── 10. Sistema de reinicio automático ─────────────────────────────────────
setup_autostart() {
    info "Configurando reinicio automático..."

    # Crear script de start
    cat > "$HOME/.local/bin/swalservice" << 'EOF'
#!/bin/bash
# SWAL Agent — Service Manager
# Uso: swalservice start|stop|restart|status

case "${1:-start}" in
    start)
        echo "[SWAL] Iniciando ZeroClaw agent..."
        export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
        cd "$HOME/zeroclaw-swal"
        nohup zeroclaw daemon > "$HOME/zeroclaw-workspace/logs/zeroclaw.log" 2>&1 &
        echo $! > "$HOME/zeroclaw-workspace/logs/zeroclaw.pid"
        echo "[SWAL] ZeroClaw PID: $(cat $HOME/zeroclaw-workspace/logs/zeroclaw.pid)"
        ;;
    stop)
        if [[ -f "$HOME/zeroclaw-workspace/logs/zeroclaw.pid" ]]; then
            kill $(cat "$HOME/zeroclaw-workspace/logs/zeroclaw.pid") 2>/dev/null
            rm "$HOME/zeroclaw-workspace/logs/zeroclaw.pid"
            echo "[SWAL] ZeroClaw detenido"
        fi
        ;;
    restart)
        swalservice stop
        sleep 2
        swalservice start
        ;;
    status)
        if [[ -f "$HOME/zeroclaw-workspace/logs/zeroclaw.pid" ]]; then
            pid=$(cat "$HOME/zeroclaw-workspace/logs/zeroclaw.pid")
            if kill -0 $pid 2>/dev/null; then
                echo "[SWAL] ZeroClaw corriendo (PID: $pid)"
            else
                echo "[SWAL] PID existe pero proceso no está corriendo"
            fi
        else
            echo "[SWAL] ZeroClaw no está corriendo"
        fi
        ;;
esac
EOF

    chmod +x "$HOME/.local/bin/swalservice"

    # Termux boot script
    mkdir -p "$HOME/.termux/boot"
    cat > "$HOME/.termux/boot/swalservice" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Iniciar SWAL Agent al arrancar Termux
sleep 30
$HOME/.local/bin/swalservice start
EOF
    chmod +x "$HOME/.termux/boot/swalservice"

    success "Autostart configurado ✓"
}

# ── 11. Validación ──────────────────────────────────────────────────────────
validate() {
    info "Validando instalación..."

    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

    local errors=0

    # ZeroClaw
    if command -v zeroclaw &>/dev/null; then
        local ver=$(zeroclaw --version 2>/dev/null || echo "unknown")
        success "ZeroClaw: $ver ✓"
    else
        error "ZeroClaw no está en PATH"
        ((errors++))
    fi

    # Gestalt
    if command -v gestalt_swarm &>/dev/null; then
        success "Gestalt Swarm: ✓"
    else
        warn "Gestalt Swarm: no instalado (opcional)"
    fi

    # Workspaces
    if [[ -d "$HOME/zeroclaw-workspace" ]]; then
        success "Workspace: ✓"
    else
        error "Workspace no encontrado"
        ((errors++))
    fi

    # Proyectos
    if [[ -d "$HOME/zeroclaw-workspace/projects" ]]; then
        local count=$(ls -1 "$HOME/zeroclaw-workspace/projects" 2>/dev/null | wc -l)
        success "Proyectos: $count cloned ✓"
    fi

    # Services
    if [[ -x "$HOME/.local/bin/swalservice" ]]; then
        success "Service manager: ✓"
    fi

    if [[ $errors -eq 0 ]]; then
        success "Validación completada — TODO OK ✓"
    else
        warn "Validación completó con $errors errores"
    fi
}

# ── 12. Próximos pasos ──────────────────────────────────────────────────────
show_next_steps() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  ¡Instalación SWAL Agent completada!${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}Configurar API Keys:${NC}"
    echo -e "    nano ~/.zeroclaw/secrets.env"
    echo ""
    echo -e "  ${YELLOW}Iniciar el agente:${NC}"
    echo -e "    swalservice start"
    echo -e "    zeroclaw daemon"
    echo ""
    echo -e "  ${YELLOW}Comandos útiles:${NC}"
    echo -e "    zeroclaw status        # Estado"
    echo -e "    zeroclaw doctor         # Diagnóstico"
    echo -e "    zeroclaw agent         # Modo interactivo"
    echo -e "    zeroclaw gateway       # Solo gateway HTTP"
    echo ""
    echo -e "  ${YELLOW}Gestalt Swarm:${NC}"
    echo -e "    gestalt_swarm --agents 4 --goal 'task'"
    echo ""
    echo -e "  ${YELLOW}Workspace:${NC}"
    echo -e "    ~/zeroclaw-workspace/"
    echo -e "    ├── projects/     # Proyectos SWAL"
    echo -e "    ├── skills/       # Skills del agente"
    echo -e "    └── logs/         # Logs"
    echo ""
    echo -e "  ${YELLOW}Acceso remoto SSH:${NC}"
    echo -e "    ssh -p 8022 $USER@IP_LOCAL"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    show_banner

    echo -e "${YELLOW}Este script configurará:${NC}"
    echo "  • ZeroClaw (agente Rust con control total)"
    echo "  • Gestalt Swarm (enjambre de agentes)"
    echo "  • Entorno de desarrollo completo (Rust, Go, Python, Node)"
    echo "  • SSH para acceso remoto"
    echo "  • Zsh + Oh My Zsh"
    echo "  • Workspace con todos los proyectos SWAL"
    echo "  • Autostart al reiniciar Termux"
    echo ""
    echo -e "${RED}ADVERTENCIA: El agente tendrá permisos de root en Termux!${NC}"
    echo ""
    echo -e "${CYAN}Presiona Enter para continuar...${NC}"
    read -r

    check_termux
    check_dependencies
    setup_repo
    setup_dev_environment
    build_zeroclaw
    build_gestalt
    setup_ssh
    setup_zsh
    setup_workspace
    setup_config
    setup_autostart
    validate

    echo ""
    success "SWAL Agent instalado correctamente!"
}

main "$@"
