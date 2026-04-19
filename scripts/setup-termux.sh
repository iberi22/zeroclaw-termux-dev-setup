#!/bin/bash
# ============================================================
# ZeroClaw SWAL Node — Termux Setup v3.2
# Interactive installer con diagnóstico y skills modulares
# Admin privileges para instalación completa de paquetes
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[SWAL]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
SKILLS_DIR="$OPENCLAW_DIR/skills"
ZEROCLAW_DIR="$HOME/zeroclaw"
ENV_FILE="$OPENCLAW_DIR/secrets.env"

# ============================================================
# VERIFICACIÓN Y SOLICITUD DE PERMISOS
# ============================================================
check_permissions() {
    info "Verificando permisos de Termux..."
    
    # 1. Verificar si es root
    if [[ "$EUID" -eq 0 ]]; then
        ROOT_MODE=true
        info "Ejecutando como ROOT"
    else
        ROOT_MODE=false
        # Intentar verificar si hay acceso root via tsu o su
        if command -v tsu &>/dev/null; then
            info "tsu disponible (puedes usar root)"
        elif command -v sudo &>/dev/null; then
            info "sudo disponible"
        fi
    fi
    
    # 2. Verificar permisos de Termux (storage)
    if [[ -n "$TERMUX_VERSION" ]]; then
        info "Ejecutando en Termux"
        
        # Solicitar permisos de storage si no están otorgados
        if [[ ! -d "$HOME/storage" ]]; then
            warn "Permiso de storage no detectado"
            info "Solicitando permisos de storage..."
            termux-setup-storage -y 2>/dev/null || true
            sleep 2
        fi
        
        # Verificar que pkg puede instalar
        if ! pkg list-installed &>/dev/null; then
            warn "pkg no tiene acceso completo"
            info "Asegúrate de:"
            info "  1. Aceptar permisos de Termux cuando aparezcan"
            info "  2. No estar en modo 'Restrict' en Termux Settings"
        fi
    fi
    
    # 3. Verificar acceso a pkg
    info "Verificando acceso a pkg..."
    if pkg update -y &>/dev/null 2>&1; then
        PKG_ACCESS=true
        success "pkg tiene acceso completo"
    else
        PKG_ACCESS=false
        warn "pkg tiene acceso limitado"
        info "Tratando de reconfigurar..."
        termux-reload-settings 2>/dev/null || true
    fi
}

