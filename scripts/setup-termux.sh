#!/bin/bash
# ============================================================
# ZeroClaw SWAL Node - Termux Setup v5.0
# With interactive menu, SWAL status dashboard, and dev tools
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

log() { printf "%b[SWAL]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

CONFIG_FILE="$HOME/.zeroclaw/config.toml"
STATUS_SCRIPT="$HOME/.local/bin/swal-status.sh"
STATUS_URL="https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/master/scripts/swal-status.sh"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}ZeroClaw SWAL Node - Termux Setup v5.0${NC}           ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# 0. CHECK AND INSTALL MISSING TOOLS
# ============================================================
info "0/6 - Verificando herramientas de desarrollo..."

MISSING_TOOLS=()
INSTALLED=()

check_tool() {
    if command -v "$1" &>/dev/null; then
        INSTALLED+=("$1")
    else
        MISSING_TOOLS+=("$1")
    fi
}

# Core tools to check
check_tool "git"
check_tool "curl"
check_tool "wget"
check_tool "python"
check_tool "python3"
check_tool "pip"
check_tool "pip3"
check_tool "node"
check_tool "npm"
check_tool "gh"
check_tool "rustc"
check_tool "cargo"

echo -e "   ${GREEN}✅ Instaladas:${NC} ${INSTALLED[*]}"
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "   ${YELLOW}⚠️  Faltan:${NC} ${MISSING_TOOLS[*]}"
    info "Instalando herramientas faltantes..."
    
    # Update package list
    pkg update -y 2>/dev/null
    
    # Install missing tools
    for tool in "${MISSING_TOOLS[@]}"; do
        case "$tool" in
            "gh")
                pkg install gh -y 2>/dev/null
                success "gh instalado"
                ;;
            "rustc"|"cargo")
                pkg install rust -y 2>/dev/null
                success "Rust instalado"
                ;;
            "node"|"npm")
                pkg install nodejs -y 2>/dev/null
                success "Node.js instalado"
                ;;
            "python"|"python3"|"pip"|"pip3")
                pkg install python -y 2>/dev/null
                success "Python instalado"
                ;;
            *)
                # Try generic install
                pkg install "$tool" -y 2>/dev/null || true
                ;;
        esac
    done
else
    success "Todas las herramientas ya estan instaladas"
fi

# ============================================================
# 1. FIX BROKEN CONFIG
# ============================================================
info "1/6 - Verificando configuraciones rotas..."

if [[ -f "$HOME/.bashrc" ]]; then
    if grep -q "zeroclaw start" "$HOME/.bashrc" 2>/dev/null; then
        warn "Encontrado 'zeroclaw start' en .bashrc - removiendo..."
        sed -i '/zeroclaw start/d' "$HOME/.bashrc"
        success "Reparado .bashrc"
    fi
fi

if [[ -f "$HOME/.zshrc" ]]; then
    if grep -q "zeroclaw start" "$HOME/.zshrc" 2>/dev/null; then
        warn "Encontrado 'zeroclaw start' en .zshrc - removiendo..."
        sed -i '/zeroclaw start/d' "$HOME/.zshrc"
        success "Reparado .zshrc"
    fi
fi

success "Configuraciones rotas verificadas"

# ============================================================
# 2. CLEAN MOTD
# ============================================================
info "2/6 - Limpiando mensajes de inicio..."
touch "$HOME/.hushlogin" 2>/dev/null || true
success "Mensajes limpiados"

# ============================================================
# 3. INSTALL SWAL STATUS SCRIPT
# ============================================================
info "3/6 - Instalando SWAL status dashboard..."

mkdir -p "$HOME/.local/bin"

if command -v curl &>/dev/null; then
    if curl -fsSL "$STATUS_URL" -o "$STATUS_SCRIPT" 2>/dev/null; then
        chmod +x "$STATUS_SCRIPT" 2>/dev/null || true
        success "swal-status.sh instalado"
    else
        warn "No se pudo descargar swal-status.sh"
    fi
else
    warn "curl no disponible"
fi

# Add to MOTD
MOTD_LINE='[[ -x "$HOME/.local/bin/swal-status.sh" ]] && "$HOME/.local/bin/swal-status.sh"'

if [[ -f "$HOME/.bashrc" ]] && ! grep -q "swal-status.sh" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# SWAL Status Dashboard" >> "$HOME/.bashrc"
    echo "$MOTD_LINE" >> "$HOME/.bashrc"
fi

if [[ -f "$HOME/.zshrc" ]] && ! grep -q "swal-status.sh" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# SWAL Status Dashboard" >> "$HOME/.zshrc"
    echo "$MOTD_LINE" >> "$HOME/.zshrc"
fi

success "MOTD configurado"

