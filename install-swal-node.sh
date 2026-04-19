#!/bin/bash
# =============================================================================
# ZeroClaw SWAL Node — Termux Full Setup
# =============================================================================
# Script completo para Termux/Android con TODAS las tools de desarrollo
# ZeroClaw + Gestalt + Environment completo
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/main/install-swal-node.sh | bash
#
# O localmente:
#   bash install-swal-node.sh
#
# Con agentes opcionales:
#   SWAL_INSTALL_ALL=1 bash install-swal-node.sh
#   SWAL_INSTALL_JULES=1 bash install-swal-node.sh
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="install-swal-node.sh"
readonly SCRIPT_VERSION="2026-04-19.2"
readonly INSTALL_DIR="$HOME/zeroclaw-swal"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'

LOG_FILE="$INSTALL_DIR/install.log"
SCRIPT_START_TS=$(date +%s)

# ── Flags de instalación opcional ──────────────────────────────────────────────
INSTALL_ALL="${SWAL_INSTALL_ALL:-0}"
is_enabled() {
    [[ "$INSTALL_ALL" == "1" ]] && return 0
    local var="SWAL_INSTALL_${1}"
    [[ "${!var}" == "1" ]] && return 0
    return 1
}

log() { printf "%b[SWAL]%b %s\n" "$1" "$NC" "$*"; [[ -d "$INSTALL_DIR" ]] && echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }
info()    { log "$CYAN" "INFO" "$@"; }
success() { log "$GREEN" "OK" "$@"; }
warn()    { log "$YELLOW" "WARN" "$@"; }
error()   { log "$RED" "ERROR" "$@"; }

cleanup() {
    local exit_code=$?
    local elapsed=$(($(date +%s) - SCRIPT_START_TS))
    if [[ $exit_code -eq 0 ]]; then
        success "Instalación completada en ${elapsed}s."
        show_next_steps
    else
        error "Instalación falló (code $exit_code) tras ${elapsed}s."
        [[ -f "$LOG_FILE" ]] && tail -20 "$LOG_FILE"
    fi
    exit $exit_code
}
trap cleanup EXIT

show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "============================================================"
    echo "  ZeroClaw SWAL Node — Full Setup v${SCRIPT_VERSION}"
    echo "  TODAS las tools + CLI agents opcionales"
    echo "============================================================"
    echo -e "${NC}\n"
}

# =============================================================================
# 1. VERIFICACIONES
# =============================================================================
check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        error "Este script debe ejecutarse en Termux."
        exit 1
    fi
    info "Termux detectado ✓"
}

# =============================================================================
# 2. PAQUETES BASE
# =============================================================================
install_base_packages() {
    info "Actualizando paquetes base..."
    pkg update -y 2>/dev/null || true

    local base_packages=(
        git curl wget tar unzip zip nano vim htop tree
        openssh netcat-openbsd dnsutils
        build-essential cmake ninja clang make autoconf automake libtool
        python python-pip
        nodejs npm
        golang
        sqlite
        jq bc findutils coreutils procps
        ruby
    )

    for pkg in "${base_packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null 2>&1; then
            info "Instalando ${pkg}..."
            pkg install -y "$pkg" 2>/dev/null || warn "No se pudo instalar ${pkg}"
        fi
    done
    success "Paquetes base instalados ✓"
}

# =============================================================================
# 3. PYTHON
# =============================================================================
install_python_packages() {
    info "Instalando Python packages..."

    pip install --upgrade pip 2>/dev/null || true

    pip install \
        requests httpx aiohttp \
        fastapi uvicorn pydantic \
        openai anthropic groq google-generativeai \
        langchain langchain-community \
        pandas numpy matplotlib jupyter ipython \
        black ruff mypy pytest pytest-asyncio \
        python-dotenv pyyaml toml \
        rich typer click questionary inquirer tabulate \
        beautifulsoup4 lxml \
        playwright selenium \
        flask quart \
        python-dotenv \
        2>/dev/null || warn "Algunos packages fallaron"

    success "Python packages instalados ✓"
}