# ============================================================
# DIAGNÓSTICO DEL AMBIENTE
# ============================================================
diagnose() {
    echo ""
    log "$CYAN" "═══════════════════════════════════════════════════════"
    log "$CYAN" "  DIAGNÓSTICO DEL AMBIENTE"
    log "$CYAN" "═══════════════════════════════════════════════════════"
    echo ""

    local checks=0
    local passed=0

    # OS
    echo -n "  OS: "
    if [[ -n "$TERMUX_VERSION" ]]; then
        echo -e "${GREEN}✓ Termux${NC}"
        ((passed++))
    else
        echo -e "${YELLOW}⚠ Linux/No-Termux${NC}"
    fi
    ((checks++))

    # Shell
    echo -n "  Shell: "
    echo -e "${GREEN}✓${NC} $SHELL"
    ((checks++))
    ((passed++))

    # Permisos
    echo -n "  Permisos root: "
    if [[ "$ROOT_MODE" == true ]]; then
        echo -e "${GREEN}✓ root${NC}"
        ((passed++))
    elif command -v sudo &>/dev/null; then
        echo -e "${YELLOW}⚠ sudo disponible${NC}"
    elif command -v tsu &>/dev/null; then
        echo -e "${YELLOW}⚠ tsu disponible${NC}"
    else
        echo -e "${YELLOW}⚠ sin escalación${NC}"
    fi
    ((checks++))

    # pkg
    echo -n "  pkg: "
    if [[ "$PKG_ACCESS" == true ]]; then
        echo -e "${GREEN}✓ acceso completo${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ acceso limitado${NC}"
    fi
    ((checks++))

    # Node.js
    ((checks++))
    if command -v node &>/dev/null; then
        echo -n "  Node.js: "
        echo -e "${GREEN}✓$(node --version)${NC}"
        ((passed++))
    else
        echo -e "  Node.js: ${RED}✗ no instalado${NC}"
    fi

    # npm
    ((checks++))
    if command -v npm &>/dev/null; then
        echo -n "  npm: "
        echo -e "${GREEN}✓$(npm --version)${NC}"
        ((passed++))
    else
        echo -e "  npm: ${RED}✗ no instalado${NC}"
    fi

    # Python
    ((checks++))
    if command -v python3 &>/dev/null; then
        echo -n "  Python: "
        echo -e "${GREEN}✓$(python3 --version 2>&1)${NC}"
        ((passed++))
    else
        echo -e "  Python: ${RED}✗ no instalado${NC}"
    fi

    # Git
    ((checks++))
    if command -v git &>/dev/null; then
        echo -n "  Git: "
        echo -e "${GREEN}✓$(git --version 2>&1)${NC}"
        ((passed++))
    else
        echo -e "  Git: ${RED}✗ no instalado${NC}"
    fi

    # OpenClaw
    ((checks++))
    if command -v openclaw &>/dev/null; then
        echo -n "  OpenClaw: "
        local oc_ver=$(openclaw --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓$oc_ver${NC}"
        ((passed++))
    else
        echo -e "  OpenClaw: ${YELLOW}⚠ no instalado${NC}"
    fi

    # ZeroClaw
    ((checks++))
    if command -v zeroclaw &>/dev/null; then
        echo -n "  ZeroClaw: "
        local zc_ver=$(zeroclaw --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓$zc_ver${NC}"
        ((passed++))
    else
        echo -e "  ZeroClaw: ${YELLOW}⚠ no instalado${NC}"
    fi

    # uvx
    ((checks++))
    if command -v uvx &>/dev/null; then
        echo -n "  uvx: "
        echo -e "${GREEN}✓$(uvx --version 2>&1 | head -1)${NC}"
        ((passed++))
    else
        echo -e "  uvx: ${YELLOW}⚠ no instalado${NC}"
    fi

    # Workspace
    ((checks++))
    if [[ -d "$WORKSPACE_DIR" ]]; then
        echo -n "  Workspace: "
        local files=$(find "$WORKSPACE_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ ($files archivos .md)${NC}"
        ((passed++))
    else
        echo -e "  Workspace: ${RED}✗ no existe${NC}"
    fi

    # Skills
    ((checks++))
    if [[ -d "$SKILLS_DIR" ]]; then
        echo -n "  Skills: "
        local skill_count=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ ($skill_count skills)${NC}"
        ((passed++))
    else
        echo -e "  Skills: ${YELLOW}⚠ no existe${NC}"
    fi

    # API Keys
    echo ""
    echo "  ─── API Keys ───"
    
    echo -n "  GROQ_API_KEY: "
    if [[ -n "${GROQ_API_KEY:-}" ]]; then
        echo -e "${GREEN}✓ configurada${NC}"
    else
        echo -e "${YELLOW}⚠ no configurada${NC}"
    fi
    
    echo -n "  MINIMAX_API_KEY: "
    if grep -q "MINIMAX_API_KEY" "$ENV_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ configurada${NC}"
    else
        echo -e "${YELLOW}⚠ no configurada${NC}"
    fi

    echo ""
    log "$CYAN" "  Resultado: $passed/$checks checks passaram"
    echo ""
}

# ============================================================
# INSTALAR HERRAMIENTAS BASE CON PERMISOS
# ============================================================
install_base_tools() {
    info "Instalando herramientas base con permisos..."
    
    # Asegurar pkg actualizado
    info "Actualizando repositorios..."
    pkg update -y 2>/dev/null || {
        warn "pkg update falló, intentando con termux-reload..."
        termux-reload-settings 2>/dev/null || true
        pkg update -y 2>/dev/null || warn "No se pudo actualizar pkg"
    }
    
    # Paquetes esenciales para SWAL
    local base_tools=(
        git curl wget openssl openssh
        vim nano htop termux-api
        clang make cmake ninja-build
        python pip python-dev
        nodejs npm
    )
    
    info "Instalando herramientas base..."
    for tool in "${base_tools[@]}"; do
        echo -n "  $tool... "
        if command -v "$tool" &>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            if pkg install -y "$tool" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}⚠ falló${NC}"
            fi
        fi
    done
    
    # Instalar uvx para MCP
    info "Instalando uvx..."
    if command -v uvx &>/dev/null; then
        success "uvx ya está instalado"
    else
        echo -n "  uvx... "
        # Instalar via cargo o pip
        if command -v cargo &>/dev/null; then
            cargo install uvx 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ via cargo falló${NC}"
        elif command -v pip3 &>/dev/null; then
            pip3 install uvx 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ via pip falló${NC}"
        else
            # Instalar via script oficial
            curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null && \
                echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ falló${NC}"
        fi
    fi
}

# ============================================================
# INSTALAR PAQUETES DE SISTEMA CON PERMISOS
# ============================================================
install_packages() {
    local selection="$1"
    
    if [[ "$selection" == "S" ]]; then
        info "Saltando instalación de paquetes de sistema..."
        return
    fi
    
    # Verificar permisos primero
    if [[ "$PKG_ACCESS" != true ]]; then
        warn "pkg tiene acceso limitado"
        info "Solicitando permisos..."
        termux-reload-settings 2>/dev/null
        sleep 2
    fi
    
    info "Actualizando packages de Termux..."
    pkg update -y 2>/dev/null || true

    # Paquetes base siempre necesarios
    local base_pkgs="git curl wget openssl openssh termux-api vim nano htop clang make cmake ninja"

    if [[ "$selection" == "A" ]]; then
        # Todos los paquetes
        pkg install -y $base_pkgs python pip nodejs npm ruby openjdk-17 dart 2>/dev/null || true
    else
        # Selección individual
        local choices=$(echo "$selection" | tr ',' '\n')
        
        echo "$choices" | while read -r choice; do
            case "$choice" in
                1) pkg install -y python pip 2>/dev/null || true ;;
                2) pkg install -y nodejs npm 2>/dev/null || true ;;
                3) pkg install -y golang 2>/dev/null || true ;;
                4) pkg install -y rust 2>/dev/null || true ;;
                5) pkg install -y php composer 2>/dev/null || true ;;
                6) pkg install -y ruby 2>/dev/null || true ;;
                7) pkg install -y openjdk-17 2>/dev/null || true ;;
                8) pkg install -y dart 2>/dev/null || true ;;
            esac
        done
    fi
}