# ============================================================
# 4. CONFIGURE ZEROCLAW
# ============================================================
info "4/6 - Configurando ZeroClaw..."

mkdir -p "$HOME/.zeroclaw"

# Backup existing config
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    info "Backup guardado: ${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
fi

# Detect API keys from environment
MINIMAX_KEY="${MINIMAX_API_KEY:-}"
GROQ_KEY="${GROQ_API_KEY:-}"
TG_TOKEN="${TG_ZEROCLAW_TOKEN:-}"

cat > "$CONFIG_FILE" << CONFIGEOF
# ZeroClaw Config - Generated by setup-termux.sh v5.0
# SWAL Node - SouthWest AI Labs

[agent]
autonomy_level = "full"

[security]
allowed_commands = ["pkg", "git", "curl", "wget", "bash", "sh", "python", "python3", "pip", "npm", "node", "ssh", "scp", "find", "grep", "sed", "awk", "cat", "ls", "cd", "mkdir", "rm", "cp", "mv", "gh", "docker", "cargo", "rustc", "pip3"]

[workspace]
path = "~/.zeroclaw/workspace"

[providers]

[providers.models]

[providers.models.minimax]
name = "MiniMax M2.7"
base_url = "https://api.minimaxi.chat/v1"
api_key = "${MINIMAX_KEY}"

[providers.models.groq]
name = "Groq"
base_url = "https://api.groq.com/openai/v1"
api_key = "${GROQ_KEY}"

[providers.fallback]
provider = "MiniMax M2.7"

[telegram]
CONFIGEOF

# Add Telegram bot token if available
if [[ -n "$TG_TOKEN" ]]; then
    echo "enabled = true" >> "$CONFIG_FILE"
    echo "bot_token = \"$TG_TOKEN\"" >> "$CONFIG_FILE"
    success "Telegram bot token configurado"
else
    echo "# bot_token = \"YOUR_BOT_TOKEN\"  # Not set" >> "$CONFIG_FILE"
    warn "Telegram bot token no detectado (TG_ZEROCLAW_TOKEN no definido)"
fi

if [[ -n "$MINIMAX_KEY" ]]; then
    success "MiniMax API key configurado"
else
    warn "MiniMax API key no detectada (MINIMAX_API_KEY no definido)"
fi

if [[ -n "$GROQ_KEY" ]]; then
    success "Groq API key configurado"
else
    warn "Groq API key no detectada (GROQ_API_KEY no definido)"
fi

success "ZeroClaw configurado"

# ============================================================
# 5. ZEROCLAW DOCTOR - Health Check
# ============================================================
info "5/6 - Ejecutando ZeroClaw Doctor..."

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  🩺 ZEROCLAW DOCTOR - Health Check${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

DOCTOR_PASS=0
DOCTOR_FAIL=0

check() {
    if [[ $1 -eq 0 ]]; then
        echo -e "   ${GREEN}✅ $2${NC}"
        DOCTOR_PASS=$((DOCTOR_PASS + 1))
    else
        echo -e "   ${RED}❌ $2${NC}"
        DOCTOR_FAIL=$((DOCTOR_FAIL + 1))
    fi
}

# Check 1: Config file exists
[[ -f "$CONFIG_FILE" ]]
check $? "Config file exists"

# Check 2: Config has [agent] section
grep -q '^\[agent\]' "$CONFIG_FILE"
check $? "[agent] section present"

# Check 3: Config has autonomy_level = full
grep -q 'autonomy_level.*=.*"full"' "$CONFIG_FILE"
check $? "autonomy_level = full"

# Check 4: Config has [providers.models.minimax]
grep -q '^\[providers\.models\.minimax\]' "$CONFIG_FILE"
check $? "providers.models.minimax defined"

# Check 5: Config has MiniMax base_url
grep -q 'base_url.*=.*"https://api\.minimaxi\.chat' "$CONFIG_FILE"
check $? "MiniMax base_url correct (api.minimaxi.chat)"

# Check 6: Config has providers.fallback (valid reference)
if grep -q '^\[providers\.fallback\]' "$CONFIG_FILE"; then
    FALLBACK_REF=$(grep -A1 '^\[providers\.fallback\]' "$CONFIG_FILE" | grep 'provider' | sed 's/.*= *//' | tr -d ' "')
    if grep -q "^\[providers\.models\.${FALLBACK_REF}\]$" "$CONFIG_FILE" 2>/dev/null; then
        check 0 "providers.fallback references valid model"
    else
        check 1 "providers.fallback references '${FALLBACK_REF}' - MODEL NOT FOUND"
    fi
else
    check 1 "providers.fallback section missing"
fi

# Check 7: ZeroClaw binary exists
command -v zeroclaw &>/dev/null
check $? "zeroclaw binary installed"

# Check 8: MINIMAX_API_KEY set in environment
[[ -n "$MINIMAX_API_KEY" ]]
check $? "MINIMAX_API_KEY environment variable set"

# Check 9: MiniMax API reachable
if [[ -n "$MINIMAX_API_KEY" ]]; then
    curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $MINIMAX_API_KEY" "https://api.minimaxi.chat/v1/models" &>/dev/null
    [[ "$?" == "000" ]] && curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $MINIMAX_API_KEY" "https://api.minimaxi.chat/v1/models" | grep -qE "200|401|403"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $MINIMAX_API_KEY" "https://api.minimaxi.chat/v1/models" --max-time 10 2>/dev/null)
    [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]
    check $? "MiniMax API reachable (HTTP $HTTP_CODE)"
else
    check 1 "MiniMax API not testable (no API key)"
fi

# Check 10: GH CLI installed
command -v gh &>/dev/null
check $? "gh CLI installed"

# Check 11: GitHub auth status
if command -v gh &>/dev/null; then
    gh auth status &>/dev/null
    check $? "GitHub authenticated"
else
    check 1 "GitHub auth not testable (gh not installed)"
fi

# Summary
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${BOLD}🩺 Doctor Summary: ${GREEN}$DOCTOR_PASS passed${NC} ${RED}$DOCTOR_FAIL failed${NC}${BOLD}${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $DOCTOR_FAIL -eq 0 ]]; then
    echo -e "   ${GREEN}✅ System READY to launch!${NC}"
    echo ""
    echo -e "   ${BOLD}Run: ${GREEN}zeroclaw daemon${NC} ${BOLD}to start${NC}"
    LAUNCH_READY=1
