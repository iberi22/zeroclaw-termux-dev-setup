#!/bin/bash
# ============================================================
# ZeroClaw SWAL Node - Termux Setup v3.7
# Interactive installer con diagnostico y reparacion de config
# Admin privileges para instalacion completa de paquetes
# Incluye logo SWAL con oh-my-logo (colores OrionHealth)
# Autonomy level: full (actua autonomously, no pide aprobacion)
# Security policy: comandos permitidos (pkg, git, npm, python, etc)
# Skills: globales + por proyecto (sales, manteniapp, worldexams, orionhealth)
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

ORION_COLORS="'#004D40', '#009688', '#00BCD4', '#80CBC4'"

# ============================================================
# REPARAR CONFIGURACION ROTA
# ============================================================
fix_broken_config() {
    info "Buscando configuraciones rotas..."
    
    local fixed=0
    
    if [[ -f "$BASHRC" ]]; then
        if grep -q "zeroclaw start" "$BASHRC" 2>/dev/null; then
            warn "Encontrado 'zeroclaw start' en $BASHRC - esto rompe Termux!"
            info "Removiendo linea rota..."
            sed -i '/zeroclaw start/d' "$BASHRC"
            ((fixed++))
            success "Reparado: 'zeroclaw start' removido de .bashrc"
        fi
    fi
    
    if [[ -f "$ZSHRC" ]]; then
        if grep -q "zeroclaw start" "$ZSHRC" 2>/dev/null; then
            warn "Encontrado 'zeroclaw start' en $ZSHRC!"
            sed -i '/zeroclaw start/d' "$ZSHRC"
            ((fixed++))
            success "Reparado: 'zeroclaw start' removido de .zshrc"
        fi
    fi
    
    if [[ $fixed -gt 0 ]]; then
        success "Reparadas $fixed configuraciones"
    else
        info "No se encontraron configuraciones rotas"
    fi
}

# ============================================================
# LIMPIAR MOTD
# ============================================================
clean_motd() {
    info "Limpiando mensajes de inicio..."
    touch "$HOME/.hushlogin" 2>/dev/null || true
    success "Mensajes de inicio limpiados"
}

# ============================================================
# VERIFICAR SERVICIOS
# ============================================================
check_services() {
    info "Verificando servicios..."
    
    echo ""
    echo "  --- Servicios Termux ---"
    
    echo -n "  SSH server: "
    if pgrep -f sshd &>/dev/null; then
        echo -e "${GREEN}OK corriendo (PID: $(pgrep -f sshd))${NC}"
    elif command -v sshd &>/dev/null; then
        echo -e "${YELLOW}WARN instalado pero no corriendo${NC}"
    else
        echo -e "${YELLOW}WARN no instalado${NC}"
    fi
    
    echo -n "  ZeroClaw daemon: "
    if pgrep -f "zeroclaw daemon" &>/dev/null; then
        echo -e "${GREEN}OK corriendo${NC}"
    elif command -v zeroclaw &>/dev/null; then
        echo -e "${YELLOW}WARN instalado pero no corriendo${NC}"
    else
        echo -e "${YELLOW}WARN no instalado${NC}"
    fi
    
    echo ""
}

# ============================================================
# VERIFICAR PERMISOS
# ============================================================
check_permissions() {
    info "Verificando permisos de Termux..."
    
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
        termux-reload-settings 2>/dev/null || true
    fi
}

