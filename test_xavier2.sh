#!/bin/bash
# =============================================================================
# Xavier2 Remote Test — Termux to PC
# =============================================================================
TERMUX_V="2026-04-25.1"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

PC_HOST="${1:-192.168.1.2}"
XAV_PORT="${2:-8006}"
TOKEN="dev-token"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN} 🧠 Xavier2 Remote Test (PC: $PC_HOST:$XAV_PORT)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Health check
echo -e "${CYAN}1) Health Check${NC}"
health=$(curl -sf "http://$PC_HOST:$XAV_PORT/health" 2>/dev/null || echo '{"status":"error"}')
if [[ "$health" == *'"ok"'* ]]; then
    version=$(echo "$health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','?'))" 2>/dev/null || echo "?")
    service=$(echo "$health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('service','?'))" 2>/dev/null || echo "?")
    echo -e "  Health:  ${GREEN}✅ RUNNING${NC}"
    echo "  Service: $service"
    echo "  Version: $version"
else
    echo -e "  Health:  ${RED}❌ NOT REACHABLE${NC}"
    echo "  Tried:   http://$PC_HOST:$XAV_PORT/health"
    exit 1
fi
echo ""

# Memory search test
echo -e "${CYAN}2) Memory Search Test${NC}"
# Write JSON to a file first to avoid shell escaping issues
cat > /data/data/com.termux/files/home/search_body.json << 'EOJSON'
{"query":"SWAL Leonardo ManteniApp","limit":3}
EOJSON

result=$(curl -sf -X POST "http://$PC_HOST:$XAV_PORT/memory/search" \
    -H "Content-Type: application/json" \
    -H "X-Xavier2-Token: $TOKEN" \
    --data-binary @/data/data/com.termux/files/home/search_body.json 2>/dev/null || echo '{}')

status_text=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','error'))" 2>/dev/null || echo "unknown")
count=$(echo "$result" | python3 -c "import sys,json; r=json.load(sys.stdin).get('results',[]); print(len(r))" 2>/dev/null || echo "?")

echo -e "  Query:   ${YELLOW}SWAL Leonardo ManteniApp${NC}"
echo -e "  Status:  $status_text"
echo -e "  Results: $count"
echo ""

# Show result content if available
if [[ "$count" != "?" && "$count" != "0" && "$count" != "unknown" ]]; then
    echo -e "${CYAN}3) Results Preview${NC}"
    echo "$result" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for i,r in enumerate(d.get('results',[])):
    content=r.get('content','')[:120]
    print(f'  [{i+1}] {content}...')
" 2>/dev/null || echo "  (parse error)"
else
    echo -e "${CYAN}3) Results Preview${NC}"
    echo "  (no results or parse error)"
    echo "  Raw: $result"
fi

echo ""
rm -f /data/data/com.termux/files/home/search_body.json
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Token used: $TOKEN"
echo "  PC IP: $PC_HOST"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
