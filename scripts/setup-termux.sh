#!/bin/bash
# ============================================================
# ZeroClaw SWAL Node — Termux Setup v3.1
# Interactive installer con diagnóstico y skills modulares
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
    else
        echo -e "${YELLOW}⚠ Linux/No-Termux${NC}"
    fi

    # Shell
    echo -n "  Shell: "
    echo -e "${GREEN}✓${NC} $SHELL"

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
        echo -e "  OpenClaw: ${RED}✗ no instalado${NC}"
    fi

    # ZeroClaw
    ((checks++))
    if command -v zeroclaw &>/dev/null; then
        echo -n "  ZeroClaw: "
        local zc_ver=$(zeroclaw --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓$zc_ver${NC}"
        ((passed++))
    else
        echo -e "  ZeroClaw: ${YELLOW}⚠ no instalado (opcional)${NC}"
    fi

    # Codex
    ((checks++))
    if command -v codex &>/dev/null; then
        echo -n "  Codex CLI: "
        echo -e "${GREEN}✓$(codex --version 2>/dev/null || echo 'installed')${NC}"
        ((passed++))
    else
        echo -e "  Codex CLI: ${YELLOW}⚠ no instalado${NC}"
    fi

    # Claude Code
    ((checks++))
    if command -v claude &>/dev/null; then
        echo -n "  Claude Code: "
        echo -e "${GREEN}✓$(claude --version 2>/dev/null || echo 'installed')${NC}"
        ((passed++))
    else
        echo -e "  Claude Code: ${YELLOW}⚠ no instalado${NC}"
    fi

    # OpenCode
    ((checks++))
    if command -v opencode &>/dev/null; then
        echo -n "  OpenCode CLI: "
        echo -e "${GREEN}✓$(opencode --version 2>/dev/null || echo 'installed')${NC}"
        ((passed++))
    else
        echo -e "  OpenCode CLI: ${YELLOW}⚠ no instalado${NC}"
    fi

    # Workspace
    ((checks++))
    if [[ -d "$WORKSPACE_DIR" ]]; then
        echo -n "  Workspace: "
        local files=$(find "$WORKSPACE_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ ($files archivos .md)${NC}"
        ((passed++))
    else
        echo -e "  Workspace: ${YELLOW}⚠ no existe${NC}"
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
    echo -n "  GROQ_API_KEY: "
    if [[ -n "${GROQ_API_KEY:-}" ]]; then
        echo -e "${GREEN}✓ configurada${NC}"
    else
        echo -e "${YELLOW}⚠ no configurada${NC}"
    fi

    echo ""
    log "$CYAN" "  Resultado: $passed/$checks checks passaram"
    echo ""
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
    echo "  [S] Solo instalar skills (sin paquetes de sistema)"
    echo ""
    echo -n "  Tu selección (ej: 1,2,C,L,O): "
}

# ============================================================
# INSTALAR CODEX CLI
# ============================================================
install_codex() {
    if ! command -v npm &>/dev/null; then
        warn "npm no disponible — no se puede instalar Codex CLI"
        return
    fi

    echo -n "  Codex CLI (@openai/codex)... "
    if npm install -g @openai/codex 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        success "Codex CLI instalado!"
        echo "    Usa: codex --help"
    else
        echo -e "${YELLOW}⚠ falló${NC}"
    fi
}

# ============================================================
# INSTALAR CLAUDE CODE CLI
# ============================================================
install_claude_code() {
    if ! command -v npm &>/dev/null; then
        warn "npm no disponible — no se puede instalar Claude Code CLI"
        return
    fi

    echo -n "  Claude Code (@anthropic/claude-code)... "
    if npm install -g @anthropic/claude-code 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        success "Claude Code CLI instalado!"
        echo "    Usa: claude --help"
    else
        echo -e "${YELLOW}⚠ falló${NC}"
    fi
}

# ============================================================
# INSTALAR OPENCODE CLI
# ============================================================
install_opencode() {
    if ! command -v npm &>/dev/null; then
        warn "npm no disponible — no se puede instalar OpenCode CLI"
        return
    fi

    echo -n "  OpenCode CLI... "
    if npm install -g opencode 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        success "OpenCode CLI instalado!"
        echo "    Usa: opencode --help"
    else
        echo -n "  OpenCode (@minimax/opencode)... "
        if npm install -g @minimax/opencode 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            success "OpenCode CLI (@minimax/opencode) instalado!"
        else
            echo -e "${YELLOW}⚠ falló${NC}"
        fi
    fi
}

# ============================================================
# INSTALAR PAQUETES DE SISTEMA
# ============================================================
install_packages() {
    local selection="$1"
    local pkg_install=""

    if [[ "$selection" == "S" ]]; then
        info "Saltando instalación de paquetes de sistema..."
        return
    fi

    info "Actualizando packages de Termux..."
    pkg update -y 2>/dev/null || true

    # Paquetes base siempre necesarios
    local base_pkgs="git curl wget openssl openssh termux-api vim nano htop clang make cmake ninja"

    if [[ "$selection" == "A" ]]; then
        # Todos los paquetes
        pkg_install="$base_pkgs python pip nodejs npm ruby openjdk-17 dart"
    else
        # Selección individual
        local choices=$(echo "$selection" | tr ',' '\n')

        # Siempre base
        pkg_install="$base_pkgs"

        echo "$choices" | while read -r choice; do
            case "$choice" in
                1) pkg_install="$pkg_install python pip" ;;
                2) pkg_install="$pkg_install nodejs npm" ;;
                3) pkg_install="$pkg_install golang" ;;
                4) pkg_install="$pkg_install rust" ;;
                5) pkg_install="$pkg_install php composer" ;;
                6) pkg_install="$pkg_install ruby" ;;
                7) pkg_install="$pkg_install openjdk-17" ;;
                8) pkg_install="$pkg_install dart" ;;
                C|c) install_codex ;;
                L|l) install_claude_code ;;
                O|o) install_opencode ;;
            esac
        done
    fi

    #Instalar paquetes de sistema (sin duplicados)
    local unique_pkgs=$(echo "$pkg_install" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    if [[ -n "$unique_pkgs" ]]; then
        info "Instalando paquetes de sistema: $unique_pkgs"
        for pkg in $unique_pkgs; do
            echo -n "  $pkg... "
            if pkg install -y "$pkg" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}⚠${NC}"
            fi
        done
    fi

    # Coding agents via npm (si seleccionados y no instalados)
    if echo ",$selection," | grep -q ",C," && ! command -v codex &>/dev/null; then
        install_codex
    fi
    if echo ",$selection," | grep -q ",L," && ! command -v claude &>/dev/null; then
        install_claude_code
    fi
    if echo ",$selection," | grep -q ",O," && ! command -v opencode &>/dev/null; then
        install_opencode
    fi
}

