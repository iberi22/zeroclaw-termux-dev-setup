#!/bin/bash
# =============================================================================
# ZeroClaw SWARM Node — Start
# =============================================================================
set -Eeuo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo -e "${CYAN}[SWARM]${NC} Iniciando nodo ZeroClaw..."

# Verificar .env
if [[ ! -f config/.env ]]; then
    if [[ -f config/.env.example ]]; then
        echo -e "${YELLOW}[SWARM]${NC} Copiando .env.example → .env"
        cp config/.env.example config/.env
        echo -e "${YELLOW}[SWARM]${NC} EDITAR config/.env CON API KEY ANTES DE CONTINUAR${NC}"
        echo -e "${YELLOW}[SWARM]${NC} nano config/.env${NC}"
        exit 1
    else
        echo -e "${YELLOW}[SWARM]${NC} .env no encontrado. Creando default..."
        cp config/.env.example config/.env 2>/dev/null || true
    fi
fi

# Verificar que API_KEY está configurada
if ! grep -q '^API_KEY=sk-' config/.env 2>/dev/null; then
    echo -e "${YELLOW}[SWARM]${NC} API_KEY no configurada en config/.env"
    echo -e "${YELLOW}[SWARM]${NC} Edita config/.env y añade tu API key"
    exit 1
fi

# Build si no existe imagen
if ! docker image inspect zeroclaw-swan-node:latest &>/dev/null; then
    echo -e "${CYAN}[SWARM]${NC} Imagen no existe. Ejecutando build..."
    docker build -t zeroclaw-swan-node:latest . || {
        echo -e "\033[0;31m[SWARM]${NC} Build falló"
        exit 1
    }
fi

# Levantar
echo -e "${CYAN}[SWARM]${NC} Levantando servicios..."
docker compose up -d

# Esperar que esté listo
echo -e "${CYAN}[SWARM]${NC} Esperando que el nodo esté listo..."
sleep 5

# Verificar
if curl -sf http://localhost:42617/health &>/dev/null; then
    echo -e "\033[0;32m[SWARM]${NC} ✓ Nodo corriendo"
    echo -e "\033[0;32m[SWARM]${NC} ✓ Gateway: http://localhost:42617"
    echo -e "\033[0;32m[SWARM]${NC} ✓ SSH: localhost:2222"
    echo ""
    echo -e "${CYAN}SSH access:${NC}"
    echo -e "  ssh -p 2222 root@localhost"
    echo ""
    echo -e "${CYAN}Ver logs:${NC}"
    echo -e "  ./scripts/logs.sh"
    echo ""
    echo -e "${CYAN}Detener:${NC}"
    echo -e "  ./scripts/stop.sh"
else
    echo -e "\033[0;31m[SWARM]${NC} Nodo no respondió — ver logs con ./scripts/logs.sh"
fi