# =============================================================================
# 4. NODE.JS
# =============================================================================
install_nodejs_packages() {
    info "Instalando Node.js globals..."

    if command -v npm &>/dev/null; then
        npm install -g \
            npm@latest pnpm yarn \
            typescript ts-node ts-node-dev @types/node \
            prettier eslint \
            dotenv-cli cross-env neovim \
            2>/dev/null || warn "Algunos npm packages fallaron"
    fi
    success "Node.js packages instalados ✓"
}

# =============================================================================
# 5. RUST + CARGO
# =============================================================================
install_rust() {
    info "Instalando Rust + Cargo..."

    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
            --default-toolchain stable \
            --profile default \
            --component rustfmt clippy rust-docs \
            2>/dev/null || {
                warn "Rust installation failed"
                return 0
            }
    fi

    export PATH="$HOME/.cargo/bin:$PATH"
    source "$HOME/.cargo/env" 2>/dev/null || true

    # Tools de Rust que usamos
    if command -v cargo &>/dev/null; then
        cargo install \
            cargo-edit cargo-watch cargo-expand cargo-tree \
            diesel_cli \
            2>/dev/null || warn "Some cargo tools failed"
    fi

    success "Rust + Cargo instalados ✓"
}

# =============================================================================
# 6. GO
# =============================================================================
install_go() {
    info "Instalando Go..."

    if ! command -v go &>/dev/null; then
        pkg install -y golang 2>/dev/null || true
    fi

    export GOPATH="$HOME/go"
    export PATH="$PATH:/usr/local/go/bin:$GOPATH/bin"
    mkdir -p "$GOPATH/bin"

    go install \
        github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
        github.com/swaggest/swag/cmd/swag@latest \
        github.com/rakyll/statik@latest \
        2>/dev/null || warn "Some Go packages failed"

    success "Go instalado ✓"
}

# =============================================================================
# 7. FLUTTER
# =============================================================================
install_flutter() {
    is_enabled "FLUTTER" || return 0
    info "Instalando Flutter SDK..."

    local flutter_dir="$HOME/flutter"
    if [[ ! -d "$flutter_dir" ]]; then
        git clone --depth 1 -b stable \
            https://github.com/flutter/flutter.git \
            "$flutter_dir" 2>/dev/null || {
            warn "Flutter clone failed"
            return 0
        }
    fi

    export PATH="$flutter_dir/bin:$PATH"
    export PUB_CACHE="$HOME/.pub-cache"
    flutter precache 2>/dev/null || true
    flutter config --enable-linux-desktop 2>/dev/null || true

    # Android SDK detection para Termux
    if [[ -d "/data/data/com.termux/files/usr/opt/android-sdk" ]]; then
        export ANDROID_SDK_ROOT="/data/data/com.termux/files/usr/opt/android-sdk"
        export PATH="$flutter_dir/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
    fi

    success "Flutter SDK instalado ✓"
}

# =============================================================================
# 8. PHP + COMPOSER
# =============================================================================
install_php() {
    is_enabled "PHP" || return 0
    info "Instalando PHP + Composer..."

    if ! command -v php &>/dev/null; then
        pkg install -y php php-cli php-mbstring php-xml php-curl php-json 2>/dev/null || true
    fi

    # Composer
    if ! command -v composer &>/dev/null; then
        curl -sS https://getcomposer.org/installer | php -- \
            --install-dir="$HOME/.local/bin" --filename=composer 2>/dev/null || \
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
        php composer-setup.php --install-dir="$HOME/.local/bin" --filename=composer && \
        rm composer-setup.php 2>/dev/null || warn "Composer install failed"
    fi

    success "PHP + Composer instalados ✓"
}