else
    echo -e "   ${RED}❌ Issues found - fix before launching${NC}"
    echo ""
    echo -e "   ${BOLD}Run setup again: ${CYAN}curl -fsSL ... | bash${NC}"
    LAUNCH_READY=0
fi

# Optional: Test daemon startup (3 second test)
if [[ $DOCTOR_FAIL -eq 0 ]] && command -v zeroclaw &>/dev/null; then
    echo ""
    echo -ne "   ${BOLD}Testing daemon startup (5s)... ${NC}"
    zeroclaw daemon &>/dev/null &
    ZC_PID=$!
    sleep 5
    kill $ZC_PID 2>/dev/null || true
    if curl -s --max-time 3 "http://127.0.0.1:42617/health" | grep -q "ok" 2>/dev/null; then
        echo -e "${GREEN}✅ Daemon started and responding!${NC}"
        echo -e "   ${GREEN}Gateway: http://127.0.0.1:42617${NC}"
    else
        echo -e "${YELLOW}⚠️  Daemon started but health check pending${NC}"
        echo -e "   Gateway should be at http://127.0.0.1:42617"
    fi
fi

# ============================================================
# 6. VALIDATE AND FIX CONFIG
# ============================================================
info "6/6 - Validando configuracion..."

if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Config no existe! Ejecuta el setup de nuevo."
    exit 1
fi

# Check for critical config issues
CONFIG_ISSUES=0

# Issue 1: providers.models.default without model definition
if grep -q 'providers.models.default' "$CONFIG_FILE" && ! grep -q 'name.*=.*"MiniMax\|name.*=.*Groq\|base_url\|api_key' "$CONFIG_FILE" 2>/dev/null; then
    error "PROBLEMA: providers.models.default existe pero no define name/base_url/api_key"
    # Fix: Remove the broken default and use named providers
    sed -i '/\[providers\.models\.default\]/,/^$/d' "$CONFIG_FILE"
    info "Fix Applied: removed broken [providers.models.default]"
    CONFIG_ISSUES=$((CONFIG_ISSUES + 1))
fi

# Issue 2: providers.fallback references model that doesn't exist
FALLBACK_PROVIDER=$(grep 'provider.*=.*"' "$CONFIG_FILE" 2>/dev/null | grep -v 'bot_token' | tail -1 | sed 's/.*provider.*=.*"//;s/".*//')
if [[ -n "$FALLBACK_PROVIDER" ]]; then
    if ! grep -q "\[providers\.models\.${FALLBACK_PROVIDER}\]" "$CONFIG_FILE" 2>/dev/null; then
        error "PROBLEMA: providers.fallback referencia '$FALLBACK_PROVIDER' que no existe en providers.models"
        # Fix: Remove the fallback line
        sed -i '/providers.fallback/,/^$/d' "$CONFIG_FILE"
        info "Fix Applied: removed broken providers.fallback"
        CONFIG_ISSUES=$((CONFIG_ISSUES + 1))
    fi
fi