# ============================================================
# DIAGNOSTICO DEL AMBIENTE
# ============================================================
diagnose() {
    echo ""
    echo "============================================================"
    echo "  DIAGNOSTICO DEL AMBIENTE"
    echo "============================================================"
    echo ""

    local checks=0
    local passed=0

    echo -n "  OS: "
    if [[ -n "$TERMUX_VERSION" ]]; then
        echo -e "${GREEN}OK Termux${NC}"
        ((passed++))
    else
        echo -e "${YELLOW}WARN Linux/No-Termux${NC}"
    fi
    ((checks++))

    echo -n "  Shell: "
    echo -e "${GREEN}OK${NC} $SHELL"
    ((checks++))
    ((passed++))

    echo -n "  pkg: "
    if [[ "$PKG_ACCESS" == true ]]; then
        echo -e "${GREEN}OK acceso completo${NC}"
        ((passed++))
    else
        echo -e "${RED}FAIL acceso limitado${NC}"
    fi
    ((checks++))

    ((checks++))
    if command -v node &>/dev/null; then
        echo -n "  Node.js: "
        echo -e "${GREEN}OK$(node --version)${NC}"
        ((passed++))
    else
        echo -e "  Node.js: ${RED}FAIL no instalado${NC}"
    fi

    ((checks++))
    if command -v npm &>/dev/null; then
        echo -n "  npm: "
        echo -e "${GREEN}OK$(npm --version)${NC}"
        ((passed++))
    else
        echo -e "  npm: ${RED}FAIL no instalado${NC}"
    fi

    ((checks++))
    if command -v python3 &>/dev/null; then
        echo -n "  Python: "
        echo -e "${GREEN}OK$(python3 --version 2>&1)${NC}"
        ((passed++))
    else
        echo -e "  Python: ${RED}FAIL no instalado${NC}"
    fi

    ((checks++))
    if command -v git &>/dev/null; then
        echo -n "  Git: "
        echo -e "${GREEN}OK$(git --version 2>&1)${NC}"
        ((passed++))
    else
        echo -e "  Git: ${RED}FAIL no instalado${NC}"
    fi

    ((checks++))
    if command -v zeroclaw &>/dev/null; then
        echo -n "  ZeroClaw: "
        local zc_ver=$(zeroclaw --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}OK$zc_ver${NC}"
        ((passed++))
    else
        echo -e "  ZeroClaw: ${YELLOW}WARN no instalado${NC}"
    fi

    echo ""
    echo "  Resultado: $passed/$checks checks passaram"
    echo ""
}

# ============================================================
# INSTALAR HERRAMIENTAS BASE
# ============================================================
install_base_tools() {
    info "Instalando herramientas base..."
    
    pkg update -y 2>/dev/null || true
    
    local base_tools=(
        git curl wget openssl openssh
        vim nano htop termux-api
        clang make cmake ninja-build
        python pip python-dev
        nodejs npm
    )
    
    for tool in "${base_tools[@]}"; do
        echo -n "  $tool... "
        if command -v "$tool" &>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            if pkg install -y "$tool" 2>/dev/null; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${YELLOW}FAIL${NC}"
            fi
        fi
    done
}

# ============================================================
# CONFIGURAR API KEYS
# ============================================================
configure_api_keys() {
    echo ""
    echo "============================================================"
    echo "  CONFIGURAR API KEYS"
    echo "============================================================"
    echo ""
    
    mkdir -p "$OPENCLAW_DIR"
    
    echo -n "  GROQ_API_KEY"
    if [[ -n "${GROQ_API_KEY:-}" ]]; then
        echo -e " ${GREEN}OK ya configurada${NC}"
    elif grep -q "GROQ_API_KEY" "$ENV_FILE" 2>/dev/null; then
        echo -e " ${GREEN}OK ya configurada${NC}"
    else
        echo ""
        echo -n "    Ingresa tu GROQ API Key (ENTER para omitir): "
        read -r gk
        if [[ -n "$gk" ]]; then
            echo "GROQ_API_KEY=$gk" >> "$ENV_FILE"
            success "GROQ_API_KEY guardada"
        fi
    fi
    
    echo ""
}

# ============================================================
# INSTALAR SKILLS (globales y por proyecto)
# ============================================================
install_skills() {
    info "Instalando SWAL Skills..."
    
    local global_skills_dir="$HOME/.zeroclaw/skills"
    mkdir -p "$global_skills_dir"
    
    local skills=(
        "cortex-memory"
        "sales-agent"
        "minimax-tools"
        "gestalt-swarm"
    )
    
    for skill in "${skills[@]}"; do
        echo -n "  $skill... "
        mkdir -p "$global_skills_dir/$skill"
        cat > "$global_skills_dir/$skill/SKILL.md" << EOF
---
name: $skill
description: "SWAL global skill - $skill"
type: global
---

# $skill

Skill global instalado por setup-termux.sh v3.7
EOF
        echo -e "${GREEN}OK${NC}"
    done
    
    # Skills por proyecto
    local projects=(
        "sales:sales-agent,cortex-memory"
        "manteniapp:sales-agent,minimax-tools,cortex-memory"
        "worldexams:cortex-memory,minimax-tools"
        "orionhealth:cortex-memory,minimax-tools"
    )
    
    for project_info in "${projects[@]}"; do
        local project_name="${project_info%%:*}"
        local project_skills="${project_info#*:}"
        local project_dir="$HOME/.zeroclaw/workspace/projects/$project_name/skills"
        
        mkdir -p "$project_dir"
        
        echo -n "  [$project_name] "
        for skill in $(echo "$project_skills" | tr ',' ' '); do
            mkdir -p "$project_dir/$skill"
            echo -n "$skill "
        done
        echo -e "${GREEN}OK${NC}"
    done
    
    success "Skills instalados"
}