# =============================================================================
# 9. JULES (Google's Autonomous Coding Agent)
# =============================================================================
install_jules() {
    is_enabled "JULES" || return 0
    info "Instalando Jules CLI..."

    # Jules es el agente autónomo de Google para iberi22/*
    # Se activa via GitHub Issues con label `jules`
    # Docs: https://github.com/iberi22/jules

    local jules_dir="$HOME/.local/bin"
    mkdir -p "$jules_dir"

    # Jules se instala via npm o go
    # Opción 1: npm (si existe)
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/jules 2>/dev/null || true
    fi

    # Opción 2: script de instalación oficial
    if ! command -v jules &>/dev/null; then
        curl -fsSL https://raw.githubusercontent.com/anthropics/jules/main/install.sh 2>/dev/null | \
            bash -s -- --bin-dir "$jules_dir" 2>/dev/null || \
        curl -fsSL https://get.jules.ai | bash 2>/dev/null || \
            warn "Jules install failed — se puede instalar manualmente después"
    fi

    # Alias para Jules en proyectos SWAL
    cat >> "$HOME/.bashrc" << 'EOF'

# Jules — Autonomous coding agent para iberi22/*
alias jules-project='cd ~/zeroclaw-workspace/projects && jules'
alias jules-gestalt='cd ~/zeroclaw-workspace/projects/gestalt-rust && jules'
alias jules-claw='cd ~/zeroclaw-workspace/projects && jules --repo iberi22'
EOF

    success "Jules CLI instalado ✓"
}

# =============================================================================
# 10. CLAUDE CODE
# =============================================================================
install_claude_code() {
    is_enabled "CLAUDE_CODE" || return 0
    info "Instalando Claude Code..."

    # Claude Code de Anthropic
    if command -v npm &>/dev/null; then
        npm install -g @anthropic/claude-code 2>/dev/null || true
    fi

    #npm install -g @anthropic/claude-code

    # Auth con API key
    # export ANTHROPIC_API_KEY=sk-ant-...

    success "Claude Code instalado ✓"
}

# =============================================================================
# 11. OPENCODE / CODEX
# =============================================================================
install_opencode() {
    is_enabled "OPENCODE" || return 0
    info "Instalando OpenCode..."

    # OpenCode (Qwen/Coder) — coding agent
    if command -v npm &>/dev/null; then
        npm install -g opencode-cli 2>/dev/null || true
    fi

    # Alternativa: desde GitHub releases
    if ! command -v opencode &>/dev/null; then
        local opencode_bin="$HOME/.local/bin/opencode"
        curl -fsSL \
            https://github.com/sst/opencode/releases/latest/download/opencode-x86_64-unknown-linux-gnu \
            -o "$opencode_bin" 2>/dev/null && \
        chmod +x "$opencode_bin" || \
            warn "OpenCode install failed"
    fi

    success "OpenCode instalado ✓"
}

# =============================================================================
# 12. GEMINI CLI
# =============================================================================
install_gemini_cli() {
    is_enabled "GEMINI_CLI" || return 0
    info "Instalando Gemini CLI..."

    # Gemini CLI oficial de Google
    if command -v npm &>/dev/null; then
        npm install -g @google/gemini-cli 2>/dev/null || true
    fi

    # Auth
    # gemini auth login

    success "Gemini CLI instalado ✓"
}

# =============================================================================
# 13. QWEN CLI
# =============================================================================
install_qwen() {
    is_enabled "QWEN" || return 0
    info "Instalando Qwen CLI..."

    # Qwen coding agent de Alibaba
    if command -v npm &>/dev/null; then
        npm install -g @qwen/qwen-cli 2>/dev/null || true
    fi

    success "Qwen CLI instalado ✓"
}

# =============================================================================
# 14. SUPABASE CLI
# =============================================================================
install_supabase() {
    is_enabled "SUPABASE" || return 0
    info "Instalando Supabase CLI..."

    if ! command -v supabase &>/dev/null; then
        local version="1.165.0"
        curl -fsSL \
            "https://github.com/supabase/cli/releases/download/v${version}/supabase_${version}_linux_amd64.tar.gz" \
            -o /tmp/supabase.tar.gz 2>/dev/null && \
        tar -xzf /tmp/supabase.tar.gz -C /tmp 2>/dev/null && \
        mv /tmp/supabase "$HOME/.local/bin/" 2>/dev/null && \
        chmod +x "$HOME/.local/bin/supabase" || \
        # Fallback: npm
        npm install -g supabase 2>/dev/null || \
            warn "Supabase CLI install failed"
    fi

    # Login
    # supabase login

    success "Supabase CLI instalado ✓"
}

