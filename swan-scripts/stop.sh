#!/bin/bash
# ZeroClaw SWARM Node — Stop
set -Eeuo pipefail
CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo -e "${RED}[SWARM]${NC} Deteniendo nodo..."
docker compose down
echo -e "${RED}[SWARM]${NC} ✓ Nodo detenido"