# ============================================================
# CONFIGURAR WORKSPACE
# ============================================================
setup_workspace() {
    info "Configurando workspace..."
    
    mkdir -p "$WORKSPACE_DIR"
    
    cat > "$WORKSPACE_DIR/README.md" << 'EOF'
# ZeroClaw SWAL Node Workspace

ZeroClaw Termux Setup - $(date)
EOF
    
    cat > "$WORKSPACE_DIR/MEMORY.md" << 'EOF'
# SWAL Node Memory

ZeroClaw Termux - Iniciado $(date)
EOF
    
    success "Workspace configurado en $WORKSPACE_DIR"
}

# ============================================================
# CONFIGURAR ZEROCLAW AUTONOMY LEVEL (FULL - no pide aprobacion)
# ============================================================
configure_zeroclaw_autonomy() {
    info "Configurando ZeroClaw autonomy level..."
    
    local config_file="$HOME/.zeroclaw/config.toml"
    
    mkdir -p "$HOME/.zeroclaw"
    
    # Verificar si ya existe autonomy_level y cambiar a full
    if grep -q 'autonomy_level' "$config_file" 2>/dev/null; then
        sed -i 's/autonomy_level = ".*"/autonomy_level = "full"/' "$config_file"
        success "autonomy_level actualizado a full"
    else
        if grep -q '^\[agent\]' "$config_file" 2>/dev/null; then
            sed -i '/^\[agent\]/a autonomy_level = "full"' "$config_file"
        else
            echo -e "\n[agent]" >> "$config_file"
            echo 'autonomy_level = "full"' >> "$config_file"
        fi
        success "autonomy_level configurado a full"
    fi
    
    grep 'autonomy_level' "$config_file" 2>/dev/null || true
}

# ============================================================
# CONFIGURAR SECURITY POLICY (comandos permitidos)
# ============================================================
configure_security_policy() {
    info "Configurando security policy (comandos permitidos)..."
    
    local config_file="$HOME/.zeroclaw/config.toml"
    
    if grep -q '^\[security\]' "$config_file" 2>/dev/null; then
        if ! grep -q 'allowed_commands' "$config_file"; then
            sed -i '/^\[security\]/a allowed_commands = ["pkg", "pkg_install", "pkg_update", "pkg_upgrade", "termux-setup-storage", "git", "curl", "wget", "openssl", "sshd", "ssh-keygen", "node", "npm", "python", "python3", "pip", "pip3", "bash", "sh", "echo", "pwd", "ls", "cd", "mkdir", "rm", "cp", "mv", "cat", "grep", "sed", "awk", "find"]' "$config_file"
        fi
        success "security policy actualizada"
    else
        echo -e "\n[security]" >> "$config_file"
        echo 'allowed_commands = ["pkg", "pkg_install", "pkg_update", "pkg_upgrade", "termux-setup-storage", "git", "curl", "wget", "openssl", "sshd", "ssh-keygen", "node", "npm", "python", "python3", "pip", "pip3", "bash", "sh", "echo", "pwd", "ls", "cd", "mkdir", "rm", "cp", "mv", "cat", "grep", "sed", "awk", "find"]' >> "$config_file"
        success "security policy creada"
    fi
    
    grep 'allowed_commands' "$config_file" 2>/dev/null || true
}

# ============================================================
# MOSTRAR LOGO SWAL
# ============================================================
show_swal_logo() {
    echo ""
    echo "============================================================"
    echo "  LOGO SWAL - Colores OrionHealth"
    echo "============================================================"
    echo ""
    
    if ! command -v node &>/dev/null || ! command -v npx &>/dev/null; then
        warn "Node.js no instalado. Saltando logo..."
        return
    fi
    
    info "Generando logo SWAL con oh-my-logo..."
    echo ""
    
    if npx --yes oh-my-logo "SWAL" --palette-colors "$ORION_COLORS" --filled --letter-spacing 2 2>/dev/null; then
        success "Logo SWAL mostrado!"
    else
        echo -e "\033[1;36m============================================================\033[0m"
        echo -e "\033[1;32m  S  W  A  L\033[0m"
        echo -e "\033[1;36m============================================================\033[0m"
    fi
    
    echo ""
}