# =============================================================================
# 15. AWS CLI
# =============================================================================
install_aws() {
    is_enabled "AWS" || return 0
    info "Instalando AWS CLI..."

    if ! command -v aws &>/dev/null; then
        curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
            -o /tmp/awscliv2.zip 2>/dev/null && \
        unzip -q /tmp/awscliv2.zip -d /tmp 2>/dev/null && \
        /tmp/aws/install 2>/dev/null || \
        pkg install -y amazon-ec2-ami-tools 2>/dev/null || \
        npm install -g aws-cli 2>/dev/null || \
            warn "AWS CLI install failed"
    fi

    # Config
    # aws configure

    success "AWS CLI instalado ✓"
}

# =============================================================================
# 16. GCP CLI (gcloud)
# =============================================================================
install_gcp() {
    is_enabled "GCP" || return 0
    info "Instalando Google Cloud CLI..."

    if ! command -v gcloud &>/dev/null; then
        if command -v apt-get &>/dev/null; then
            # Instalar desde repos de Google
            apt-get install -y google-cloud-sdk 2>/dev/null || \
            # Instalar desde script oficial
            curl -fsSL https://sdk.cloud.google.com | bash -s -- \
                --disable-prompts \
                --install-dir="$HOME/google-cloud-sdk" 2>/dev/null || \
                warn "GCP CLI install failed"
        fi
    fi

    # Alias y path
    [[ -d "$HOME/google-cloud-sdk" ]] && \
        export PATH="$HOME/google-cloud-sdk/bin:$PATH"

    # Auth
    # gcloud auth login

    success "GCP CLI (gcloud) instalado ✓"
}

# =============================================================================
# 17. CLOUDFLARE WRANGLER CLI
# =============================================================================
install_cloudflare() {
    is_enabled "CLOUDFLARE" || return 0
    info "Instalando Cloudflare Wrangler CLI..."

    if command -v npm &>/dev/null; then
        npm install -g wrangler 2>/dev/null || true
    fi

    # Wrangler (Workers, Pages, D1, R2, etc.)
    if ! command -v wrangler &>/dev/null; then
        curl -fsSL https://pkg.cloudflare.com/wrangler/releases/linux/x86_64/wrangler-*.tar.gz \
            -o /tmp/wrangler.tar.gz 2>/dev/null || \
        npm install -g wrangler 2>/dev/null || \
            warn "Cloudflare Wrangler install failed"
    fi

    # Auth
    # wrangler login

    success "Cloudflare Wrangler CLI instalado ✓"
}

# =============================================================================
# 18. TERRAFORM
# =============================================================================
install_terraform() {
    is_enabled "TERRAFORM" || return 0
    info "Instalando Terraform..."

    if ! command -v terraform &>/dev/null; then
        local version="1.6.0"
        curl -fsSL \
            "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip" \
            -o /tmp/terraform.zip 2>/dev/null && \
        unzip -q /tmp/terraform.zip -d /tmp 2>/dev/null && \
        mv /tmp/terraform "$HOME/.local/bin/" 2>/dev/null && \
        chmod +x "$HOME/.local/bin/terraform" || \
            warn "Terraform install failed"
    fi

    # Providers comunes
    # terraform init

    success "Terraform instalado ✓"
}

# =============================================================================
# 19. PULUMI
# =============================================================================
install_pulumi() {
    is_enabled "PULUMI" || return 0
    info "Instalando Pulumi..."

    if ! command -v pulumi &>/dev/null; then
        curl -fsSL https://get.pulumi.com | bash -s -- \
            --version 3.88.0 2>/dev/null || \
        npm install -g pulumi 2>/dev/null || \
            warn "Pulumi install failed"
    fi

    # Auth
    # pulumi login

    success "Pulumi instalado ✓"
}

# =============================================================================
# 20. BUN
# =============================================================================
install_bun() {
    is_enabled "BUN" || return 0
    info "Instalando Bun..."

    if ! command -v bun &>/dev/null; then
        curl -fsSL https://bun.sh/install | bash 2>/dev/null || \
        npm install -g bun 2>/dev/null || \
            warn "Bun install failed"
    fi

    success "Bun instalado ✓"
}

# =============================================================================
# 21. DENO
# =============================================================================
install_deno() {
    is_enabled "DENO" || return 0
    info "Instalando Deno..."

    if ! command -v deno &>/dev/null; then
        curl -fsSL https://deno.land/install.sh | sh 2>/dev/null || \
        npm install -g deno 2>/dev/null || \
            warn "Deno install failed"
    fi

    success "Deno instalado ✓"
}

