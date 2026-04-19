#!/bin/bash
# ============================================================
# ZeroClaw SWAL Node — Termux Setup v3.4
# Interactive installer con diagnóstico y reparación de config
# Admin privileges para instalación completa de paquetes
# Incluye logo SWAL con oh-my-logo (colores OrionHealth)
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
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

# Colores OrionHealth: Teal → Cyan
ORION_COLORS="'#004D40', '#009688', '#00BCD4', '#80CBC4'"

# ============================================================
# REPARAR CONFIGURACIÓN ROMPIDA
# ============================================================
fix_broken_config() {
    info "Buscando configuraciones rotas..."
    
    local fixed=0
    
    # 1. Verificar y reparar .bashrc
    if [[ -f "$BASHRC" ]]; then
        if grep -q "zeroclaw start" "$BASHRC" 2>/dev/null; then
            warn "Encontrado 'zeroclaw start' en $BASHRC - esto rompe Termux!"
            info "Removiendo línea rota..."
            sed -i '/zeroclaw start/d' "$BASHRC"
            ((fixed++))
            success "Reparado: 'zeroclaw start' removido de .bashrc"
        fi
        
        if grep -q "zeroclaw daemon" "$BASHRC" 2>/dev/null; then
            info "Nota: 'zeroclaw daemon' encontrado en $BASHRC (auto-start)"
        fi
    fi
    
    # 2. Verificar y reparar .zshrc
    if [[ -f "$ZSHRC" ]]; then
        if grep -q "zeroclaw start" "$ZSHRC" 2>/dev/null; then
            warn "Encontrado 'zeroclaw start' en $ZSHRC - esto rompe Termux!"
            info "Removiendo línea rota..."
            sed -i '/zeroclaw start/d' "$ZSHRC"
            ((fixed++))
            success "Reparado: 'zeroclaw start' removido de .zshrc"
        fi
    fi
    
    # 3. Verificar Termux rc files
    local termux_rc="/data/data/com.termux/files/usr/etc/motd"
    if [[ -f "$termux_rc" ]] && grep -q "zeroclaw" "$termux_rc" 2>/dev/null; then
        warn "zeroclaw encontrado en motd - removiendo..."
        sed -i '/zeroclaw/d' "$termux_rc" 2>/dev/null || true
        ((fixed++))
        success "Reparado: zeroclaw removido del motd"
    fi
    
    # 4. Verificar zeroclaw config
    if [[ -f "$HOME/.zeroclaw/config.toml" ]]; then
        info "Verificando config.toml..."
        if grep -q "zeroclaw start" "$HOME/.zeroclaw/config.toml" 2>/dev/null; then
            warn "Encontrado 'zeroclaw start' en config.toml"
            sed -i '/zeroclaw start/d' "$HOME/.zeroclaw/config.toml"
            ((fixed++))
            success "Reparado: config.toml limpio"
        fi
    fi
    
    # 5. Mostrar rc files problemáticos
    info "Verificando rc files para comandos rotos..."
    for rc in "$BASHRC" "$ZSHRC" "$HOME/.profile" "$HOME/.bash_profile"; do
        if [[ -f "$rc" ]]; then
            while IFS= read -r line; do
                if [[ "$line" =~ ^(alias\ |export\ |function\ ) ]]; then
                    continue
                fi
                local cmd=$(echo "$line" | awk '{print $1}' | tr -d '|;$')
                if [[ -n "$cmd" ]] && ! command -v "$cmd" &>/dev/null && [[ "$cmd" != "zeroclaw" ]]; then
                    if ! grep -q "#.*$cmd" "$rc"; then
                        warn "Comando no encontrado en $rc: $cmd"
                    fi
                fi
            done < "$rc"
        fi
    done
    
    if [[ $fixed -gt 0 ]]; then
        success "Reparadas $fixed configuraciones"
        info "Reinicia Termux para aplicar cambios"
    else
        info "No se encontraron configuraciones rotas"
    fi
}

