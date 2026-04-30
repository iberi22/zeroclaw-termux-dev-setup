#!/bin/bash
# Healthcheck para Docker
set -Eeuo pipefail

# Verificar ZeroClaw gateway
if curl -sf "http://localhost:42617/health" &>/dev/null; then
    exit 0
fi

# Verificar SSH
if pgrep -x sshd &>/dev/null; then
    exit 0
fi

# Verificar que el proceso zeroclaw exista
if pgrep -x zeroclaw &>/dev/null; then
    exit 0
fi

exit 1
