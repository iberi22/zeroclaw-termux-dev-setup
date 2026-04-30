#!/bin/bash
# =============================================================================
# diagnose.sh - Environment Diagnostic for ZeroClaw/SWAN Node
# =============================================================================
# Usage: ./diagnose.sh [--json]
# Exit codes: 0=healthy, 1=issues found, 2=critical failures

set -euo pipefail

OUTPUT_JSON=false
if [[ "${1:-}" == "--json" ]]; then
    OUTPUT_JSON=true
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

log_pass() { echo -e "  ${GREEN}✓${NC} $*"; ((PASS++)); }
log_fail() { echo -e "  ${RED}✗${NC} $*"; ((FAIL++)); }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $*"; ((WARN++)); }
log_info() { echo -e "  ${BLUE}ℹ${NC} $*"; }
log_section() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }

# JSON output helper
declare -A JSON_RESULTS
json_result() { JSON_RESULTS["$1"]="$2"; }

# =============================================================================
# HEADER
# =============================================================================
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║           ZeroClaw / SWAN Node - Environment Diagnostic       ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Run: $(hostname) | $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo -e "  User: $(whoami) (UID: $(id -u))"
echo -e "  Shell: ${SHELL}"
echo -e "  Arch: $(uname -m)"
echo ""

# =============================================================================
# 1. SYSTEM RESOURCES
# =============================================================================
log_section "System Resources"

# CPU
CPU_MODEL=$(cat /proc/cpuinfo 2>/dev/null | grep "model name" | head -1 | cut -d: -f2 | xargs || echo "unknown")
CPU_CORES=$(nproc 2>/dev/null || echo "?")
log_info "CPU: ${CPU_MODEL}"
log_info "Cores: ${CPU_CORES}"

# Memory
MEM_TOTAL=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' || echo "?")
MEM_USED=$(free -h 2>/dev/null | grep Mem | awk '{print $3}' || echo "?")
MEM_AVAIL=$(free -h 2>/dev/null | grep Mem | awk '{print $7}' || echo "?")
log_info "Memory: ${MEM_USED} used / ${MEM_TOTAL} total (${MEM_AVAIL} available)"

# Disk
DISK_ROOT=$(df -h / 2>/dev/null | tail -1 | awk '{print $3" used / "$2" total ("$5" used)"}' || echo "?")
log_info "Disk /: ${DISK_ROOT}"

# Load average
LOADAVG=$(cat /proc/loadavg 2>/dev/null | awk '{print $1" "$2" "$3"}' || echo "?")
log_info "Load avg (1/5/15 min): ${LOADAVG}"

# Uptime
UPTIME=$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "?")
log_info "Uptime: ${UPTIME}"

# =============================================================================
# 2. OPERATING SYSTEM
# =============================================================================
log_section "Operating System"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    log_info "OS: ${PRETTY_NAME:-${NAME} ${VERSION}}"
    log_info "ID: ${ID:-unknown}"
else
    log_warn "OS detection: /etc/os-release not found"
fi
log_info "Kernel: $(uname -r)"

# =============================================================================
# 3. PROGRAMMING LANGUAGES
# =============================================================================
log_section "Programming Languages"

# Node.js
if command -v node &>/dev/null; then
    NODE_VER=$(node --version 2>/dev/null)
    NPM_VER=$(npm --version 2>/dev/null)
    PNPM_VER=$(pnpm --version 2>/dev/null || echo "not installed")
    YARN_VER=$(yarn --version 2>/dev/null || echo "not installed")
    log_pass "Node.js: ${NODE_VER} (npm: ${NPM_VER}, pnpm: ${PNPM_VER}, yarn: ${YARN_VER})"
    json_result "node" "${NODE_VER}"
else
    log_fail "Node.js: NOT FOUND"
fi

# Python
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version 2>/dev/null)
    PIP_VER=$(pip3 --version 2>/dev/null | awk '{print $2}' || echo "?")
    log_pass "Python: ${PY_VER} (pip: ${PIP_VER})"
    json_result "python" "${PY_VER}"
