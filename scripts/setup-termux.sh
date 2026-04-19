#!/bin/bash
# ============================================================
# ZeroClaw Termux Setup — SWAL Node
# Solo actualiza e instala permisos. NO reemplaza config.
# Uso: curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/main/scripts/setup-termux.sh | bash
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[SWAL]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }

info "=============================================="
info "  ZeroClaw SWAL Node — Termux Setup"
info "=============================================="

# ── Detectar si es Termux ────────────────────────────────────
if [[ "${TERMUX_VERSION:-}" == "" ]]; then
    warn "No parece Termux. Este script es para Termux (Android)."
    warn "Si estás en Linux, usa el script de Docker."
    exit 0
fi

# ── Paths críticos ────────────────────────────────────────────
OPENCLAW_DIR="$HOME/.openclaw"
ZEROCLAW_DIR="$HOME/zeroclaw"
SKILLS_DIR="$OPENCLAW_DIR/skills"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
MEMORY_DIR="$OPENCLAW_DIR/memory"

info "OpenClaw dir: $OPENCLAW_DIR"
info "Workspace: $WORKSPACE_DIR"

# ── 1. Crear directorios si no existen ───────────────────────
info "Creando estructura de directorios..."
mkdir -p "$SKILLS_DIR" 2>/dev/null || true
mkdir -p "$WORKSPACE_DIR" 2>/dev/null || true
mkdir -p "$MEMORY_DIR" 2>/dev/null || true
mkdir -p "$ZEROCLAW_DIR" 2>/dev/null || true

# ── 2. Actualizar pkg ─────────────────────────────────────────
info "Actualizando Termux packages..."
pkg update -y 2>/dev/null || true

# ── 3. Instalar deps esenciales ──────────────────────────────
info "Instalando dependencias..."
pkg install -y \
    git curl wget openssl openssh termux-api \
    python nodejs npm vim nano htop \
    clang make cmake \
    2>/dev/null || true

# ── 4. Instalar ZeroClaw CLI si no existe ────────────────────
if ! command -v zeroclaw &>/dev/null; then
    info "Instalando ZeroClaw CLI..."
    npm install -g openclaw 2>/dev/null || npm install -g openclaw
    success "ZeroClaw CLI instalado"
else
    info "ZeroClaw CLI ya instalado: $(zeroclaw --version 2>/dev/null || echo 'version unknown')"
fi

# ── 5. Instalar/actualizar SWAL skills ────────────────────────
info "Configurando SWAL skills..."

# Skills críticos para SWAL Node
SWAL_SKILLS=(
    "terraform,pulumi,aws-cli,supabase,cloudflare-wrangler"
    "gcp,gestalt-swarm,jules,coding-agent,github"
)

# Directorio temporal para clonar skills
TEMP_SKILLS="/tmp/swal-skills-update"
rm -rf "$TEMP_SKILLS" 2>/dev/null || true

if git clone --depth 1 https://github.com/iberi22/swal-skills "$TEMP_SKILLS" 2>/dev/null; then
    # Copiar skills que no existan (NO sobreescribir)
    for skill in "$TEMP_SKILLS"/skills/*/; do
        skill_name=$(basename "$skill")
        dest="$SKILLS_DIR/$skill_name"
        if [[ -d "$dest" ]]; then
            # Skill existe — solo crear link si no existe
            if [[ ! -L "$dest/SKILL.md" ]] && [[ ! -f "$dest/SKILL.md" ]]; then
                cp "$skill/SKILL.md" "$dest/SKILL.md"
            fi
            info "  ✓ $skill_name (actualizado)"
        else
            # Skill nuevo — copiar completo
            mkdir -p "$dest"
            cp -r "$skill"/* "$dest/"
            info "  + $skill_name (nuevo)"
        fi
    done
    rm -rf "$TEMP_SKILLS"
    success "SWAL skills actualizados"
else
    warn "No se pudo actualizar skills (git clone falló)"
fi

# ── 6. Configurar permissions para bot ───────────────────────
info "Configurando permisos de ejecución..."

# Permisos para zeroclaw
if command -v zeroclaw &>/dev/null; then
    chmod +x "$(which zeroclaw)" 2>/dev/null || true
fi

# Asegurar que los scripts en workspace tengan permisos
if [[ -d "$WORKSPACE_DIR" ]]; then
    find "$WORKSPACE_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$WORKSPACE_DIR" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
fi

# ── 7. Configurar environment file (si no existe) ─────────────
ENV_FILE="$OPENCLAW_DIR/secrets.env"
if [[ ! -f "$ENV_FILE" ]]; then
    info "Creando secrets.env (vacío)..."
    cat > "$ENV_FILE" << 'EOF'
# ZeroClaw Environment Variables
# Completa con tus API keys

# GROQ (transcripción audio)
# GROQ_API_KEY=

# Gemini
# GEMINI_API_KEY=

# MiniMax
# MINIMAX_API_KEY=

# Cortex
# CORTEX_TOKEN=dev-token
# CORTEX_URL=http://localhost:8003

# ZeroClaw
# ZEROCLAW_API_KEY=
EOF
    warn "Edita $ENV_FILE con tus API keys"
else
    info "secrets.env ya existe — no se modifica"
fi

# ── 8. Verificar archivos críticos de workspace ────────────────
info "Verificando workspace..."
for file in SOUL.md AGENTS.md USER.md MEMORY.md; do
    if [[ -f "$WORKSPACE_DIR/$file" ]]; then
        info "  ✓ $file"
    else
        warn "  ✗ $file — crear desde template"
        # Copiar desde swal-skills si existe
        if [[ -d "$TEMP_SKILLS" ]]; then
            if [[ -f "$TEMP_SKILLS/templates/$file" ]]; then
                cp "$TEMP_SKILLS/templates/$file" "$WORKSPACE_DIR/$file"
            fi
        fi
    fi
done

# ── 9. Verificar que Node.js pueda compilar ──────────────────
info "Verificando Node.js..."
node --version
npm --version

# Test: npm install un paquete pequeño para verificar
if npm install -g --silent jsome 2>/dev/null; then
    success "npm funciona correctamente"
else
    warn "npm tiene problemas — intenta: pkg fix"
fi

# ── 10. Resumen ───────────────────────────────────────────────
info "=============================================="
success "  Setup completado!"
info "=============================================="
info "Próximos pasos:"
info "  1. Editar $ENV_FILE con tus API keys"
info "  2. Reiniciar session de Termux (exit + enter)"
info "  3. Ejecutar: zeroclaw daemon"
info ""
info "Skills instalados:"
ls -la "$SKILLS_DIR/" 2>/dev/null | head -20
info "=============================================="