# ============================================================
# INSTALAR PYTHON TOOLS
# ============================================================
install_python_tools() {
    if ! command -v pip3 &>/dev/null; then
        warn "pip3 no disponible — saltando Python tools"
        return
    fi

    info "Instalando Python tools..."
    pip3 install --break-system-packages --quiet \
        fastapi uvicorn pydantic requests httpx aiohttp \
        langchain langchain-community openai anthropic groq \
        pandas numpy matplotlib jupyter ipython \
        black ruff mypy pytest pytest-asyncio \
        python-dotenv pyyaml rich typer click \
        sqlalchemy redis beautifulsoup4 pillow scikit-learn \
        2>/dev/null || true
    success "Python tools instalados"
}

# ============================================================
# INSTALAR NODE TOOLS
# ============================================================
install_node_tools() {
    if ! command -v npm &>/dev/null; then
        warn "npm no disponible — saltando Node tools"
        return
    fi

    info "Instalando Node tools globalmente..."

    # openclaw siempre
    if ! command -v openclaw &>/dev/null; then
        echo -n "  openclaw... "
        if npm install -g openclaw 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}⚠ falló${NC}"
        fi
    fi

    # wrangler para Cloudflare
    echo -n "  wrangler... "
    if npm install -g wrangler 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ falló${NC}"
    fi

    # TypeScript y ts-node
    echo -n "  typescript + ts-node... "
    if npm install -g typescript ts-node 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ falló${NC}"
    fi

    # pnpm
    echo -n "  pnpm... "
    if npm install -g pnpm 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ falló${NC}"
    fi

    # yarn
    echo -n "  yarn... "
    if npm install -g yarn 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ falló${NC}"
    fi

    success "Node tools instalados"
}