# ============================================================
# MOSTRAR CONFIGURACION COMPLETA (para copiar manualmente)
# ============================================================
show_config() {
    echo ""
    echo "============================================================"
    echo "  CONFIGURACION DE SEGURIDAD ZEROCLAW"
    echo "============================================================"
    echo ""
    
    local config_file="$HOME/.zeroclaw/config.toml"
    
    if [[ -f "$config_file" ]]; then
        info "Archivo: $config_file"
        echo ""
        echo "--- Contenido actual ---"
        echo ""
        cat "$config_file"
        echo ""
        
        echo "--- Politicas restrictivas ---"
        echo ""
        
        local autonomy=$(grep -i "autonomy_level" "$config_file" 2>/dev/null || echo "autonomy_level: NO CONFIGURADO")
        echo "  * $autonomy"
        
        if grep -q "allowed_commands" "$config_file" 2>/dev/null; then
            local allowed=$(grep "allowed_commands" "$config_file" 2>/dev/null)
            echo "  * $allowed"
        else
            echo "  * allowed_commands: NO CONFIGURADO"
        fi
        
        echo ""
        info "Si el bot sigue bloqueado, copia el config arriba y revisalo"
        
    else
        warn "Archivo de configuracion no encontrado"
    fi
    
    echo ""
    echo "============================================================"
    echo "  SETUP COMPLETADO!"
    echo "============================================================"
    echo ""
    info "Proximos pasos:"
    echo "  1. Revisa la configuracion de seguridad arriba"
    echo "  2. Copia el contenido si necesitas compartirlo"
    echo "  3. Reinicia zeroclaw: pkill zeroclaw && zeroclaw daemon"
    echo ""
}

# ============================================================
# MENU DE PAQUETES
# ============================================================
show_menu() {
    echo ""
    echo "============================================================"
    echo "  INSTALAR PAQUETES"
    echo "============================================================"
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
    echo "  [A] TODOS"
    echo "  [S] Solo skills (sin paquetes)"
    echo ""
    echo -n "  Seleccion (ej: 1,2): "
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
    
    pkg update -y 2>/dev/null || true

    echo "$selection" | tr ',' '\n' | while read -r choice; do
        case "$choice" in
            1) pkg install -y python pip 2>/dev/null && echo -e "  Python: ${GREEN}OK${NC}" ;;
            2) pkg install -y nodejs npm 2>/dev/null && echo -e "  Node.js: ${GREEN}OK${NC}" ;;
            3) pkg install -y golang 2>/dev/null && echo -e "  Go: ${GREEN}OK${NC}" ;;
            4) pkg install -y rust 2>/dev/null && echo -e "  Rust: ${GREEN}OK${NC}" ;;
            5) pkg install -y openjdk-17 2>/dev/null && echo -e "  Java: ${GREEN}OK${NC}" ;;
            6) pkg install -y ruby 2>/dev/null && echo -e "  Ruby: ${GREEN}OK${NC}" ;;
            7) pkg install -y php 2>/dev/null && echo -e "  PHP: ${GREEN}OK${NC}" ;;
            8) pkg install -y dart 2>/dev/null && echo -e "  Flutter: ${GREEN}OK${NC}" ;;
            9) pkg install -y cmake ninja clang make 2>/dev/null && echo -e "  Build tools: ${GREEN}OK${NC}" ;;
        esac
    done
}

# ============================================================
# MAIN
# ============================================================
main() {
    echo ""
    echo "============================================================"
    echo "  ZeroClaw SWAL Node - Termux Setup v3.7"
    echo "============================================================"
    echo ""
    
    fix_broken_config
    clean_motd
    check_permissions
    check_services
    diagnose
    
    show_menu
    read -r selection
    
    echo ""
    info "Instalando: $selection"
    
    install_base_tools
    install_packages "$selection"
    configure_api_keys
    install_skills
    setup_workspace
    
    configure_zeroclaw_autonomy
    configure_security_policy
    show_swal_logo
    diagnose
    show_config
}

main "$@"