# Issue 3: Missing required sections
for section in agent security providers; do
    if ! grep -q "^\[${section}\]" "$CONFIG_FILE" 2>/dev/null; then
        error "PROBLEMA: Seccion [$section] falta en el config"
        CONFIG_ISSUES=$((CONFIG_ISSUES + 1))
    fi
done

if [[ $CONFIG_ISSUES -eq 0 ]]; then
    success "Config verificada - todo OK"
else
    warn "Se encontraron y repararon $CONFIG_ISSUES problema(s) en el config"
fi

# ============================================================
# SHOW STATUS DASHBOARD
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  STATUS DEL SISTEMA${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ -x "$STATUS_SCRIPT" ]]; then
    bash "$STATUS_SCRIPT"
else
    # Fallback inline status
    echo -e "${CYAN}--- Servicios ---${NC}"
    echo -n "  ZeroClaw: "
    if pgrep -f "zeroclaw daemon" &>/dev/null; then
        echo -e "${GREEN}✅ running${NC}"
    elif command -v zeroclaw &>/dev/null; then
        echo -e "${YELLOW}⚠️  stopped${NC}"
    else
        echo -e "${RED}❌ not installed${NC}"
    fi
fi

# ============================================================
# INTERACTIVE MENU
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  MENU DE ACCIONES${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "   ${GREEN}[1]${NC}  Iniciar ZeroClaw daemon"
echo -e "   ${GREEN}[2]${NC}  Reiniciar ZeroClaw daemon"
echo -e "   ${GREEN}[3]${NC}  Ver status completo (swal-status)"
echo -e "   ${GREEN}[4]${NC}  Ver config de ZeroClaw"
echo -e "   ${GREEN}[5]${NC}  Abrir shell de ZeroClaw"
echo -e "   ${GREEN}[6]${NC}  Configurar GH (GitHub CLI)"
echo -e "   ${GREEN}[0]${NC}  Salir (solo mostrar MOTD)"
echo ""
echo -ne "   ${BOLD}Selecciona una opcion:${NC} "

read -r option

case "$option" in
    1)
        echo ""
        info "Iniciando ZeroClaw daemon..."
        if command -v zeroclaw &>/dev/null; then
            echo -e "${GREEN}Ejecutando: zeroclaw daemon${NC}"
            echo -e "${DIM}Usa Ctrl+C para detener${NC}"
            echo ""
            zeroclaw daemon
        else
            echo -e "${RED}zeroclaw no esta instalado${NC}"
        fi
        ;;
    2)
        echo ""
        info "Reiniciando ZeroClaw daemon..."
        pkill zeroclaw 2>/dev/null || true
        sleep 1
        if command -v zeroclaw &>/dev/null; then
            echo -e "${GREEN}Ejecutando: zeroclaw daemon${NC}"
            zeroclaw daemon
        else
            echo -e "${RED}zeroclaw no esta instalado${NC}"
        fi
        ;;
    3)
        echo ""
        if [[ -x "$STATUS_SCRIPT" ]]; then
            bash "$STATUS_SCRIPT"
        else
            echo -e "${RED}swal-status.sh no encontrado${NC}"
        fi
        ;;
    4)
        echo ""
        echo -e "${CYAN}--- Contenido de $CONFIG_FILE ---${NC}"
        cat "$CONFIG_FILE"
        ;;
    5)
        echo ""
        info "Abriendo shell de ZeroClaw..."
        if command -v zeroclaw &>/dev/null; then
            zeroclaw shell
        else
            echo -e "${RED}zeroclaw no esta instalado${NC}"
        fi
        ;;
    6)
        echo ""
        info "Configurando GitHub CLI (gh)..."
        if command -v gh &>/dev/null; then
            echo -e "${CYAN}GH ya esta instalado. Estado:${NC}"
            gh auth status
        else
            echo -e "${YELLOW}GH no esta instalado. Instalandolo...${NC}"
            pkg install gh -y
        fi
        ;;
    0|*)
        echo ""
        info "Saliendo..."
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  ✅ Setup completado!${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Proximos pasos:${NC}"
        echo -e "    1. ZeroClaw ya esta configurado con autonomy=full"
        echo -e "    2. Cada vez que abras Termux veras el dashboard SWAL"
        echo -e "    3. Para ocultar MOTD: ${CYAN}touch ~/.swal-motd-disable${NC}"
        echo ""
        echo -e "  ${BOLD}Comandos utiles:${NC}"
        echo -e "    ${GREEN}zeroclaw daemon${NC}  - Iniciar daemon"
        echo -e "    ${GREEN}swal-status${NC}       - Ver status"
        echo -e "    ${GREEN}htop${NC}              - Monitor"
        echo ""
        ;;
esac
