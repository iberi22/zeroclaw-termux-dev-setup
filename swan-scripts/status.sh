#!/bin/bash
# ZeroClaw SWARM Node — Status
set -Eeuo pipefail
CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo -e "${CYAN}[SWARM]${NC} Estado del nodo"
echo ""

# Docker container
if docker compose ps &>/dev/null; then
    echo "Containers:"
    docker compose ps
    echo ""
fi

# Gateway
if curl -sf http://localhost:42617/health &>/dev/null; then
    echo -e "${GREEN}✓${NC} Gateway ZeroClaw: http://localhost:42617"
    STATUS=$(curl -s http://localhost:42617/status 2>/dev/null | head -c 200 || echo "unknown")
    echo "  Status: $STATUS"
else
    echo -e "${RED}✗${NC} Gateway ZeroClaw: NO disponible"
fi

# SSH
if pgrep -x sshd &>/dev/null || docker exec zeroclaw-swan-node pgrep sshd &>/dev/null 2>/dev/null; then
    echo -e "${GREEN}✓${NC} SSH: localhost:2222"
else
    echo -e "${YELLOW}?${NC} SSH: no verificado"
fi

# Cortex
if curl -sf http://localhost:8003/health &>/dev/null; then
    echo -e "${GREEN}✓${NC} Cortex: http://localhost:8003"
else
    echo -e "${YELLOW}?${NC} Cortex: no corriendo (o profile not started)"
fi

# SSH key
SSH_KEY_FILE="volumes/ssh/id_rsa.pub"
if [[ -f "$SSH_KEY_FILE" ]]; then
    echo ""
    echo "SSH Public Key:"
    cat "$SSH_KEY_FILE"
fi