else
    log_fail "Python3: NOT FOUND"
fi

# Rust
if command -v rustc &>/dev/null; then
    RUST_VER=$(rustc --version 2>/dev/null)
    CARGO_VER=$(cargo --version 2>/dev/null)
    log_pass "Rust: ${RUST_VER} (${CARGO_VER})"
    json_result "rust" "${RUST_VER}"
else
    log_fail "Rust: NOT FOUND"
fi

# Go
if command -v go &>/dev/null; then
    GO_VER=$(go version 2>/dev/null | awk '{print $3}')
    GOPATH=$(go env GOPATH 2>/dev/null)
    log_pass "Go: ${GO_VER} (GOPATH: ${GOPATH})"
    json_result "go" "${GO_VER}"
else
    log_fail "Go: NOT FOUND"
fi

# Java
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2)
    if command -v javac &>/dev/null; then
        JAVAC_VER=$(javac -version 2>&1 | awk '{print $2}')
        log_pass "Java: ${JAVA_VER} (javac: ${JAVAC_VER})"
    else
        log_warn "Java: ${JAVA_VER} (javac NOT found)"
    fi
    json_result "java" "${JAVA_VER}"
else
    log_fail "Java: NOT FOUND"
fi

# PHP
if command -v php &>/dev/null; then
    PHP_VER=$(php --version 2>/dev/null | head -1 | awk '{print $2}')
    log_pass "PHP: ${PHP_VER}"
    json_result "php" "${PHP_VER}"
else
    log_fail "PHP: NOT FOUND"
fi

# Ruby
if command -v ruby &>/dev/null; then
    RUBY_VER=$(ruby --version 2>/dev/null | awk '{print $2}')
    log_pass "Ruby: ${RUBY_VER}"
    json_result "ruby" "${RUBY_VER}"
else
    log_fail "Ruby: NOT FOUND"
fi

# =============================================================================
# 4. DATABASE & MESSAGING
# =============================================================================
log_section "Databases & Messaging"

# Docker
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
    if docker info &>/dev/null; then
        log_pass "Docker: ${DOCKER_VER} (running)"
    else
        log_warn "Docker: ${DOCKER_VER} (installed but not running)"
    fi
else
    log_fail "Docker: NOT FOUND"
fi

# PostgreSQL
if command -v psql &>/dev/null; then
    PG_VER=$(psql --version 2>/dev/null | awk '{print $3}')
    if pg_isready &>/dev/null || systemctl is-active postgresql &>/dev/null; then
        log_pass "PostgreSQL: ${PG_VER} (running)"
    else
        log_warn "PostgreSQL: ${PG_VER} (installed, may not be running)"
    fi
else
    log_warn "PostgreSQL client: NOT FOUND"
fi

# Redis
if command -v redis-cli &>/dev/null; then
    REDIS_VER=$(redis-cli --version 2>/dev/null | awk '{print $2}')
    if redis-cli ping &>/dev/null 2>&1; then
        log_pass "Redis: ${REDIS_VER} (running)"
    else
        log_warn "Redis: ${REDIS_VER} (installed, may not be running)"
    fi
else
    log_warn "Redis CLI: NOT FOUND"
fi

# =============================================================================
# 5. API KEYS & CREDENTIALS
# =============================================================================
log_section "API Keys & Credentials"

check_key() {
    local name=$1
    local var=$2
    local value="${!var:-}"
    if [[ -n "$value" && "$value" != "***" && "$value" != "your_"* ]]; then
        local short="${value:0:12}...${value: -4}"
        log_pass "${name}: ${short}"
        json_result "$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')" "present"
    else
        log_fail "${name}: MISSING or NOT SET"
        json_result "$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')" "missing"
    fi
}

check_key "GROQ_API_KEY" "GROQ_API_KEY"
check_key "GEMINI_API_KEY" "GEMINI_API_KEY"
check_key "MINIMAX_API_KEY" "MINIMAX_API_KEY"
check_key "CORTEX_TOKEN" "CORTEX_TOKEN"
check_key "OPENAI_API_KEY" "OPENAI_API_KEY"
check_key "ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY"