# ============================================================
# INSTALAR CLI AGENTS
# ============================================================
install_cli_agents() {
    local selection="$1"
    
    info "Instalando CLI agents..."
    
    # Codex CLI
    if echo ",$selection," | grep -q ",C,"; then
        info "Instalando Codex CLI..."
        if ! command -v codex &>/dev/null; then
            if command -v npm &>/dev/null; then
                npm install -g @openai/codex 2>/dev/null && success "Codex CLI instalado" || warn "Codex CLI falló"
            else
                warn "npm no disponible para Codex CLI"
            fi
        else
            success "Codex CLI ya instalado"
        fi
    fi
    
    # Claude Code CLI
    if echo ",$selection," | grep -q ",L,"; then
        info "Instalando Claude Code CLI..."
        if ! command -v claude &>/dev/null; then
            if command -v npm &>/dev/null; then
                npm install -g @anthropic/claude-code 2>/dev/null && success "Claude Code CLI instalado" || warn "Claude Code CLI falló"
            else
                warn "npm no disponible para Claude Code CLI"
            fi
        else
            success "Claude Code CLI ya instalado"
        fi
    fi
    
    # OpenCode CLI
    if echo ",$selection," | grep -q ",O,"; then
        info "Instalando OpenCode CLI..."
        if ! command -v opencode &>/dev/null; then
            if command -v npm &>/dev/null; then
                npm install -g opencode 2>/dev/null && success "OpenCode CLI instalado" || \
                npm install -g @minimax/opencode 2>/dev/null && success "OpenCode CLI (@minimax) instalado" || warn "OpenCode CLI falló"
            else
                warn "npm no disponible para OpenCode CLI"
            fi
        else
            success "OpenCode CLI ya instalado"
        fi
    fi
    
    # Jules CLI
    if echo ",$selection," | grep -q ",J,"; then
        info "Instalando Jules CLI..."
        if ! command -v jules &>/dev/null; then
            if command -v npm &>/dev/null; then
                npm install -g @anthropic/jules 2>/dev/null && success "Jules CLI instalado" || warn "Jules CLI falló"
            else
                warn "npm no disponible para Jules CLI"
            fi
        else
            success "Jules CLI ya instalado"
        fi
    fi
}