# ============================================================
# INSTALAR SKILLS MODULARES
# ============================================================
install_skills() {
    local selection="$1"
    local TEMP_SKILLS="/tmp/swal-skills-tmp"

    info "Clonando swal-skills..."
    rm -rf "$TEMP_SKILLS" 2>/dev/null || true

    if ! git clone --depth 1 https://github.com/iberi22/swal-skills "$TEMP_SKILLS" 2>/dev/null; then
        error "No se pudo clonar swal-skills"
        return
    fi

    # Crear dirs
    mkdir -p "$SKILLS_DIR" 2>/dev/null || true
    mkdir -p "$WORKSPACE_DIR" 2>/dev/null || true

    # Función para instalar un skill
    install_skill() {
        local skill_name="$1"
        local skill_path="$TEMP_SKILLS/skills/$skill_name"
        local dest="$SKILLS_DIR/$skill_name"

        if [[ ! -d "$skill_path" ]]; then
            return
        fi

        if [[ -d "$dest" ]]; then
            # Ya existe — solo actualizar SKILL.md
            cp -f "$skill_path/SKILL.md" "$dest/SKILL.md" 2>/dev/null || true
            echo -e "  ${CYAN}↻${NC} $skill_name (actualizado)"
        else
            # Nuevo — copiar todo
            mkdir -p "$dest"
            cp -r "$skill_path"/* "$dest/"
            echo -e "  ${GREEN}+${NC} $skill_name (nuevo)"
        fi
    }

    echo ""
    info "Instalando skills según paquetes seleccionados..."
    echo ""

    # Skills BASE — siempre
    install_skill "openclaw"
    install_skill "github"
    install_skill "coding-agent"

    # Skills según paquetes seleccionados
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",1," ]]; then
        install_skill "python"
        install_skill "jupyter"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",2," ]]; then
        install_skill "nodejs"
        install_skill "typescript"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",3," ]]; then
        install_skill "golang"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",4," ]]; then
        install_skill "rust"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",5," ]]; then
        install_skill "php"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",6," ]]; then
        install_skill "ruby"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",7," ]]; then
        install_skill "java"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",8," ]]; then
        install_skill "flutter"
    fi

    # Coding agents CLI skills
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",[Cc]," ]]; then
        install_skill "codex"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",[Ll]," ]]; then
        install_skill "claude-code"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",[Oo]," ]]; then
        install_skill "opencode-dev-workflow"
        install_skill "subagent-launcher"
    fi
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",[Jj]," ]]; then
        install_skill "jules"
    fi

    # Skills IaC/Infrastructure — siempre básicos
    install_skill "terraform"
    install_skill "pulumi"
    install_skill "aws-cli"
    install_skill "supabase"
    install_skill "cloudflare-wrangler"
    install_skill "gcp"

    # Skills Swarm
    install_skill "gestalt-swarm"
    install_skill "skill-launcher"

    # Skills de inteligencia — siempre
    install_skill "browser-automation"
    install_skill "web-research"
    install_skill "brave-search"

    # SWAL Node overview
    install_skill "SWAL-node-overview"

    # Limpiar
    rm -rf "$TEMP_SKILLS"

    echo ""
    success "Skills instalados!"

    # Listar skills instalados
    info "Skills en $SKILLS_DIR:"
    ls -la "$SKILLS_DIR/" 2>/dev/null | grep "^d" | awk '{print "  " $NF}' | grep -v "^\.$" | head -30
}

# ============================================================
# VERIFICAR WORKSPACE
# ============================================================
verify_workspace() {
    info "Verificando workspace..."
    mkdir -p "$WORKSPACE_DIR/memory" 2>/dev/null || true
    mkdir -p "$WORKSPACE_DIR/skills" 2>/dev/null || true

    local critical_files="SOUL.md AGENTS.md USER.md MEMORY.md HEARTBEAT.md IDENTITY.md TOOLS.md"
    local all_ok=true

    for file in $critical_files; do
        if [[ -f "$WORKSPACE_DIR/$file" ]]; then
            echo -e "  ${GREEN}✓${NC} $file"
        else
            echo -e "  ${YELLOW}⚠${NC} $file (falta)"
            all_ok=false
        fi
    done

    if [[ "$all_ok" == "false" ]]; then
        warn "Algunos archivos críticos faltan."
    fi
}

# ============================================================
# CONFIGURAR PERMISOS
# ============================================================
setup_permissions() {
    info "Configurando permisos..."

    for bin in zeroclaw openclaw codex claude opencode; do
        if command -v $bin &>/dev/null; then
            chmod +x "$(which $bin)" 2>/dev/null || true
            echo -e "  ${GREEN}✓${NC} $bin"
        fi
    done

    if [[ -d "$WORKSPACE_DIR" ]]; then
        find "$WORKSPACE_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        find "$WORKSPACE_DIR" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} scripts en workspace"
    fi

    success "Permisos configurados"
}

# ============================================================
# GENERATE SECRETS.ENV
# ============================================================
setup_secrets() {
    if [[ -f "$ENV_FILE" ]] && [[ -s "$ENV_FILE" ]]; then
        info "secrets.env ya existe — no se modifica"
        return
    fi

    info "Creando $ENV_FILE..."
    cat > "$ENV_FILE" << 'EOF'
# ============================================================
# ZeroClaw SWAL Node — Environment Variables
# ============================================================

# GROQ API (transcripción de audio)
# GROQ_API_KEY=gsak_...

# Gemini API
# GEMINI_API_KEY=

# MiniMax API
# MINIMAX_API_KEY=

# Cortex (memoria central)
# CORTEX_TOKEN=dev-token
# CORTEX_URL=http://localhost:8003

# ZeroClaw
# ZEROCLAW_API_KEY=

# Coding agents
# ANTHROPIC_API_KEY=   # Para Claude Code CLI
# OPENAI_API_KEY=       # Para Codex CLI

# Proveedor default
# DEFAULT_PROVIDER=groq
# DEFAULT_MODEL=minimax/MiniMax-M2.7

# Telegram (ZeroClaw bot)
# TELEGRAM_BOT_TOKEN=
# TELEGRAM_ALLOWED_USER_IDS=2076598024,5885831693

# Workspace
# ZEROCLAW_WORKSPACE=/data/data/com.termux/files/home/zeroclaw-workspace
EOF

    warn "Edita $ENV_FILE con tus API keys!"
}

# ============================================================
# MAIN
# ============================================================
main() {
    echo ""
    log "$GREEN" "═══════════════════════════════════════════════════════"
    log "$GREEN" "  ZeroClaw SWAL Node — Termux Setup v3.1"
    log "$GREEN" "═══════════════════════════════════════════════════════"

    # 1. Diagnóstico
    diagnose

    # 2. Menú
    show_menu
    read -r selection

    echo ""

    # 3. Instalar paquetes (sistema + coding agents)
    install_packages "$selection"

    # 4. Python tools
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",1," ]]; then
        install_python_tools
    fi

    # 5. Node tools
    if [[ "$selection" == "A" ]] || echo ",$selection," | grep -q ",2," ]]; then
        install_node_tools
    fi

    # 6. Instalar skills modulares
    install_skills "$selection"

    # 7. Verificar workspace
    verify_workspace

    # 8. Permisos
    setup_permissions

    # 9. Secrets
    setup_secrets

    # 10. Resumen
    echo ""
    log "$GREEN" "═══════════════════════════════════════════════════════"
    success "  SETUP COMPLETADO!"
    log "$GREEN" "═══════════════════════════════════════════════════════"
    echo ""
    info "Resumen de instalación:"
    echo "  - Selección: $selection"
    echo "  - Workspace: $WORKSPACE_DIR"
    echo "  - Skills: $SKILLS_DIR"
    echo ""
    info "Coding agents instalados:"
    command -v codex &>/dev/null && echo "  ${GREEN}✓${NC} Codex CLI (@openai/codex)" || true
    command -v claude &>/dev/null && echo "  ${GREEN}✓${NC} Claude Code CLI (@anthropic/claude-code)" || true
    command -v opencode &>/dev/null && echo "  ${GREEN}✓${NC} OpenCode CLI" || true
    echo ""
    info "Próximos pasos:"
    echo "  1. Edita $ENV_FILE con tus API keys"
    echo "  2. Ejecuta: termux-reload-settings"
    echo "  3. Reinicia sesión: exit (y vuelve a entrar)"
    echo "  4. Inicia: zeroclaw daemon"
    echo ""
}

main "$@"