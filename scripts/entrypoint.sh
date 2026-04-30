#!/bin/bash
set +euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[ZEROCLAW]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

WORKSPACE="${ZEROCLAW_WORKSPACE:-/zeroclaw/workspace}"
SSH_DIR="/zeroclaw/ssh"

info "=============================================="
info "  ZeroClaw SWARM Node"
info "  Workspace: $WORKSPACE"
info "=============================================="

# Verificar workspace
if [[ -d "$WORKSPACE" ]]; then
    info "Workspace existe: $WORKSPACE"
    for file in MEMORY.md SOUL.md AGENTS.md USER.md; do
        if [[ -f "$WORKSPACE/$file" ]]; then
            info "  ✓ $file"
        else
            warn "  ✗ $file"
        fi
    done
else
    warn "Workspace no encontrado: $WORKSPACE"
    mkdir -p "$WORKSPACE" 2>/dev/null || true
fi

# API Keys
if [[ -n "${GROQ_API_KEY:-}" ]]; then
    info "GROQ_API_KEY configurada"
else
    warn "GROQ_API_KEY no configurada"
fi

if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    info "GEMINI_API_KEY configurada"
else
    warn "GEMINI_API_KEY no configurada"
fi

# SSH (non-critical)
info "Configurando SSH (non-critical)..."
mkdir -p "$SSH_DIR" 2>/dev/null || true
mkdir -p /zeroclaw/logs 2>/dev/null || true

# Check gestalt_cli
if command -v gestalt_cli &>/dev/null; then
    info "gestalt_cli encontrado"
else
    warn "gestalt_cli NO encontrado (placeholder)"
fi

# Check zeroclaw
if command -v zeroclaw &>/dev/null; then
    info "zeroclaw encontrado"
else
    warn "zeroclaw NO encontrado (placeholder)"
fi

# Check tools
for tool in node npm python3 pip cargo go java terraform pulumi git gh; do
    if command -v $tool &>/dev/null; then
        info "  ✓ $tool"
    else
        warn "  ✗ $tool"
    fi
done

info "=============================================="
info "  Container vivo — Debug mode"
info "=============================================="
info "Comandos disponibles:"
info "  docker exec zeroclaw-swan-node node --version"
info "  docker exec zeroclaw-swan-node python3 --version"
info "  docker exec zeroclaw-swan-node gestalt_cli"
info "=============================================="

exec sleep infinity