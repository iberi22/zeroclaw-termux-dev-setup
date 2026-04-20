#!/bin/bash
# ZeroClaw startup script - runs zeroclaw daemon with exec to prevent fork exit
# This replaces the shell process, preventing container from exiting

set -euo pipefail

log() { echo "[ZEROCLAW-START] $1"; }

# Wait for config if needed
if [[ -f /zeroclaw/config.toml ]]; then
    log "Config found: /zeroclaw/config.toml"
else
    log "Warning: No config found at /zeroclaw/config.toml"
fi

log "Starting zeroclaw daemon..."

# Use exec to replace current process - critical for container not exiting
exec zeroclaw daemon "$@"