# ============================================================
# MENU DE PAQUETES
# ============================================================
show_menu() {
    echo ""
    log "$CYAN" "═══════════════════════════════════════════════════════"
    log "$CYAN" "  INSTALAR PAQUETES — Selecciona los que necesitas"
    log "$CYAN" "═══════════════════════════════════════════════════════"
    echo ""
    echo "  [1] Python + pip + herramientas (fastapi, langchain, jupyter)"
    echo "  [2] Node.js + npm + pnpm + yarn + ts-node"
    echo "  [3] Go (golang)"
    echo "  [4] Rust + Cargo (rustup)"
    echo "  [5] PHP + Composer"
    echo "  [6] Ruby + Bundler"
    echo "  [7] Java (OpenJDK 17) + Maven"
    echo "  [8] Flutter SDK (~2GB, opcional)"
    echo "  [9] Build tools (cmake, ninja, clang, make)"
    echo ""
    echo "  [C] Codex CLI — coding agent, OpenAI"
    echo "  [L] Claude Code CLI — coding agent, Anthropic"
    echo "  [O] OpenCode CLI — coding agent, MiniMax-M2.7"
    echo "  [J] Jules CLI — coding agent, Google (GitHub issues)"
    echo ""
    echo "  [A] Instalar TODOS los anteriores"
    echo ""
    echo "  [S] Solo instalar skills (sin paquetes de sistema)"
    echo ""
    echo -n "  Tu selección (ej: 1,2,C,L,O): "
}

# ============================================================
# CONFIGURAR API KEYS
# ============================================================
configure_api_keys() {
    echo ""
    log "$CYAN" "═══════════════════════════════════════════════════════"
    log "$CYAN" "  CONFIGURAR API KEYS"
    log "$CYAN" "═══════════════════════════════════════════════════════"
    echo ""
    
    # Crear directorio si no existe
    mkdir -p "$OPENCLAW_DIR"
    
    # GROQ_API_KEY
    echo -n "  GROQ_API_KEY"
    if [[ -n "${GROQ_API_KEY:-}" ]]; then
        echo -e " ${GREEN}✓ ya configurada${NC}"
    elif grep -q "GROQ_API_KEY" "$ENV_FILE" 2>/dev/null; then
        echo -e " ${GREEN}✓ ya configurada${NC}"
    else
        echo ""
        echo -n "    Ingresa tu GROQ API Key (ENTER para omitir): "
        read -r gk
        if [[ -n "$gk" ]]; then
            echo "GROQ_API_KEY=$gk" >> "$ENV_FILE"
            success "GROQ_API_KEY guardada"
        fi
    fi
    
    # MINIMAX_API_KEY
    echo -n "  MINIMAX_API_KEY"
    if grep -q "MINIMAX_API_KEY" "$ENV_FILE" 2>/dev/null; then
        echo -e " ${GREEN}✓ ya configurada${NC}"
    else
        echo ""
        echo -n "    Ingresa tu MINIMAX API Key (ENTER para omitir): "
        read -r mk
        if [[ -n "$mk" ]]; then
            echo "MINIMAX_API_KEY=$mk" >> "$ENV_FILE"
            success "MINIMAX_API_KEY guardada"
        fi
    fi
    
    echo ""
}