# =============================================================================
# 22. GIT CONFIG
# =============================================================================
setup_git() {
    info "Configurando Git..."
    cat > "$HOME/.gitconfig" << 'EOF'
[user]
    name = SWAL Agent
    email = agent@swal.local
[core]
    editor = nano
    autocrlf = input
[pull]
    rebase = false
[init]
    defaultBranch = main
[alias]
    co = checkout
    br = branch
    ci = commit
    st = status
    lg = log --oneline --graph --decorate
[fetch]
    prune = true
[push]
    default = simple
EOF
    success "Git configurado ✓"
}

# =============================================================================
# 23. ZSH + OH MY ZSH
# =============================================================================
install_zsh() {
    info "Configurando Zsh + Oh My Zsh..."

    if ! command -v zsh &>/dev/null; then
        pkg install -y zsh 2>/dev/null || true
    fi

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh 2>/dev/null | \
            sh -s -- --unattended 2>/dev/null || true
    fi

    # Plugins
    mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]] && \
            git clone --depth 1 \
                "https://github.com/zsh-users/$plugin" \
                "$HOME/.oh-my-zsh/custom/plugins/$plugin" 2>/dev/null || true
    done

    cat > "$HOME/.zshrc" << 'EOF'
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export EDITOR=nano
export RUST_BACKTRACE=1
export GOPATH=$HOME/go
export NVM_DIR="$HOME/.nvm"

# Aliases
alias sw='cd $HOME/zeroclaw-swal'
alias projects='cd $HOME/zeroclaw-workspace/projects'
alias gs='git status'
alias za='zeroclaw agent'
alias zd='zeroclaw daemon'
alias gg='gestalt_swarm'

ZSH_THEME="robbyrussell"
plugins=(git docker node npm rust python docker-compose)
source $ZSH/oh-my-zsh.sh
EOF

    success "Zsh configurado ✓"
}

# =============================================================================
# 24. SSH
# =============================================================================
setup_ssh() {
    info "Configurando SSH..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    [[ ! -f "$HOME/.ssh/id_rsa" ]] && \
        ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa" 2>/dev/null || true

    mkdir -p "$PREFIX/var/run"
    cat > "$PREFIX/etc/ssh/sshd_config" << 'EOF'
Port 8022
AuthorizedKeysFile %h/.ssh/authorized_keys
PasswordAuthentication no
PermitRootLogin yes
UseDNS no
EOF

    echo ""
    info "SSH listo — Puerto 8022"
    [[ -f "$HOME/.ssh/id_rsa.pub" ]] && cat "$HOME/.ssh/id_rsa.pub"
    echo ""

    success "SSH configurado ✓"
}

# =============================================================================
# 25. ZERO CLAW
# =============================================================================
install_zeroclaw() {
    info "Instalando ZeroClaw..."

    mkdir -p "$HOME/zeroclaw-swal"
    cd "$HOME/zeroclaw-swal"

    if [[ ! -d ".git" ]]; then
        git clone --depth 1 \
            https://github.com/iberi22/zeroclaw-termux-dev-setup.git \
            . 2>/dev/null || \
        git clone --depth 1 \
            https://github.com/zeroclaw-labs/zeroclaw.git \
            . 2>/dev/null || {
            error "No se pudo clonar ZeroClaw"
            return 1
        }
    fi

    export CARGO_BUILD_JOBS=2
    export RUSTFLAGS="-C codegen-units=1"

    info "Compilando ZeroClaw (10-30 min)..."
    RUST_LOG=info cargo build --release --locked \
        --features "channel-nostr" 2>&1 | tee -a "$LOG_FILE" || {
        error "ZeroClaw build failed"
        return 1
    }

    mkdir -p "$HOME/.local/bin"
    cp target/release/zeroclaw "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/zeroclaw"

    success "ZeroClaw instalado ✓"
}

