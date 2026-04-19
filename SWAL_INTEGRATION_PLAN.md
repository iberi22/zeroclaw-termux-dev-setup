# ZeroClaw SWAL Node — Plan de Integración

**Fecha:** 2026-04-19  
**Proyecto:** SWAL Node con ZeroClaw + Gestalt Rust + Cortex  
**Repo:** `iberi22/zeroclaw-termux-dev-setup`

---

## Arquitectura Actual del Fork

El fork `iberi22/zeroclaw-termux-dev-setup` (v0.7.1) es una reimplementación completa con workspace de 16 crates:

```
zeroclaw-api           — API traits y tipos core
zeroclaw-infra         — Infraestructura compartida
zeroclaw-config        — Sistema de configuración
zeroclaw-providers     — 20+ providers (OpenAI, Anthropic, Gemini CLI, Ollama, etc.)
zeroclaw-memory        — SQLite, Qdrant, Knowledge Graph, Embeddings
zeroclaw-channels      — Telegram, Discord, Nostr, Matrix, Feishu
zeroclaw-tools         — Tool execution surface
zeroclaw-runtime       — Runtime adapters
zeroclaw-gateway       — HTTP webhook server
zeroclaw-tui           — Terminal UI
zeroclaw-plugins       — Plugin system
zeroclaw-hardware      — Periféricos hardware
zeroclaw-tool-call-parser — Parser de tool calls
```

**Módulos propios agregados:**
- `src/nodes` — Sistema de nodos distribuidos
- `src/hands` — Sistema de herramientas avanzado
- `src/routines` — Tareas programadas
- `src/skillforge` — Forja de skills
- `src/marketplace` — Marketplace de skills
- `src/platform` — Configuración de plataforma
- `src/trust` — Sistema de confianza/permisos
- `src/verifiable_intent` — Intenciones verificables

---

## Plan de Integración SWAL

### FASE 1: Docker Node para SWAL ✅ (Esta sesión)
- [ ] `docker-compose.swal.yml` — Docker Compose para SWAL node
- [ ] `Dockerfile.swal` — Dockerfile optimizado para SWAL con Gestalt
- [ ] Variables de entorno para Cortex, Gestalt, OpenClaw bridge
- [ ]Puerto y networking configurables

### FASE 2: Script de Instalación Termux ✅ (Esta sesión)
- [ ] `install-swal-node.sh` — Script de instalación para Termux
- [ ] Soporte para ZeroClaw + Gestalt Swarm CLI
- [ ] Integración con el existing `termux-dev-nvim-agents`
- [ ] API keys configurables

### FASE 3: Integración Gestalt Swarm ⚙️
- [ ] Crear `crates/zeroclaw-gestalt` — Bridge hacia Gestalt Swarm
- [ ] Exponer `gestalt_swarm` como tool en ZeroClaw
- [ ] API endpoint en gateway para gestión de swarm
- [ ] Soporte para `swarm` subcommand en CLI

### FASE 4: Integración Cortex Memory ⚙️
- [ ] Crear `crates/zeroclaw-cortex` — Backend de memoria Cortex
- [ ] Implementar `Memory` trait para Cortex HTTP API
- [ ] Configuración de URL/token de Cortex en config
- [ ] Sync bidireccional con memoria local de ZeroClaw

### FASE 5: Integración Skills SWAL ⚙️
- [ ] Asegurar compatibilidad de skills OpenClaw → ZeroClaw
- [ ] Importar skills de `iberi22/swal-skills`
- [ ] Skill de Gestalt Swarm (`gestalt-swarm` skill)
- [ ] Skill de Cortex Memory (`cortex-memory` skill)

### FASE 6: Fix de Tool Calls en Termux 🔧
- [ ] Diagnosticar problemas de tool calls en Termux
- [ ] 添加 retry logic y exponential backoff
- [ ] Mejorar parsing de tool calls del Gemini CLI
- [ ] Policy de Rate limiting para evitar 429s

---

## Comparativa: OpenClaw vs ZeroClaw vs Objetivo SWAL

| Feature | OpenClaw | ZeroClaw (fork) | Objetivo SWAL |
|---------|----------|-----------------|----------------|
| Lenguaje | TypeScript/Node | Rust | Rust |
| RAM | >1GB | <5MB | <10MB |
| Startup | >500ms | <10ms | <50ms |
| Skills | SKILL.md | SKILL.md/SKILL.toml | SKILL.md |
| Memory | Cortex | SQLite/Qdrant | Cortex + SQLite |
| Swarm | Gestalt Rust | No | Sí (integrado) |
| Channels | Telegram, etc. | Multi | Todos + custom |
| Tool calls | Buenos | Buenos | Mejorados |
| Docker | Nativo | Multi-stage | SWAL-optimized |

---

## Tool Calls en Termux — Diagnóstico

**Problemas reportados:**
1. Gemini CLI tiene políticas de rate limiting estrictas
2. Configuraciones de políticas interfieren
3. Muchos tool call failures vs OpenClaw

**Causas probables:**
- Gemini CLI en Termux usa OAuth con scopes limitados
- El thin client de Termux tiene problemas de parsing de respuestas largas
- Falta de retry/timeout configurable

**Soluciones:**
1. Implementar `gemini_cli` provider con retry logic robusto
2. Usar `zeroclaw` como proxy local para batching de requests
3. Configurar `trust.level` y `autonomy` para reducir tool calls innecesarios
4. Añadir `rate_limit` y `timeout` configurables por provider

---

## Docker Setup — SWAL Node

```yaml
# docker-compose.swal.yml
services:
  zeroclaw-swal:
    build:
      context: .
      dockerfile: Dockerfile.swal
    container_name: swal-zeroclaw-node
    environment:
      - API_KEY=${API_KEY}
      - CORTEX_URL=http://cortex:8003
      - CORTEX_TOKEN=dev-token
      - GESTALT_SWARM_PATH=/app/gestalt
      - ZEROCLAW_GATEWAY_PORT=42617
      - PROVIDER=openrouter
      - DEFAULT_MODEL=${DEFAULT_MODEL:-anthropic/claude-sonnet-4-20250514}
    ports:
      - "42617:42617"
    volumes:
      - swal-workspace:/zeroclaw-data/workspace
      - swal-config:/zeroclaw-data/.zeroclaw
      - gestalt-binaries:/app/gestalt
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
```

---

## Puerto y Configuración de Red

- **ZeroClaw Gateway:** 42617 (configurable)
- **Gestalt Swarm CLI:** puerto dinámico
- **Cortex API:** http://localhost:8003
- **Telegram Bot:** configurable via bot token
- **Nostr:** configurable

---

## Credentials (Cortex + Providers)

```toml
# ~/.zeroclaw/.zeroclaw/config.swal.toml
[cortex]
url = "http://localhost:8003"
token = "dev-token"
enabled = true

[gestalt]
swarm_path = "~/.local/bin/gestalt_swarm"
enabled = false  # Activar cuando esté integrado

[providers.gemini_cli]
enabled = true
model = "gemini-2.5-flash"
oauth_cache = "~/.gemini-oauth-cache"
rate_limit_rpm = 30

[providers.openrouter]
enabled = true
```

---

## Flags de Build Recomendados

```bash
# Features para SWAL node
ZEROCLAW_CARGO_FEATURES="channel-lark,whatsapp-web,channel-nostr"
# Incluir:
# - gestalt integration (próximamente)
# - cortex memory backend (próximamente)
```
