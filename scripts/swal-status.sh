#!/bin/bash
# ============================================================
# SWAL Status Dashboard - Termux MOTD
# Shows system health, tokens, and pending tasks on startup
# v1.0 - Fast, silent, beautiful
# ============================================================

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
BOLD='\033[1m'

# Skip if disabled
[[ -f "$HOME/.swal-motd-disable" ]] && exit 0

# Only run in interactive SSH/Termux sessions
if [[ -n "$TERMUX_VERSION" ]] || [[ -n "$SSH_CONNECTION" ]]; then
    : # Continue
else
    # Check if stdin is a TTY (interactive shell)
    if [[ ! -t 0 ]]; then
        exit 0
    fi
fi

# ============================================================
# Helper: status check
# ============================================================
check_ok() {
    if [[ $1 -eq 0 ]]; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FAIL${NC}"
    fi
}

check_warn() {
    if [[ $1 -eq 0 ]]; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${YELLOW}⚠ WARN${NC}"
    fi
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
# Section: System Services
# ============================================================
echo -e "${CYAN}─── Servicios ──────────────────────────────────────────${NC}"

echo -n "  SSH server:        "
if pgrep -f sshd &>/dev/null; then
    echo -e "${GREEN}✓ running${NC} (PID: $(pgrep -f sshd | head -1))"
else
    echo -e "${YELLOW}⚠ not running${NC}"
fi

echo -n "  ZeroClaw daemon:   "
if pgrep -f "zeroclaw daemon" &>/dev/null; then
    echo -e "${GREEN}✓ running${NC}"
elif command -v zeroclaw &>/dev/null; then
    echo -e "${YELLOW}⚠ installed, run 'zeroclaw daemon'${NC}"
else
    echo -e "${RED}✗ not installed${NC}"
fi

echo -n "  OpenClaw gateway:  "
if pgrep -f "openclaw gateway" &>/dev/null; then
    echo -e "${GREEN}✓ running${NC}"
elif pgrep -f "node.*openclaw" &>/dev/null; then
    echo -e "${GREEN}✓ running${NC}"
else
    echo -e "${YELLOW}⚠ not detected${NC}"
fi

echo -n "  Cortex service:    "
if curl -s --connect-timeout 2 http://localhost:8003/health &>/dev/null; then
    echo -e "${GREEN}✓ healthy${NC}"
elif curl -s --connect-timeout 2 http://localhost:8003 &>/dev/null; then
    echo -e "${GREEN}✓ running${NC}"
else
    echo -e "${YELLOW}⚠ not reachable${NC}"
fi

echo -n "  Termux API:        "
if command -v termux-battery &>/dev/null; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ not installed${NC}"
fi

# ============================================================
# Section: Development Tools
# ============================================================
echo ""
echo -e "${CYAN}─── Herramientas ───────────────────────────────────────${NC}"

echo -n "  Git:               "
if command -v git &>/dev/null; then
    git_ver=$(git --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    echo -e "${GREEN}✓ $git_ver${NC}"
else
    echo -e "${RED}✗ not installed${NC}"
fi

echo -n "  Node.js:           "
if command -v node &>/dev/null; then
    node_ver=$(node --version 2>/dev/null)
    echo -e "${GREEN}✓ $node_ver${NC}"
else
    echo -e "${RED}✗ not installed${NC}"
fi

echo -n "  npm:               "
if command -v npm &>/dev/null; then
    npm_ver=$(npm --version 2>/dev/null)
    echo -e "${GREEN}✓ v$npm_ver${NC}"
else
    echo -e "${YELLOW}⚠ not installed${NC}"
fi

echo -n "  Python:            "
if command -v python3 &>/dev/null; then
    py_ver=$(python3 --version 2>/dev/null | grep -oP '\d+\.\d+')
    echo -e "${GREEN}✓ $py_ver${NC}"
else
    echo -e "${RED}✗ not installed${NC}"
fi

echo -n "  pip:               "
if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ not installed${NC}"
fi

# ============================================================
# Section: ZeroClaw Config
# ============================================================
echo ""
echo -e "${CYAN}─── ZeroClaw Config ────────────────────────────────────${NC}"

ZC_CONFIG="$HOME/.zeroclaw/config.toml"

if [[ -f "$ZC_CONFIG" ]]; then
    echo -n "  Config file:       "
    echo -e "${GREEN}✓ exists${NC}"

    echo -n "  autonomy_level:    "
    autonomy=$(grep 'autonomy_level' "$ZC_CONFIG" 2>/dev/null | grep -oP '".*?"' | tr -d '"')
    if [[ "$autonomy" == "full" ]]; then
        echo -e "${GREEN}✓ full${NC}"
    elif [[ -n "$autonomy" ]]; then
        echo -e "${YELLOW}⚠ $autonomy${NC}"
    else
        echo -e "${RED}✗ not set${NC}"
    fi

    echo -n "  allowed_commands:  "
    cmds=$(grep 'allowed_commands' "$ZC_CONFIG" 2>/dev/null | wc -l)
    if [[ "$cmds" -gt 0 ]]; then
        echo -e "${GREEN}✓ configured ($cmds entries)${NC}"
    else
        echo -e "${RED}✗ not configured${NC}"
    fi

    echo -n "  Telegram bot:      "
    if grep -q 'bot_token' "$ZC_CONFIG" 2>/dev/null; then
        echo -e "${GREEN}✓ configured${NC}"
    else
        echo -e "${YELLOW}⚠ not found in config${NC}"
    fi
else
    echo -e "  ${RED}✗ Config file not found${NC}"
    echo -e "  ${YELLOW}  Run: curl -fsSL ...setup-termux.sh | bash${NC}"
fi

# ============================================================
# Section: API Keys
# ============================================================
echo ""
echo -e "${CYAN}─── API Keys ───────────────────────────────────────────${NC}"

echo -n "  MiniMax:           "
if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
    echo -e "${GREEN}✓ set${NC}"
elif grep -q "MINIMAX_API_KEY" "$HOME/.openclaw/secrets.env" 2>/dev/null; then
    echo -e "${GREEN}✓ configured${NC}"
else
    echo -e "${YELLOW}⚠ not configured${NC}"
fi

echo -n "  Groq (Whisper):    "
if [[ -n "${GROQ_API_KEY:-}" ]]; then
    echo -e "${GREEN}✓ set${NC}"
elif grep -q "GROQ_API_KEY" "$HOME/.openclaw/secrets.env" 2>/dev/null; then
    echo -e "${GREEN}✓ configured${NC}"
else
    echo -e "${YELLOW}⚠ not configured${NC}"
fi

echo -n "  Telegram (ZC):     "
if [[ -n "${TG_ZEROCLAW_TOKEN:-}" ]]; then
    echo -e "${GREEN}✓ set${NC}"
else
    echo -e "${YELLOW}⚠ not set (env var TG_ZEROCLAW_TOKEN)${NC}"
fi

# ============================================================
# Section: Workspace & Skills
# ============================================================
echo ""
echo -e "${CYAN}─── Workspace ───────────────────────────────────────────${NC}"

echo -n "  Workspace dir:     "
if [[ -d "$HOME/.zeroclaw/workspace" ]]; then
    files=$(find "$HOME/.zeroclaw/workspace" -type f 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ $files files${NC}"
else
    echo -e "${YELLOW}⚠ not created${NC}"
fi

echo -n "  Skills dir:        "
if [[ -d "$HOME/.zeroclaw/skills" ]]; then
    skills=$(ls -d "$HOME/.zeroclaw/skills"/*/ 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ $skills skills${NC}"
else
    echo -e "${YELLOW}⚠ not installed${NC}"
fi

echo -n "  OpenClaw dir:      "
if [[ -d "$HOME/.openclaw" ]]; then
    echo -e "${GREEN}✓ exists${NC}"
else
    echo -e "${YELLOW}⚠ not created${NC}"
fi

# ============================================================
# Section: Pending Tasks
# ============================================================
echo ""
echo -e "${CYAN}─── Pending Tasks ────────────────────────────────────────${NC}"

has_tasks=0

# ZeroClaw not running
if ! pgrep -f "zeroclaw daemon" &>/dev/null && command -v zeroclaw &>/dev/null; then
    echo -e "  ${YELLOW}→ ZeroClaw not running${NC}"
    echo -e "    Run: ${GREEN}zeroclaw daemon${NC}"
    has_tasks=1
fi

# Config incomplete
if [[ -f "$ZC_CONFIG" ]]; then
    if ! grep -q 'autonomy_level.*"full"' "$ZC_CONFIG" 2>/dev/null; then
        echo -e "  ${YELLOW}→ autonomy_level not set to 'full'${NC}"
        has_tasks=1
    fi
else
    echo -e "  ${RED}→ ZeroClaw config missing${NC}"
    echo -e "    Run setup: ${GREEN}curl -fsSL ...setup-termux.sh | bash${NC}"
    has_tasks=1
fi

# Missing API keys
if [[ ! -f "$HOME/.openclaw/secrets.env" ]] && [[ ! -n "${MINIMAX_API_KEY:-}" ]]; then
    echo -e "  ${YELLOW}→ MiniMax API key not configured${NC}"
    has_tasks=1
fi

# All good
if [[ $has_tasks -eq 0 ]]; then
    echo -e "  ${GREEN}✓ All systems operational${NC}"
fi

# ============================================================
# Footer
# ============================================================
echo ""
echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
echo -e "  ${BOLD}Quick commands:${NC}"
echo -e "    ${GREEN}zeroclaw daemon${NC}  - Start ZeroClaw"
echo -e "    ${GREEN}swal-status${NC}       - Show this status"
echo -e "    ${GREEN}htop${NC}              - Task manager"
echo -e "    ${GREEN}logout${NC}            - Exit Termux"
echo ""
echo -e "  ${BOLD}Disable MOTD:${NC} touch ~/.swal-motd-disable"
echo ""