# =============================================================================
# 26. GESTALT SWARM
# =============================================================================
install_gestalt() {
    info "Instalando Gestalt Swarm..."

    [[ ! -d "$HOME/gestalt-rust/.git" ]] && \
        git clone --depth 1 \
            https://github.com/iberi22/gestalt-rust.git \
            "$HOME/gestalt-rust" 2>/dev/null || return 0

    cd "$HOME/gestalt-rust"
    export CARGO_BUILD_JOBS=2

    if cargo build --release -p gestalt_swarm 2>&1 | tee -a "$LOG_FILE"; then
        cp target/release/gestalt_swarm "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/gestalt_swarm"
        success "Gestalt Swarm instalado ✓"
    else
        warn "Gestalt Swarm build failed"
    fi
}

# =============================================================================
# 27. WORKSPACE + PROYECTOS
# =============================================================================
setup_workspace() {
    info "Configurando workspace..."
    mkdir -p "$HOME/zeroclaw-workspace"/{projects,skills,memory,logs}

    declare -a SWAL_PROJECTS=(
        "https://github.com/iberi22/gestalt-rust.git"
        "https://github.com/iberi22/swal-skills.git"
        "https://github.com/iberi22/termux-dev-nvim-agents.git"
        "https://github.com/iberi22/isar_agent_memory.git"
        "https://github.com/iberi22/agents-flows-recipes.git"
    )

    for repo in "${SWAL_PROJECTS[@]}"; do
        local reponame=$(basename "$repo" .git)
        [[ ! -d "$HOME/zeroclaw-workspace/projects/$reponame/.git" ]] && \
            git clone --depth 1 "$repo" \
                "$HOME/zeroclaw-workspace/projects/$reponame" 2>/dev/null || \
            warn "No se pudo clonar $reponame"
    done

    success "Workspace listo ✓"
}

# =============================================================================
# 28. CONFIG ZERO CLAW
# =============================================================================
setup_zeroclaw_config() {
    info "Configurando ZeroClaw..."

    mkdir -p "$HOME/.zeroclaw"

    cat > "$HOME/.zeroclaw/config.toml" << EOF
workspace_dir = "${HOME}/zeroclaw-workspace"
config_path = "${HOME}/.zeroclaw/config.toml"

api_key = "${API_KEY:-}"
default_provider = "${PROVIDER:-openrouter}"
default_model = "${MODEL:-anthropic/claude-sonnet-4-20250514}"
default_temperature = 0.7

[gateway]
port = 42617
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

[cortex]
enabled = true
url = "http://localhost:8003"
token = "dev-token"

[gestalt]
enabled = true
swarm_path = "${HOME}/.local/bin/gestalt_swarm"

[skills]
open_skills_enabled = true
skills_dir = "${HOME}/zeroclaw-workspace/skills"
EOF

    cat > "$HOME/.zeroclaw/secrets.env" << EOF
API_KEY=${API_KEY:-}
GROQ_API_KEY=${GROQ_API_KEY:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
EOF
    chmod 600 "$HOME/.zeroclaw/secrets.env"

    success "ZeroClaw configurado ✓"
}

# =============================================================================
# 29. AUTOSTART
# =============================================================================
setup_autostart() {
    info "Configurando autostart..."

    cat > "$HOME/.local/bin/swalservice" << 'EOF'
#!/bin/bash
case "${1:-start}" in
    start)
        echo "[SWAL] Iniciando ZeroClaw..."
        export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
        cd "$HOME/zeroclaw-swal"
        nohup zeroclaw daemon > "$HOME/zeroclaw-workspace/logs/zeroclaw.log" 2>&1 &
        echo $! > "$HOME/zeroclaw-workspace/logs/zeroclaw.pid"
        ;;
    stop)
        [[ -f "$HOME/zeroclaw-workspace/logs/zeroclaw.pid" ]] && \
            kill $(cat "$HOME/zeroclaw-workspace/logs/zeroclaw.pid") 2>/dev/null
        ;;
    restart) swalservice stop; sleep 2; swalservice start ;;
    status)
        if [[ -f "$HOME/zeroclaw-workspace/logs/zeroclaw.pid" ]]; then
            kill -0 $(cat "$HOME/zeroclaw-workspace/logs/zeroclaw.pid") 2>/dev/null && \
                echo "Corriendo" || echo "No corriendo"
        else echo "No corriendo"; fi
        ;;
esac
EOF
    chmod +x "$HOME/.local/bin/swalservice"

    mkdir -p "$HOME/.termux/boot"
    cat > "$HOME/.termux/boot/swalservice" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
