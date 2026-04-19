#!/bin/bash
# ============================================================
# ZeroClaw Termux — MiniMax MCP Setup
# Corre esto en tu Termux después de setup-termux.sh
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[SWAL]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

# ============================================================
# 1. Verificar requisitos
# ============================================================
info "Verificando requisitos..."

if ! command -v uvx &>/dev/null; then
    warn "uvx no encontrado. Instalando uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Recargar PATH
    export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v uvx &>/dev/null; then
    error "uvx sigue sin estar disponible después de instalación"
    exit 1
fi

success "uvx disponible"

# ============================================================
# 2. Configurar MiniMax API Key
# ============================================================
info "Configurando MiniMax API Key..."

ZEROCLAW_DIR="$HOME/.zeroclaw"
CONFIG_FILE="$ZEROCLAW_DIR/config.toml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    error "No encontré config.toml en $ZEROCLAW_DIR"
    error "Primero ejecuta: setup-termux.sh"
    exit 1
fi

# Backup config
cp "$CONFIG_FILE" "$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"

# Pedir API key si no está en secrets
SECRETS_FILE="$ZEROCLAW_DIR/secrets.env"
if [[ ! -f "$SECRETS_FILE" ]]; then
    touch "$SECRETS_FILE"
fi

if ! grep -q "MINIMAX_API_KEY" "$SECRETS_FILE" 2>/dev/null; then
    echo ""
    warn "Necesito tu MiniMax API Key (del Coding Plan):"
    read -p "MINIMAX_API_KEY=" -r MINIMAX_API_KEY
    if [[ -n "$MINIMAX_API_KEY" ]]; then
        echo "MINIMAX_API_KEY=$MINIMAX_API_KEY" >> "$SECRETS_FILE"
        success "API key guardada en $SECRETS_FILE"
    else
        error "No se proporcionó API key"
        exit 1
    fi
else
    info "MINIMAX_API_KEY ya configurada"
fi

# ============================================================
# 3. Agregar MCP server al config.toml
# ============================================================
info "Agregando MCP server al config.toml..."

# El formato de MCP en ZeroClaw/Termux puede variar
# Intentar detectar el formato actual

if grep -q "\[mcp\]" "$CONFIG_FILE" 2>/dev/null; then
    info "Bloque [mcp] ya existe, añadiendo servidor..."
    
    # Agregar después de [mcp] o crear sección
    if ! grep -q "minimax-coding-plan-mcp" "$CONFIG_FILE" 2>/dev/null; then
        # Insertar después de [mcp]
        sed -i '/\[mcp\]/a \
\[\[mcp.servers\]\]
name = "minimax"\
command = "uvx"\
args = ["minimax-coding-plan-mcp", "-y"]\
env = { MINIMAX_API_KEY = '"'$'"'${MINIMAX_API_KEY}'"'", MINIMAX_API_HOST = "https://api.minimax.io" }' "$CONFIG_FILE"
    fi
else
    info "Creando sección [mcp]..."
    cat >> "$CONFIG_FILE" << 'EOF'

[mcp]
[[mcp.servers]]
name = "minimax"
command = "uvx"
args = ["minimax-coding-plan-mcp", "-y"]
env = { MINIMAX_API_KEY = "${MINIMAX_API_KEY}", MINIMAX_API_HOST = "https://api.minimax.io" }
EOF
fi

success "MCP server configurado"

# ============================================================
# 4. Verificar con zeroclaw
# ============================================================
info "Verificando configuración MCP..."

if command -v zeroclaw &>/dev/null; then
    info "Comando zeroclaw mcp list:"
    zeroclaw mcp list 2>&1 || true
else
    warn "zeroclaw no está en PATH. Puede requerir reiniciar sesión."
fi

# ============================================================
# 5. Probar MCP
# ============================================================
info "Probando MiniMax MCP..."

echo "Ejecutando: uvx minimax-coding-plan-mcp --help"
timeout 10 uvx minimax-coding-plan-mcp --help 2>&1 || {
    warn "El servidor MCP no responde a --help (puede ser normal)"
}

success "Setup de MCP completado!"
echo ""
info "Próximos pasos:"
echo "  1. Reinicia zeroclaw: zeroclaw daemon"
echo "  2. Verifica MCP: zeroclaw mcp list"
echo "  3. Prueba web_search:zeroclaw tools list | grep web_search"