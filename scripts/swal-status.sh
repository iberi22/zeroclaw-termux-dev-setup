#!/bin/bash
# ============================================================
# SWAL Status Dashboard - Termux MOTD
# Shows system health, versions, updates, and pending tasks
# v2.0 - With version checks and update notifications
# ============================================================

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
BOLD='\033[1m'; DIM='\033[2m'

# Skip if disabled
[[ -f "$HOME/.swal-motd-disable" ]] && exit 0

# Only run in interactive SSH/Termux sessions
if [[ -n "$TERMUX_VERSION" ]] || [[ -n "$SSH_CONNECTION" ]]; then
    : # Continue
else
    [[ ! -t 0 ]] && exit 0
fi

# ============================================================
# Helpers
# ============================================================
check() {
    [[ $1 -eq 0 ]] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}"
}

check_warn() {
    [[ $1 -eq 0 ]] && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"
}

version_ok() {
    # $1 = current version, $2 = minimum required
    current_ver=$(echo "$1" | grep -oP '\d+\.\d+\.\d+' | head -1)
    min_ver=$(echo "$2" | grep -oP '\d+\.\d+\.\d+' | head -1)
    if [[ -z "$current_ver" ]] || [[ -z "$min_ver" ]]; then
        echo -e "${GREEN}$1${NC}"
        return 0
    fi
    # Simple comparison
    if [[ "$current_ver" < "$min_ver" ]]; then
        echo -e "${YELLOW}$1${NC} ${RED}↻ update${NC}"
        return 1
    fi
    echo -e "${GREEN}$1${NC}"
    return 0
}

# ============================================================
# Header
# ============================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN} ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${CYAN}SouthWest AI Labs - Termux Node${NC}                       ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# Section: Services Status
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  📋 Servicios${NC}"

echo -n "   SSH Server    "
if pgrep -f sshd &>/dev/null; then
    echo -e "${GREEN}✅ running${NC}  (PID: $(pgrep -f sshd | head -1))"
else
    echo -e "${YELLOW}⚠️  stopped${NC}  → ${CYAN}sshd${NC}"
fi

echo -n "   ZeroClaw     "
if pgrep -f "zeroclaw daemon" &>/dev/null; then
    zc_pid=$(pgrep -f "zeroclaw daemon" | head -1)
    echo -e "${GREEN}✅ running${NC}  (PID: $zc_pid)"
elif command -v zeroclaw &>/dev/null; then
    echo -e "${YELLOW}⚠️  stopped${NC}  → ${CYAN}zeroclaw daemon${NC}"
else
    echo -e "${RED}❌ not installed${NC}"
fi

echo -n "   OpenClaw     "
if pgrep -f "openclaw gateway" &>/dev/null; then
    echo -e "${GREEN}✅ running${NC}"
elif pgrep -f "node.*openclaw" &>/dev/null; then
    echo -e "${GREEN}✅ running${NC}"
else
    echo -e "${YELLOW}⚠️  not detected${NC}"
fi

echo -n "   Cortex       "
if curl -s --connect-timeout 1 http://localhost:8003/health &>/dev/null; then
    echo -e "${GREEN}✅ healthy${NC}"
else
    echo -e "${YELLOW}⚠️  unreachable${NC}"
fi

# ============================================================
# Section: Development Tools with Versions
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  🔧 Herramientas de Desarrollo${NC}"