sleep 30
$HOME/.local/bin/swalservice start
EOF
    chmod +x "$HOME/.termux/boot/swalservice"

    success "Autostart configurado ✓"
}

# =============================================================================
# 30. VALIDACIÓN
# =============================================================================
validate() {
    info "Validando instalación..."

    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    local errors=0

    for cmd in git curl wget tar python node npm go cargo sqlite nano vim htop jq; do
        if command -v "$cmd" &>/dev/null; then
            success "  ✓ $cmd"
        else
            warn "  ✗ $cmd"
            ((errors++))
        fi
    done

    # Agentes opcionales (solo verificar si se instalaron)
    for agent in jules claude opencode bun deno; do
        if command -v "$agent" &>/dev/null; then
            success "  ✓ $agent"
        fi
    done

    # CLIs opcionales
    for cli in aws gcloud wrangler terraform pulumi supabase; do
        if command -v "$cli" &>/dev/null; then
            success "  ✓ $cli"
        fi
    done

    # ZeroClaw
    if command -v zeroclaw &>/dev/null; then
        success "ZeroClaw: ✓"
    else
        error "ZeroClaw: ✗"
        ((errors++))
    fi

    # Gestalt
    if command -v gestalt_swarm &>/dev/null; then
        success "Gestalt Swarm: ✓"
    fi

    # Workspace
    [[ -d "$HOME/zeroclaw-workspace" ]] && \
        success "Workspace: ✓"

    [[ $errors -eq 0 ]] && success "Validación OK ✓" || warn "$errors errores"
}

# =============================================================================
# PRÓXIMOS PASOS
# =============================================================================
show_next_steps() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  ¡Instalación SWAL Node COMPLETA!${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}CLI Agents instalados:${NC}"
    echo "    ZeroClaw, Gestalt Swarm, Jules, Claude Code,"
    echo "    OpenCode, Gemini CLI, Qwen, Bun, Deno"
    echo ""
    echo -e "  ${YELLOW}Infrastructure CLIs:${NC}"
    echo "    Supabase, AWS, GCP (gcloud),"
    echo "    Cloudflare Wrangler, Terraform, Pulumi"
    echo ""
    echo -e "  ${YELLOW}Development:${NC}"
    echo "    Python, Node.js, Go, Rust/Cargo,"
    echo "    Flutter, PHP/Composer, CMake, Ninja, Clang"
    echo ""
    echo -e "  ${YELLOW}Configurar API keys:${NC}"
    echo "    nano ~/.zeroclaw/secrets.env"
    echo ""
    echo -e "  ${YELLOW}Iniciar agente:${NC}"
    echo "    swalservice start"
    echo "    zeroclaw daemon"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    show_banner

    echo -e "${YELLOW}Instalando TODAS las tools de desarrollo...${NC}"
    echo ""
    echo -e "${CYAN}Agentes CLI:${NC} ZeroClaw, Gestalt, Jules, Claude Code, OpenCode, Gemini, Qwen"
    echo -e "${CYAN}Infra CLI:${NC}  Supabase, AWS, GCP, Cloudflare, Terraform, Pulumi"
    echo -e "${CYAN}Dev:${NC}         Python, Node, Go, Rust, Flutter, PHP, CMake, Ninja"
    echo ""
    echo -e "Con agentes opcionales: ${GREEN}SWAL_INSTALL_ALL=1 bash install-swal-node.sh${NC}"
    echo -e "Agente específico:     ${GREEN}SWAL_INSTALL_JULES=1 bash install-swal-node.sh${NC}"
    echo ""
    echo -e "${CYAN}Presiona Enter para continuar...${NC}"
    read -r

    check_termux
    install_base_packages
    install_python_packages
    install_nodejs_packages
    install_rust
    install_go
    install_flutter
    install_php
    install_jules
    install_claude_code
    install_opencode
    install_gemini_cli
    install_qwen
    install_supabase
    install_aws
    install_gcp
    install_cloudflare
    install_terraform
    install_pulumi
    install_bun
    install_deno
    setup_git
    install_zsh
    setup_ssh
    install_zeroclaw
    install_gestalt
    setup_workspace
    setup_zeroclaw_config
    setup_autostart
    validate

    success "SWAL Node instalado correctamente!"
}

main "$@"
