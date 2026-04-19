#!/bin/bash
# =============================================================================
# ZeroClaw SWARM Node — Entrypoint
# =============================================================================
# Arranca el nodo ZeroClaw COMPARTIENDO el workspace de OpenClaw
# Ambos agentes leen/escriben los mismos MEMORY.md, SOUL.md, AGENTS.md, etc.
# =============================================================================
set -Eeuo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log() { printf "%b[ZEROCLAW]%b %s\n" "$1" "$NC" "$2"; }
info()    { log "$CYAN" "$@"; }
success() { log "$GREEN" "$@"; }
warn()    { log "$YELLOW" "$@"; }
error()   { log "$RED" "$@"; }

# ── Paths ─────────────────────────────────────────────────────────────────
WORKSPACE="${ZEROCLAW_WORKSPACE:-/zeroclaw/workspace}"
ZEROCLAW_CONFIG="${ZEROCLAW_CONFIG:-/zeroclaw/config.toml}"
SSH_DIR="/zeroclaw/ssh"
CORTEX_URL="${CORTEX_URL:-http://localhost:8003}"

info "=============================================="
info "  ZeroClaw SWARM Node"
info "  Workspace: $WORKSPACE"
info "=============================================="

# ── 1. Verificar workspace ────────────────────────────────────────────────
if [[ ! -d "$WORKSPACE" ]]; then
    error "Workspace no encontrado: $WORKSPACE"
    error "Verificar OPENCLAW_WORKSPACE en .env"
    exit 1
fi

# ── 2. Verificar archivos de OpenClaw ────────────────────────────────────
info "Verificando workspace de OpenClaw..."
for file in MEMORY.md SOUL.md AGENTS.md USER.md; do
    if [[ -f "$WORKSPACE/$file" ]]; then
        info "  ✓ $file"
    else
        warn "  ✗ $file (no encontrado)"
    fi
done

# ── 3. API Key ───────────────────────────────────────────────────────────
if [[ -z "${API_KEY:-}" ]]; then
    warn "API_KEY no configurada — modo limitado"
fi

# ── 4. SSH ───────────────────────────────────────────────────────────────
info "Configurando SSH..."
mkdir -p "$SSH_DIR"

if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
    ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_DIR/id_rsa" 2>/dev/null
    chmod 600 "$SSH_DIR/id_rsa"
    chmod 644 "$SSH_DIR/id_rsa.pub"
fi

# Authorized keys del nodo
touch "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"

info "SSH fingerprint:"
ssh-keygen -lf "$SSH_DIR/id_rsa" 2>/dev/null || true

# ── 5. Directorios ───────────────────────────────────────────────────────
mkdir -p "$WORKSPACE/memory"
mkdir -p "$WORKSPACE/skills"
mkdir -p "/zeroclaw/logs"

# ── 6. Config ZeroClaw ─────────────────────────────────────────────────
info "Escribiendo config ZeroClaw..."

cat > "$ZEROCLAW_CONFIG" << EOF
workspace_dir = "${WORKSPACE}"
config_path = "${ZEROCLAW_CONFIG}"

api_key = "${API_KEY:-}"
default_provider = "${PROVIDER:-openrouter}"
default_model = "${DEFAULT_MODEL:-anthropic/claude-sonnet-4-20250514}"
default_temperature = ${DEFAULT_TEMPERATURE:-0.7}

[gateway]
port = ${ZEROCLAW_GATEWAY_PORT:-42617}
host = "0.0.0.0"
allow_public_bind = false
require_pairing = false

[autonomy]
level = "full"
auto_approve = [
    "file_read", "file_write", "file_edit", "file_delete",
    "git_clone", "git_pull", "git_push", "git_commit",
    "shell_exec", "shell_install", "shell_update",
    "pkg_install", "pkg_update",
    "web_search", "web_fetch",
    "memory_recall", "memory_store",
    "cargo_build", "cargo_test", "cargo_run",
    "npm_install", "npm_run", "npm_build"
]

[tools]
enabled_all = true
allow_shell = true
allow_git = true
allow_file_write = true
allow_file_delete = true
allow_pkg_install = true
allow_network = true

[security]
allow_unsafe_commands = true
require_confirmation = false
log_all_commands = true
audit_file = "${WORKSPACE}/logs/audit.log"

[cortex]
enabled = ${CORTEX_ENABLED:-true}
url = "${CORTEX_URL}"
token = "${CORTEX_TOKEN:-dev-token}"

[gestalt]
enabled = ${GESTALT_ENABLED:-true}
swarm_path = "/usr/local/bin/gestalt_swarm"

[skills]
open_skills_enabled = true
skills_dir = "${WORKSPACE}/skills"
EOF

chmod 600 "$ZEROCLAW_CONFIG"

# ── 7. Iniciar SSH ──────────────────────────────────────────────────────
info "Iniciando SSH..."
/usr/sbin/sshd

# ── 8. Arrancar ZeroClaw ────────────────────────────────────────────────
info "=============================================="
info "  ZeroClaw SWARM — RUNNING"
info "=============================================="
info "Gateway: http://localhost:${ZEROCLAW_GATEWAY_PORT:-42617}"
info "SSH:    localhost:${SSH_PORT:-2222}"
info "=============================================="

exec zeroclaw daemon --config "$ZEROCLAW_CONFIG"