# ============================================================
# LIMPIAR MOTD Y MENSAJES DE INICIO
# ============================================================
clean_motd() {
    info "Limpiando mensajes de inicio..."
    
    local cleaned=0
    
    touch "$HOME/.hushlogin" 2>/dev/null && ((cleaned++)) || true
    
    local motd_file="/data/data/com.termux/files/usr/etc/motd"
    if [[ -w "$motd_file" ]] 2>/dev/null; then
        sed -i '/termux\.dev\/donate/d' "$motd_file" 2>/dev/null || true
        sed -i '/termux\.dev\/community/d' "$motd_file" 2>/dev/null || true
        ((cleaned++))
    fi
    
    if [[ -d "/data/data/com.termux/files/usr/etc/motd.d" ]]; then
        rm -f /data/data/com.termux/files/usr/etc/motd.d/*.sh 2>/dev/null || true
        ((cleaned++))
    fi
    
    success "Mensajes de inicio limpiados"
}

# ============================================================
# VERIFICAR SERVICIOS INSTALADOS
# ============================================================
check_services() {
    info "Verificando servicios..."
    
    echo ""
    log "$CYAN" "  ─── Servicios Termux ───"
    
    # SSH
    echo -n "  SSH server: "
    if pgrep -f sshd &>/dev/null; then
        echo -e "${GREEN}✓ corriendo (PID: $(pgrep -f sshd))${NC}"
    elif command -v sshd &>/dev/null; then
        echo -e "${YELLOW}⚠ instalado pero no corriendo${NC}"
    else
        echo -e "${YELLOW}⚠ no instalado${NC}"
    fi
    
    # Zeroclaw
    echo -n "  ZeroClaw daemon: "
    if pgrep -f "zeroclaw daemon" &>/dev/null; then
        echo -e "${GREEN}✓ corriendo (PID: $(pgrep -f "zeroclaw daemon"))${NC}"
    elif command -v zeroclaw &>/dev/null; then
        echo -e "${YELLOW}⚠ instalado pero no corriendo${NC}"
    else
        echo -e "${YELLOW}⚠ no instalado${NC}"
    fi
    
    # OpenClaw
    echo -n "  OpenClaw: "
    if pgrep -f "openclaw" &>/dev/null; then
        echo -e "${GREEN}✓ corriendo${NC}"
    elif command -v openclaw &>/dev/null; then
        echo -e "${YELLOW}⚠ instalado pero no corriendo${NC}"
    else
        echo -e "${YELLOW}⚠ no instalado${NC}"
    fi
    
    echo ""
}

# ============================================================
# VERIFICACIÓN Y SOLICITUD DE PERMISOS
# ============================================================
check_permissions() {
    info "Verificando permisos de Termux..."
    
    if [[ "$EUID" -eq 0 ]]; then
        ROOT_MODE=true
        info "Ejecutando como ROOT"
    else
        ROOT_MODE=false
    fi
    
    if [[ -n "$TERMUX_VERSION" ]]; then
        info "Ejecutando en Termux"
        
        if [[ ! -d "$HOME/storage" ]]; then
            warn "Permiso de storage no detectado"
            info "Solicitando permisos de storage..."
            termux-setup-storage -y 2>/dev/null || true
            sleep 2
        fi
    fi
    
    info "Verificando acceso a pkg..."
    if pkg update -y &>/dev/null 2>&1; then
        PKG_ACCESS=true
        success "pkg tiene acceso completo"
    else
        PKG_ACCESS=false
        warn "pkg tiene acceso limitado"
        info "Tratando de reconfigurar..."
        termux-reload-settings 2>/dev/null || true
        sleep 2
        if pkg update -y &>/dev/null 2>&1; then
            PKG_ACCESS=true
            success "pkg恢复 acceso completo"
        fi
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

    echo -n "  OS: "
    if [[ -n "$TERMUX_VERSION" ]]; then
        echo -e "${GREEN}✓ Termux${NC}"
        ((passed++))
    else
        echo -e "${YELLOW}⚠ Linux/No-Termux${NC}"
    fi
    ((checks++))

    echo -n "  Shell: "
    echo -e "${GREEN}✓${NC} $SHELL"
    ((checks++))
    ((passed++))

    echo -n "  pkg: "
    if [[ "$PKG_ACCESS" == true ]]; then
        echo -e "${GREEN}✓ acceso completo${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ acceso limitado${NC}"
    fi
    ((checks++))

    ((checks++))
    if command -v node &>/dev/null; then
        echo -n "  Node.js: "
        echo -e "${GREEN}✓$(node --version)${NC}"
        ((passed++))
    else
        echo -e "  Node.js: ${RED}✗ no instalado${NC}"
    fi

    ((checks++))
    if command -v npm &>/dev/null; then
        echo -n "  npm: "
        echo -e "${GREEN}✓$(npm --version)${NC}"
        ((passed++))
    else
        echo -e "  npm: ${RED}✗ no instalado${NC}"
    fi

    ((checks++))
    if command -v python3 &>/dev/null; then
        echo -n "  Python: "
        echo -e "${GREEN}✓$(python3 --version 2>&1)${NC}"
        ((passed++))
    else
        echo -e "  Python: ${RED}✗ no instalado${NC}"
    fi

    ((checks++))
    if command -v git &>/dev/null; then
        echo -n "  Git: "
        echo -e "${GREEN}✓$(git --version 2>&1)${NC}"
        ((passed++))
    else
        echo -e "  Git: ${RED}✗ no instalado${NC}"
    fi

    ((checks++))
    if command -v openclaw &>/dev/null; then
        echo -n "  OpenClaw: "
        local oc_ver=$(openclaw --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓$oc_ver${NC}"
        ((passed++))
    else
        echo -e "  OpenClaw: ${YELLOW}⚠ no instalado${NC}"
    fi

    ((checks++))
    if command -v zeroclaw &>/dev/null; then
        echo -n "  ZeroClaw: "
        local zc_ver=$(zeroclaw --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓$zc_ver${NC}"
        ((passed++))
    else
        echo -e "  ZeroClaw: ${YELLOW}⚠ no instalado${NC}"
    fi

    ((checks++))
    if command -v uvx &>/dev/null; then
        echo -n "  uvx: "
        echo -e "${GREEN}✓$(uvx --version 2>&1 | head -1)${NC}"
        ((passed++))
    else
        echo -e "  uvx: ${YELLOW}⚠ no instalado${NC}"
    fi

    ((checks++))
    if [[ -d "$WORKSPACE_DIR" ]]; then
        echo -n "  Workspace: "
        local files=$(find "$WORKSPACE_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ ($files archivos .md)${NC}"
        ((passed++))
    else
        echo -e "  Workspace: ${RED}✗ no existe${NC}"
    fi

    echo ""
    log "$CYAN" "  ─── Configuraciones ───"
    
    local broken=0
    for rc in "$BASHRC" "$ZSHRC"; do
        if [[ -f "$rc" ]]; then
            if grep -q "zeroclaw start" "$rc" 2>/dev/null; then
                echo -e "  ${RED}✗${NC} $rc tiene 'zeroclaw start' (ROTO)"
                ((broken++))
            fi
        fi
    done
    
    if [[ $broken -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} RC files sin errores"
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
    
    info "Actualizando repositorios..."
    pkg update -y 2>/dev/null || {
        warn "pkg update falló, intentando con termux-reload..."
        termux-reload-settings 2>/dev/null || true
        pkg update -y 2>/dev/null || warn "No se pudo actualizar pkg"
    }
    
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
    
    info "Instalando uvx..."
    if command -v uvx &>/dev/null; then
        success "uvx ya está instalado"
    else
        echo -n "  uvx... "
        if command -v cargo &>/dev/null; then
            (cargo install uvx 2>/dev/null && echo -e "${GREEN}✓${NC}") || \
            (curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null && echo -e "${GREEN}✓${NC}") || \
            echo -e "${YELLOW}⚠ falló${NC}"
        elif command -v pip3 &>/dev/null; then
            (pip3 install uvx 2>/dev/null && echo -e "${GREEN}✓${NC}") || \
            (curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null && echo -e "${GREEN}✓${NC}") || \
            echo -e "${YELLOW}⚠ falló${NC}"
        else
            curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}⚠ falló${NC}"
        fi
    fi
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
    
    mkdir -p "$OPENCLAW_DIR"
    
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
    
    local skills=(
        "cortex-memory"
        "sales-agent"
        "minimax-tools"
    )
    
    for skill in "${skills[@]}"; do
        echo -n "  $skill... "
        mkdir -p "$SKILLS_DIR/$skill"
        if [[ ! -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
            cat > "$SKILLS_DIR/$skill/SKILL.md" << EOF
---
name: $skill
description: "SWAL Node skill - $skill"
---

# $skill

Skill instalado por setup-termux.sh v3.4
EOF
        fi
        echo -e "${GREEN}✓${NC}"
    done
    
    success "Skills instalados en $SKILLS_DIR"
}

# ============================================================
# CONFIGURAR WORKSPACE
# ============================================================
setup_workspace() {
    info "Configurando workspace..."
    
    mkdir -p "$WORKSPACE_DIR"
    
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
# MOSTRAR LOGO SWAL (oh-my-logo con colores OrionHealth)
# ============================================================
show_swal_logo() {
    echo ""
    log "$CYAN" "═══════════════════════════════════════════════════════"
    log "$CYAN" "  LOGO SWAL — Colores OrionHealth"
    log "$CYAN" "═══════════════════════════════════════════════════════"
    echo ""
    
    # Verificar si node/npm está disponible
    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        warn "Node.js no está instalado. Saltando logo..."
        return
    fi
    
    # Verificar npx
    if ! command -v npx &>/dev/null; then
        warn "npx no disponible. Saltando logo..."
        return
    fi
    
    info "Generando logo SWAL con oh-my-logo..."
    echo ""
    
    # Ejecutar oh-my-logo con colores OrionHealth (Teal → Cyan)
    # Colores: #004D40 (dark teal) → #009688 (teal) → #00BCD4 (cyan) → #80CBC4 (light teal)
    if npx --yes oh-my-logo "SWAL" --palette-colors "$ORION_COLORS" --filled --letter-spacing 2 2>/dev/null; then
        success "Logo SWAL mostrado!"
    else
        # Fallback: ASCII art manual con colores ANSI
        echo -e "\033[1;36m╔═══════════════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[1;36m║\033[0m\033[1;32m ██████╗ ██████╗ ███████╗███╗   ██╗ █████╗ ██╗       \033[1;36m║\033[0m"
        echo -e "\033[1;36m║\033[0m\033[1;32m ██╔══██╗██╔══██╗██╔════╝████╗  ██║██╔══██╗██║       \033[1;36m║\033[0m"
        echo -e "\033[1;36m║\033[0m\033[1;32m ██████╔╝██████╔╝█████╗  ██╔██╗ ██║███████║██║       \033[1;36m║\033[0m"
        echo -e "\033[1;36m║\033[0m\033[1;32m ██╔══██╗██╔══██╗██╔══╝  ██║╚██╗██║██╔══██║██║       \033[1;36m║\033[0m"
        echo -e "\033[1;36m║\033[0m\033[1;32m ██████╔╝██║  ██║███████╗██║ ╚████║██║  ██║███████╗\033[1;36m║\033[0m"
        echo -e "\033[1;36m║\033[0m\033[1;32m ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝\033[1;36m║\033[0m"
        echo -e "\033[1;36m╚═══════════════════════════════════════════════════════════╝\033[0m"
        echo -e "\033[1;32m              🦉  S W A L   N O D E  🦉\033[0m"
        echo -e "\033[1;36m            Colores: OrionHealth (Teal/Cyan)\033[0m"
    fi
    
    echo ""
}

# ============================================================
# MENU DE PAQUETES
# ============================================================
show_menu() {
    echo ""
    log "$CYAN" "═══════════════════════════════════════════════════════"
    log "$CYAN" "  INSTALAR PAQUETES"
    log "$CYAN" "═══════════════════════════════════════════════════════"
    echo ""
    echo "  [1] Python + pip"
    echo "  [2] Node.js + npm"
    echo "  [3] Go (golang)"
    echo "  [4] Rust + Cargo"
    echo "  [5] Java (OpenJDK)"
    echo "  [6] Ruby"
    echo "  [7] PHP"
    echo "  [8] Flutter SDK"
    echo "  [9] Build tools (cmake, ninja, clang)"
    echo ""
    echo "  [C] Codex CLI (OpenAI)"
    echo "  [L] Claude Code CLI (Anthropic)"
    echo "  [O] OpenCode CLI (MiniMax)"
    echo "  [J] Jules CLI (Google)"
    echo ""
    echo "  [A] TODOS"
    echo "  [S] Solo skills (sin paquetes)"
    echo ""
    echo -n "  Selección (ej: 1,2,C,L): "
}

# ============================================================
# INSTALAR PAQUETES
# ============================================================
install_packages() {
    local selection="$1"
    
    if [[ "$selection" == "S" ]]; then
        info "Saltando paquetes..."
        return
    fi
    
    info "Actualizando repositorios..."
    pkg update -y 2>/dev/null || true

    local choices=$(echo "$selection" | tr ',' '\n')
    
    echo "$choices" | while read -r choice; do
        case "$choice" in
            1) pkg install -y python pip 2>/dev/null && echo -e "  Python: ${GREEN}✓${NC}" ;;
            2) pkg install -y nodejs npm 2>/dev/null && echo -e "  Node.js: ${GREEN}✓${NC}" ;;
            3) pkg install -y golang 2>/dev/null && echo -e "  Go: ${GREEN}✓${NC}" ;;
            4) pkg install -y rust 2>/dev/null && echo -e "  Rust: ${GREEN}✓${NC}" ;;
            5) pkg install -y openjdk-17 2>/dev/null && echo -e "  Java: ${GREEN}✓${NC}" ;;
            6) pkg install -y ruby 2>/dev/null && echo -e "  Ruby: ${GREEN}✓${NC}" ;;
            7) pkg install -y php 2>/dev/null && echo -e "  PHP: ${GREEN}✓${NC}" ;;
            8) pkg install -y dart 2>/dev/null && echo -e "  Flutter: ${GREEN}✓${NC}" ;;
            9) pkg install -y cmake ninja clang make 2>/dev/null && echo -e "  Build tools: ${GREEN}✓${NC}" ;;
            C|c) npm install -g @openai/codex 2>/dev/null && echo -e "  Codex: ${GREEN}✓${NC}" || warn "Codex falló" ;;
            L|l) npm install -g @anthropic/claude-code 2>/dev/null && echo -e "  Claude Code: ${GREEN}✓${NC}" || warn "Claude Code falló" ;;
            O|o) npm install -g opencode 2>/dev/null && echo -e "  OpenCode: ${GREEN}✓${NC}" || warn "OpenCode falló" ;;
            J|j) npm install -g @anthropic/jules 2>/dev/null && echo -e "  Jules: ${GREEN}✓${NC}" || warn "Jules falló" ;;
        esac
    done
}

# ============================================================
# CONFIGURAR ZEROCLAW AUTONOMY LEVEL
# ============================================================
configure_zeroclaw_autonomy() {
    info "Configurando ZeroClaw autonomy level..."
    
    local config_file="$HOME/.zeroclaw/config.toml"
    
    # Crear directorio si no existe
    mkdir -p "$HOME/.zeroclaw"
    
    # Verificar si ya existe autonomy_level
    if grep -q 'autonomy_level' "$config_file" 2>/dev/null; then
        # Modificar existente
        sed -i 's/autonomy_level = ".*"/autonomy_level = "supervised"/' "$config_file"
        success "autonomy_level actualizado a supervised"
    else
        # Agregar al final o crear sección [agent]
        if grep -q '^\[agent\]' "$config_file" 2>/dev/null; then
            sed -i '/^\[agent\]/a autonomy_level = "supervised"' "$config_file"
        else
            echo -e "\n[agent]" >> "$config_file"
            echo 'autonomy_level = "supervised"' >> "$config_file"
        fi
        success "autonomy_level configurado a supervised"
    fi
    
    grep 'autonomy_level' "$config_file" 2>/dev/null || true
}

# ============================================================
# MAIN
# ============================================================
main() {
    echo ""
    log "$GREEN" "═══════════════════════════════════════════════════════"
    log "$GREEN" "  ZeroClaw SWAL Node — Termux Setup v3.5"
    log "$GREEN" "═══════════════════════════════════════════════════════"
    echo ""
    
    # 0. Reparar configs rotas PRIMERO
    fix_broken_config
    clean_motd
    
    # 1. Verificar permisos
    check_permissions
    
    # 2. Verificar servicios
    check_services
    
    # 3. Diagnóstico
    diagnose
    
    # 4. Menú de instalación
    show_menu
    read -r selection
    
    # 5. Instalación
    echo ""
    info "Instalando: $selection"
    
    install_base_tools
    install_packages "$selection"
    configure_api_keys
    install_skills
    setup_workspace
    
    # 6. Configurar ZeroClaw autonomy level (supervised)
    configure_zeroclaw_autonomy
    
    # 7. Mostrar logo SWAL con oh-my-logo (colores OrionHealth)
    show_swal_logo
    
    # 8. Mostrar resultados
    diagnose
    
    echo ""
    log "$GREEN" "═══════════════════════════════════════════════════════"
    log "$GREEN" "  ¡SETUP COMPLETADO!"
    log "$GREEN" "═══════════════════════════════════════════════════════"
    echo ""
    info "Próximos pasos:"
    echo "  1. Reinicia Termux: exit y vuelve a entrar"
    echo "  2. Inicia zeroclaw: zeroclaw daemon"
    echo ""
}

main "$@"