# =============================================================================
# 6. SWAL SPECIFIC
# =============================================================================
log_section "SWAL / ZeroClaw Specific"

# OpenClaw
if command -v openclaw &>/dev/null; then
    OC_VER=$(openclaw --version 2>/dev/null || openclaw version 2>/dev/null || echo "unknown")
    log_pass "OpenClaw CLI: ${OC_VER}"
else
    log_warn "OpenClaw CLI: NOT FOUND (may not be in PATH)"
fi

# Gestalt Swarm
if command -v gestalt &>/dev/null; then
    GS_VER=$(gestalt --version 2>/dev/null || echo "unknown")
    log_pass "Gestalt Swarm: ${GS_VER}"
elif [[ -f /usr/local/bin/gestalt ]]; then
    log_pass "Gestalt Swarm: binary at /usr/local/bin/gestalt"
else
    log_warn "Gestalt Swarm: NOT FOUND"
fi

# Cortex (local)
if curl -s --max-time 3 http://localhost:8003/health &>/dev/null; then
    log_pass "Cortex: running at localhost:8003"
    json_result "cortex" "running"
elif curl -s --max-time 3 http://localhost:8003 &>/dev/null; then
    log_pass "Cortex: responding at localhost:8003 (no health endpoint)"
else
    log_warn "Cortex: NOT running at localhost:8003"
fi

# Workspace
if [[ -d /zeroclaw/workspace ]]; then
    WS_SIZE=$(du -sh /zeroclaw/workspace 2>/dev/null | cut -f1 || echo "?")
    log_pass "Workspace: /zeroclaw/workspace (${WS_SIZE})"
elif [[ -d /root/workspace ]]; then
    WS_SIZE=$(du -sh /root/workspace 2>/dev/null | cut -f1 || echo "?")
    log_pass "Workspace: /root/workspace (${WS_SIZE})"
elif [[ -d /workspace ]]; then
    WS_SIZE=$(du -sh /workspace 2>/dev/null | cut -f1 || echo "?")
    log_pass "Workspace: /workspace (${WS_SIZE})"
else
    log_warn "Workspace: NOT FOUND"
fi

# =============================================================================
# 7. DEV TOOLS
# =============================================================================
log_section "Developer Tools"

check_tool() {
    local name=$1
    local cmd=$2
    if command -v "$cmd" &>/dev/null; then
        local ver=$("$cmd" --version 2>/dev/null | head -1 | xargs || echo "")
        log_pass "${name}: ${ver:-found}"
    else
        log_fail "${name}: NOT FOUND"
    fi
}

check_tool "Git" "git"
check_tool "Docker" "docker"
check_tool "kubectl" "kubectl"
check_tool "Helm" "helm"
check_tool "Terraform" "terraform"
check_tool "Ansible" "ansible"
check_tool "Make" "make"
check_tool "CMake" "cmake"
check_tool "Ninja" "ninja"
check_tool "LLVM/Clang" "clang"
check_tool "GCC" "gcc"
check_tool "GDB" "gdb"
check_tool "Valgrind" "valgrind"

# =============================================================================
# 8. NETWORK & CONNECTIVITY
# =============================================================================
log_section "Network & Connectivity"

# DNS
DNS_SERVER=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}' || echo "?")
log_info "DNS: ${DNS_SERVER}"

# Internet connectivity
if curl -s --max-time 5 -o /dev/null -w "%{http_code}" https://api.github.com 2>/dev/null | grep -q "200"; then
    log_pass "Internet: HTTPS connectivity (api.github.com)"
elif curl -s --max-time 5 -o /dev/null https://api.github.com 2>/dev/null; then
    log_pass "Internet: connected (api.github.com)"
else
    log_fail "Internet: NO connectivity to api.github.com"
fi

