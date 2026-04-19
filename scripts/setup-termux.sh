#!/bin/bash
# ============================================================
# ZeroClaw SWAL Node - Termux Setup v3.9 (DEBUG MODE)
# ============================================================
set -x  # Enable debug mode - shows every command

DEBUG_FILE="/data/tmp/setup-debug.log"
exec 2>"$DEBUG_FILE"

echo "============================================================"
echo "  ZeroClaw SWAL Node - Termux Setup v3.9 (DEBUG)"
echo "============================================================"
echo "DEBUG: Starting script at $(date)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[SWAL]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
ZEROCLAW_DIR="$HOME/.zeroclaw"
ENV_FILE="$OPENCLAW_DIR/secrets.env"

echo "DEBUG: HOME=$HOME"
echo "DEBUG: OPENCLAW_DIR=$OPENCLAW_DIR"
echo "DEBUG: ZEROCLAW_DIR=$ZEROCLAW_DIR"

# ============================================================
# FIX BROKEN CONFIG
# ============================================================
echo "DEBUG: Running fix_broken_config..."
info "Buscando configuraciones rotas..."

if [[ -f "$HOME/.bashrc" ]]; then
    echo "DEBUG: .bashrc exists, checking for zeroclaw start..."
    if grep -q "zeroclaw start" "$HOME/.bashrc" 2>/dev/null; then
        warn "Encontrado 'zeroclaw start' en .bashrc!"
        sed -i '/zeroclaw start/d' "$HOME/.bashrc"
        success "Reparado"
    fi
fi

if [[ -f "$HOME/.zshrc" ]]; then
    echo "DEBUG: .zshrc exists, checking for zeroclaw start..."
    if grep -q "zeroclaw start" "$HOME/.zshrc" 2>/dev/null; then
        warn "Encontrado 'zeroclaw start' en .zshrc!"
        sed -i '/zeroclaw start/d' "$HOME/.zshrc"
        success "Reparado"
    fi
fi

echo "DEBUG: fix_broken_config done"

# ============================================================
# CLEAN MOTD
# ============================================================
echo "DEBUG: Running clean_motd..."
info "Limpiando mensajes de inicio..."
touch "$HOME/.hushlogin" 2>/dev/null || true
success "Mensajes de inicio limpiados"

# ============================================================
# CHECK PERMISSIONS
# ============================================================
echo "DEBUG: Running check_permissions..."
info "Verificando permisos de Termux..."

if [[ -n "$TERMUX_VERSION" ]]; then
    echo "DEBUG: Running in Termux"
    info "Ejecutando en Termux"
    
    if [[ ! -d "$HOME/storage" ]]; then
        warn "Permiso de storage no detectado"
        echo "DEBUG: Requesting storage permission..."
        termux-setup-storage -y 2>/dev/null || true
        sleep 2
    else
        echo "DEBUG: Storage permission already granted"
    fi
fi

echo "DEBUG: Checking pkg access..."
if pkg update -y &>/dev/null 2>&1; then
    PKG_ACCESS=true
    success "pkg tiene acceso completo"
else
    PKG_ACCESS=false
    warn "pkg tiene acceso limitado"
fi

echo "DEBUG: check_permissions done, PKG_ACCESS=$PKG_ACCESS"

# ============================================================
# CHECK SERVICES
# ============================================================
echo "DEBUG: Running check_services..."
info "Verificando servicios..."

echo -n "  SSH server: "
if pgrep -f sshd &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
elif command -v sshd &>/dev/null; then
    echo -e "${YELLOW}WARN${NC}"
else
    echo -e "${YELLOW}WARN${NC}"
fi

echo -n "  ZeroClaw daemon: "
if pgrep -f "zeroclaw daemon" &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
elif command -v zeroclaw &>/dev/null; then
    echo -e "${YELLOW}WARN${NC}"
else
    echo -e "${YELLOW}WARN${NC}"
fi

echo "DEBUG: check_services done"

# ============================================================
# CONFIGURE ZEROCLAW AUTONOMY
# ============================================================
echo "DEBUG: Running configure_zeroclaw_autonomy..."
info "Configurando ZeroClaw autonomy level..."

local config_file="$HOME/.zeroclaw/config.toml"
echo "DEBUG: config_file=$config_file"

mkdir -p "$HOME/.zeroclaw"
echo "DEBUG: Directory created"

if [[ -f "$config_file" ]]; then
    echo "DEBUG: config_file exists, content:"
    cat "$config_file"
else
    echo "DEBUG: config_file does not exist, creating..."
fi

if grep -q 'autonomy_level' "$config_file" 2>/dev/null; then
    echo "DEBUG: Modifying existing autonomy_level..."
    sed -i 's/autonomy_level = ".*"/autonomy_level = "full"/' "$config_file"
else
    echo "DEBUG: Adding autonomy_level..."
    if grep -q '^\[agent\]' "$config_file" 2>/dev/null; then
        sed -i '/^\[agent\]/a autonomy_level = "full"' "$config_file"
    else
        echo -e "\n[agent]" >> "$config_file"
        echo 'autonomy_level = "full"' >> "$config_file"
    fi
fi

success "autonomy_level = full"
echo "DEBUG: configure_zeroclaw_autonomy done"

# ============================================================
# CONFIGURE SECURITY POLICY
# ============================================================
echo "DEBUG: Running configure_security_policy..."
info "Configurando security policy..."

local allowed_cmds='allowed_commands = ["pkg", "git", "curl", "wget", "bash", "sh", "echo", "pwd", "ls", "cd", "mkdir", "npm", "node", "python", "python3", "pip"]'

if grep -q '^\[security\]' "$config_file" 2>/dev/null; then
    echo "DEBUG: [security] section exists"
    if ! grep -q 'allowed_commands' "$config_file"; then
        sed -i "/^\[security\]/a $allowed_cmds" "$config_file"
    fi
else
    echo "DEBUG: Adding [security] section..."
    echo -e "\n[security]" >> "$config_file"
    echo "$allowed_cmds" >> "$config_file"
fi

success "Security policy configurada"
echo "DEBUG: configure_security_policy done"

# ============================================================
# SHOW CONFIG
# ============================================================
echo "DEBUG: Running show_config..."
echo ""
echo "============================================================"
echo "  CONFIGURACION DE SEGURIDAD ZEROCLAW"
echo "============================================================"
echo ""

info "Archivo: $config_file"
echo ""
echo "--- Contenido completo ---"
if [[ -f "$config_file" ]]; then
    cat "$config_file"
else
    echo "ARCHIVO NO EXISTE!"
fi
echo ""

echo "--- Resumen ---"
grep -i "autonomy_level" "$config_file" 2>/dev/null || echo "autonomy_level: NO CONFIGURADO"
grep "allowed_commands" "$config_file" 2>/dev/null || echo "allowed_commands: NO CONFIGURADO"

echo ""
echo "DEBUG: show_config done"

# ============================================================
# SHOW DEBUG LOG LOCATION
# ============================================================
echo ""
echo "============================================================"
echo "  SETUP COMPLETADO!"
echo "============================================================"
echo ""
info "Log debug guardado en: $DEBUG_FILE"
echo "Para ver errores: cat $DEBUG_FILE"
echo ""
echo "Proximos pasos:"
echo "  1. Copia el config de arriba"
echo "  2. Reinicia zeroclaw: pkill zeroclaw; zeroclaw daemon"
echo ""

echo "DEBUG: Script finished at $(date)"