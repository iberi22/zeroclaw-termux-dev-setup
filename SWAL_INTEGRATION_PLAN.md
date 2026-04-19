# ZeroClaw SWAL Agent — Plan de Integración

**Fecha:** 2026-04-19
**Repo:** `iberi22/zeroclaw-termux-dev-setup`
**Visión:** ZeroClaw como AGENTE CONTROLADO por OpenClaw via HTTP API

---

## Concepto

```
OpenClaw (esta sesión) ──HTTP──> ZeroClaw Gateway (Docker)
                                      │
                                      ├── Ejecuta tools (shell, git, file)
                                      ├── Accede a proyectos (workspace)
                                      └── Memoria → Cortex
```

ZeroClaw corre en Docker. OpenClaw le envía tasks via REST API (gateway port 42617). ZeroClaw las ejecuta con todas las tools habilitadas, accediendo a los proyectos montados.

---

## Arquitectura

### Workspace mounting

```
Host: E:\scripts-python\
  └── zeroclaw/              ← repo zeroclaw-termux-dev-setup
        docker-compose.swal.yml
        Dockerfile.swal
  └── projects/               ← TODOS los proyectos SWAL (montado como volume)
        gestalt-rust/
        swal-skills/
        agents-flows-recipes/
        termux-dev-nvim-agents/
        isar_agent_memory/
        ...más
```

En Docker: `/zeroclaw-data/workspace` = `E:\scripts-python\` (directorio padre)

### Gateway API

```
http://localhost:42617
```

Endpoints útiles:
- `POST /v1/chat` — Enviar mensaje al agente
- `POST /v1/tools/execute` — Ejecutar tool específica
- `GET /health` — Health check
- `GET /status` — Estado del agente

---

## Herramientas Habilitadas

| Tool | Descripción | Estado |
|------|-------------|--------|
| shell | Ejecutar comandos bash/powershell | ✅ |
| git | Git operations | ✅ |
| file_read | Leer archivos | ✅ |
| file_write | Escribir archivos | ✅ |
| file_edit | Editar archivos | ✅ |
| glob_search | Buscar archivos | ✅ |
| web_search | Búsqueda web | ✅ |
| web_fetch | Fetch URLs | ✅ |
| calculator | Calculadora | ✅ |
| memory_recall | Cortex recall | ✅ |
| memory_store | Cortex store | ✅ |

---

## Flujo de Trabajo

1. **Build:** `docker build -f Dockerfile.swal -t swal-zeroclaw .`
2. **Start:** `docker compose -f docker-compose.swal.yml up -d`
3. **Yo envío tasks via HTTP** al gateway
4. **ZeroClaw ejecuta** con tools → accede proyectos
5. **Resultado vuelve** a mí → reporto

---

## Tool Calls — Fix Termux

El problema de Termux (tool call failures) se resuelve:
1. Usar ZeroClaw Docker como proxy (no Gemini CLI directo)
2. Configurar `reliable.rs` retry con exponential backoff
3. Rate limiting por provider
4. Verificar `ZEROCLAW_ALLOW_*` flags

---

## Issues Pendientes

- [ ] Test HTTP API del gateway (curl /health, /status)
- [ ] Verificar mount de workspace con proyectos
- [ ] Configurar tools allowlist correctamente
- [ ] Test shell execution desde OpenClaw → ZeroClaw
- [ ] Integrar Cortex memory (ZeroClaw → Cortex API)
- [ ] FASE 3: Gestalt Swarm como tool

---

## Quick Start

```bash
cd E:\scripts-python\zeroclaw

# 1. Copiar y editar env
cp env.swal.example .env.swal
# Editar .env.swal → añadir API_KEY

# 2. Build
docker build -f Dockerfile.swal -t swal-zeroclaw .

# 3. Start (sin cortex si ya corre en host)
docker compose -f docker-compose.swal.yml up -d

# 4. Verificar
curl http://localhost:42617/health

# 5. Enviar mensaje al agente
curl -X POST http://localhost:42617/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Ejecuta git status en gestalt-rust"}'
```