# Git
echo -n "   Git          "
if command -v git &>/dev/null; then
    git_ver=$(git --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    echo -e "${GREEN}✅ v$git_ver${NC}"
else
    echo -e "${RED}❌ not installed${NC}"
fi

# Node.js
echo -n "   Node.js      "
if command -v node &>/dev/null; then
    node_ver=$(node --version 2>/dev/null | tr -d 'v')
    echo -e "${GREEN}✅ v$node_ver${NC}"
else
    echo -e "${RED}❌ not installed${NC}  → ${CYAN}pkg install nodejs${NC}"
fi

# npm
echo -n "   npm          "
if command -v npm &>/dev/null; then
    npm_ver=$(npm --version 2>/dev/null)
    echo -e "${GREEN}✅ v$npm_ver${NC}"
else
    echo -e "${RED}❌ not installed${NC}"
fi

# Python
echo -n "   Python       "
if command -v python3 &>/dev/null; then
    py_ver=$(python3 --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
    echo -e "${GREEN}✅ v$py_ver${NC}"
else
    echo -e "${RED}❌ not installed${NC}  → ${CYAN}pkg install python${NC}"
fi

# pip
echo -n "   pip          "
if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
    pip_ver=$(pip --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || pip3 --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    echo -e "${GREEN}✅ v$pip_ver${NC}"
else
    echo -e "${YELLOW}⚠️  not available${NC}"
fi

# curl
echo -n "   curl         "
if command -v curl &>/dev/null; then
    curl_ver=$(curl --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+')
    echo -e "${GREEN}✅ v$curl_ver${NC}"
else
    echo -e "${RED}❌ not installed${NC}"
fi

# ============================================================
# Section: ZeroClaw Config
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  ⚙️  ZeroClaw Config${NC}"

ZC_CONFIG="$HOME/.zeroclaw/config.toml"

if [[ -f "$ZC_CONFIG" ]]; then
    echo -n "   Config file  "
    echo -e "${GREEN}✅ exists${NC}"

    echo -n "   autonomy    "
    autonomy=$(grep 'autonomy_level' "$ZC_CONFIG" 2>/dev/null | grep -oP '".*?"' | tr -d '"')
    if [[ "$autonomy" == "full" ]]; then
        echo -e "${GREEN}✅ full${NC}"
    elif [[ -n "$autonomy" ]]; then
        echo -e "${YELLOW}⚠️  $autonomy${NC}  → ${CYAN}set to full${NC}"
    else
        echo -e "${RED}❌ not configured${NC}"
    fi

    echo -n "   allowed     "
    cmds_line=$(grep 'allowed_commands' "$ZC_CONFIG" 2>/dev/null)
    if [[ -n "$cmds_line" ]]; then
        cmd_count=$(echo "$cmds_line" | grep -o '"' | wc -l)
        cmd_count=$((cmd_count / 2))
        echo -e "${GREEN}✅ $cmd_count commands${NC}"
    else
        echo -e "${RED}❌ empty${NC}"
    fi

    echo -n "   Telegram    "
    if grep -q 'bot_token' "$ZC_CONFIG" 2>/dev/null; then
        echo -e "${GREEN}✅ configured${NC}"
    else
        echo -e "${YELLOW}⚠️  not in config${NC}"
    fi
else
    echo -e "   ${RED}❌ Config file missing${NC}"
    echo -e "   ${YELLOW}   Run: curl -fsSL ...setup-termux.sh | bash${NC}"
fi

# ============================================================
# Section: API Keys
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  🔑 API Keys${NC}"

echo -n "   MiniMax      "
if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
    echo -e "${GREEN}✅ set${NC}"
elif grep -q "MINIMAX_API_KEY" "$HOME/.openclaw/secrets.env" 2>/dev/null; then
    echo -e "${GREEN}✅ configured${NC}"
else
    echo -e "${YELLOW}⚠️  not configured${NC}"
fi

echo -n "   Groq         "
if [[ -n "${GROQ_API_KEY:-}" ]]; then
    echo -e "${GREEN}✅ set${NC}"
elif grep -q "GROQ_API_KEY" "$HOME/.openclaw/secrets.env" 2>/dev/null; then
    echo -e "${GREEN}✅ configured${NC}"
else
    echo -e "${YELLOW}⚠️  not configured${NC}"
fi

echo -n "   Telegram ZC  "
if [[ -n "${TG_ZEROCLAW_TOKEN:-}" ]]; then
    echo -e "${GREEN}✅ set${NC}"
else
    echo -e "${YELLOW}⚠️  TG_ZEROCLAW_TOKEN not set${NC}"
fi

# ============================================================
# Section: Workspace
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  📁 Workspace${NC}"

echo -n "   Workspace    "
if [[ -d "$HOME/.zeroclaw/workspace" ]]; then
    files=$(find "$HOME/.zeroclaw/workspace" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ $files files${NC}"
else
    echo -e "${YELLOW}⚠️  not created${NC}"
fi

echo -n "   Skills      "
if [[ -d "$HOME/.zeroclaw/skills" ]]; then
    skills=$(ls -d "$HOME/.zeroclaw/skills"/*/ 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ $skills installed${NC}"
else
    echo -e "${YELLOW}⚠️  none installed${NC}"
fi

echo -n "   OpenClaw    "
if [[ -d "$HOME/.openclaw" ]]; then
    echo -e "${GREEN}✅ ready${NC}"
else
    echo -e "${YELLOW}⚠️  not initialized${NC}"
fi

# ============================================================
# Section: Quick Actions
# ============================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  ⚡ Quick Actions${NC}"
echo ""

if pgrep -f "zeroclaw daemon" &>/dev/null; then
    echo -e "   ${GREEN}✅ ZeroClaw is running${NC}"
    echo -e "   ${DIM}   Restart:${CYAN} pkill zeroclaw && zeroclaw daemon${NC}"
else
    if command -v zeroclaw &>/dev/null; then
        echo -e "   ${YELLOW}⚠️  ZeroClaw stopped${NC}"
        echo -e "   ${GREEN}   Start:${CYAN} zeroclaw daemon${NC}"
    fi
fi

echo ""

# ============================================================
# Footer
# ============================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${BOLD}Commands:${NC}  ${GREEN}zeroclaw daemon${NC}  •  ${GREEN}swal-status${NC}  •  ${GREEN}htop${NC}  •  ${GREEN}logout${NC}"
echo -e "  ${DIM}Disable:${NC}   ${CYAN}touch ~/.swal-motd-disable${NC}"
echo ""