# ============================================================
# INSTALAR SKILLS
# ============================================================
install_skills() {
    info "Instalando SWAL Skills..."
    
    mkdir -p "$SKILLS_DIR"
    
    # Skills principales
    local skills=(
        "cortex-memory"
        "sales-agent"
        "minimax-tools"
    )
    
    for skill in "${skills[@]}"; do
        echo -n "  $skill... "
        # Crear directorio del skill con SKILL.md básico
        mkdir -p "$SKILLS_DIR/$skill"
        if [[ ! -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
            cat > "$SKILLS_DIR/$skill/SKILL.md" << EOF
---
name: $skill
description: "SWAL Node skill - $skill"
---

# $skill

Skill instalado por setup-termux.sh v3.2
EOF
        fi
        echo -e "${GREEN}✓${NC}"
    done
    
    # Instalar skill desde GitHub si hay conexión
    if curl -fsSL --max-time 10 "https://github.com" &>/dev/null; then
        info "Descargando skills desde GitHub..."
        # Intentar descargar skill de ventas
        if [[ ! -f "$SKILLS_DIR/sales-agent/SKILL.md" ]] || \
           ! grep -q "sales-agent" "$SKILLS_DIR/sales-agent/SKILL.md" 2>/dev/null; then
            curl -fsSL "https://raw.githubusercontent.com/iberi22/swal-skills/main/skills/sales-agent/SKILL.md" \
                -o "$SKILLS_DIR/sales-agent/SKILL.md" 2>/dev/null && \
                success "sales-agent skill instalado" || warn "sales-agent skill no disponible"
        fi
    fi
    
    success "Skills instalados en $SKILLS_DIR"
}

# ============================================================
# CONFIGURAR WORKSPACE
# ============================================================
setup_workspace() {
    info "Configurando workspace..."
    
    mkdir -p "$WORKSPACE_DIR"
    
    # Crear archivos base
    if [[ ! -f "$WORKSPACE_DIR/README.md" ]]; then
        cat > "$WORKSPACE_DIR/README.md" << 'EOF'
# ZeroClaw SWAL Node Workspace

ZeroClaw Termux Setup - $(date)
EOF
    fi
    
    if [[ ! -f "$WORKSPACE_DIR/MEMORY.md" ]]; then
        cat > "$WORKSPACE_DIR/MEMORY.md" << 'EOF'
# SWAL Node Memory

ZeroClaw Termux - Iniciado $(date)
EOF
    fi
    
    success "Workspace configurado en $WORKSPACE_DIR"
}

# ============================================================
# MOSTRAR PRÓXIMOS PASOS
# ============================================================
show_next_steps() {
    echo ""
    log "$GREEN" "═══════════════════════════════════════════════════════"
    log "$GREEN" "  ¡SETUP COMPLETADO!"
    log "$GREEN" "═══════════════════════════════════════════════════════"
    echo ""
    info "Próximos pasos:"
    echo ""
    echo "  1. Edita $ENV_FILE con tus API keys si no lo hiciste"
    echo "  2. Ejecuta: termux-reload-settings"
    echo "  3. Reinicia sesión: exit (y vuelve a entrar)"
    echo "  4. Inicia: zeroclaw daemon"
    echo ""
    info "Comandos útiles:"
    echo "  Diagnóstico: $0 --diagnose"
    echo "  Ver API keys: cat $ENV_FILE"
    echo "  Ver config: cat ~/.zeroclaw/config.toml"
    echo ""
}

# ============================================================
# MAIN
# ============================================================
main() {
    # Verificar si es solo diagnóstico
    if [[ "${1:-}" == "--diagnose" ]]; then
        check_permissions
        diagnose
        exit 0
    fi
    
    echo ""
    log "$GREEN" "═══════════════════════════════════════════════════════"
    log "$GREEN" "  ZeroClaw SWAL Node — Termux Setup v3.2"
    log "$GREEN" "═══════════════════════════════════════════════════════"
    echo ""
    
    # 1. Verificar permisos
    check_permissions
    
    # 2. Diagnóstico
    diagnose
    
    # 3. Menú de instalación
    show_menu
    read -r selection
    
    # 4. Instalación
    echo ""
    info "Instalando selección: $selection"
    echo ""
    
    # Instalar herramientas base
    install_base_tools
    
    # Instalar paquetes seleccionados
    install_packages "$selection"
    
    # Instalar CLI agents
    install_cli_agents "$selection"
    
    # 5. Configurar API keys
    configure_api_keys
    
    # 6. Instalar skills
    install_skills
    
    # 7. Configurar workspace
    setup_workspace
    
    # 8. Mostrar resultados
    diagnose
    
    # 9. Próximos pasos
    show_next_steps
}

# Ejecutar
main "$@"