# API endpoints
check_endpoint() {
    local name=$1
    local url=$2
    local code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        log_pass "${name}: OK (${code})"
    elif [[ "$code" == "401" || "$code" == "403" ]]; then
        log_pass "${name}: responding (${code} - auth issue is ok)"
    else
        log_warn "${name}: HTTP ${code}"
    fi
}

check_endpoint "Groq API" "https://api.groq.com/openai/v1/models"
check_endpoint "Gemini API" "https://generativelanguage.googleapis.com/v1/models"
check_endpoint "OpenAI API" "https://api.openai.com/v1/models"

# =============================================================================
# 9. PORT STATUS
# =============================================================================
log_section "Port Status (_common SWAL ports)"

check_port() {
    local port=$1
    local name=$2
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        local addr=$(ss -tlnp 2>/dev/null | grep ":${port} " | awk '{print $4}' || echo "?")
        log_pass "${name} (${port}): LISTENING on ${addr}"
    elif netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
        log_pass "${name} (${port}): LISTENING"
    else
        log_info "${name} (${port}): not in use"
    fi
}

check_port 8003 "Cortex"
check_port 3000 "Next.js"
check_port 5173 "Vite"
check_port 5432 "PostgreSQL"
check_port 6379 "Redis"
check_port 8080 "HTTP alt"
check_port 9123 "SynapseTrader"
check_port 19234 "SynapseTrading"

# =============================================================================
# 10. SECURITY
# =============================================================================
log_section "Security"

# SSH keys
if [[ -f ~/.ssh/id_rsa ]] || [[ -f ~/.ssh/id_ed25519 ]]; then
    log_pass "SSH keys: present"
else
    log_warn "SSH keys: NOT FOUND"
fi

# Fail2ban
if command -v fail2ban-client &>/dev/null; then
    log_pass "Fail2ban: installed"
else
    log_info "Fail2ban: not installed"
fi

# UFW/firewall
if command -v ufw &>/dev/null; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        log_pass "UFW: active"
    else
        log_info "UFW: installed but not active"
    fi
else
    log_info "UFW: not installed"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                        SUMMARY                                 ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ PASSED:  ${PASS}${NC}"
echo -e "  ${YELLOW}⚠ WARNINGS: ${WARN}${NC}"
echo -e "  ${RED}✗ FAILED:   ${FAIL}${NC}"
echo ""

# Critical checks (must pass)
CRITICAL_FAILS=0
if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}⚠ Issues detected that may prevent agent operation:${NC}"
    
    # Re-show failed items
    if ! command -v node &>/dev/null; then
        echo -e "  ${RED}✗${NC} Node.js missing - required for OpenClaw"
        ((CRITICAL_FAILS++))
    fi
    if ! command -v python3 &>/dev/null; then
        echo -e "  ${RED}✗${NC} Python3 missing - required for AI/ML tools"
        ((CRITICAL_FAILS++))
    fi
    if [[ -z "${GROQ_API_KEY:-}" && -z "${GEMINI_API_KEY:-}" ]]; then
        echo -e "  ${RED}✗${NC} No LLM API keys set (GROQ_API_KEY or GEMINI_API_KEY)"
        ((CRITICAL_FAILS++))
    fi
fi

echo ""

# JSON output
if $OUTPUT_JSON; then
    echo "{"
    echo "  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
    echo "  \"hostname\": \"$(hostname)\","
    echo "  \"passed\": ${PASS},"
    echo "  \"warnings\": ${WARN},"
    echo "  \"failed\": ${FAIL},"
    echo "  \"results\": {"
    local first=true
    for key in "${!JSON_RESULTS[@]}"; do
        if $first; then
            first=false
        else
            echo ","
        fi
        echo -n "    \"${key}\": \"${JSON_RESULTS[$key]}\""
    done
    echo ""
    echo "  }"
    echo "}"
fi

# Exit code
if [[ $FAIL -gt 0 ]]; then
    exit 1
elif [[ $WARN -gt 0 ]]; then
    exit 0
else
    exit 0
fi
