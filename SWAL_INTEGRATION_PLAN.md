# ZeroClaw SWAL Agent — Plan de Integración

**Fecha:** 2026-04-19  
**Repo:** `iberi22/zeroclaw-termux-dev-setup`  
**Visión:** ZeroClaw como AGENTE CONTROLADO por OpenClaw — replica el ambiente OpenClaw

---

## Concepto

```
┌─────────────────────────────────────────────────────────────────┐
│  OpenClaw (esta sesión, EditorOne)                             │
│    ├── MEMORY.md, SOUL.md, AGENTS.md, USER.md                   │
│    ├── Skills: ~/clawd/skills/                                  │
│    └── Projects: E:\scripts-python\                             │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ MIGRACIÓN
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  ZeroClaw (Docker, controlado via HTTP API)                     │
│    ├── Gateway HTTP: http://localhost:42617                      │
│    ├── Workspace migrado (memoria, identidad)                    │
│    ├── Acceso lectura → OpenClaw workspace (SOUL, AGENTS, etc)   │
│    └── Acceso rw → Proyectos SWAL                               │
└─────────────────────────────────────────────────────────────────┘
```

Yo envío requests HTTP al gateway de ZeroClaw. ZeroClaw ejecuta con tools habilitadas, accede proyectos, reporta resultados.

---

## Workspace — Estructura de Mounts

```
HOST (Windows)                          DOCKER (ZeroClaw)
──────────────────────────────────────  ────────────────────────────────────
C:\Users\belal\.openclaw\workspace\       /openclaw-workspace (ro)
  ├── MEMORY.md                          # Memoria migrada
  ├── SOUL.md                            # Identidad del bot
  ├── AGENTS.md                          # Config de agentes
  ├── USER.md                            # Perfil CEO
  └── (skills/)

E:\scripts-python\                       /swal-projects (rw)
  ├── gestalt-rust/
  ├── zeroclaw/                          # Repo zeroclaw-termux-dev-setup
  ├── swal-skills/
  ├── agents-flows-recipes/
  ├── termux-dev-nvim-agents/
  └── isar_agent_memory/

                                        /zeroclaw-data/workspace/ (ZeroClaw workspace)
                                          # Memoria migrada va aquí
                                          # Skills SWAL van aquí
```

---

## Migración OpenClaw → ZeroClaw

ZeroClaw tiene `zeroclaw migrate openclaw` que lee:
1. `memory/brain.db` — SQLite de OpenClaw
2. `MEMORY.md` — memoria central en markdown
3. `memory/*.md` — entradas diarias

**Workspace de OpenClaw en EditorOne:**
```
C:\Users\belal\.openclaw\workspace\
├── MEMORY.md        ✅ (migrable)
├── AGENTS.md        ✅ (migrable - copiar manualmente)
├── IDENTITY.md      ✅ (migrable - copiar manualmente)
├── SOUL.md          ✅ (migrable - copiar manualmente)
├── USER.md          ✅ (migrable - copiar manualmente)
├── HEARTBEAT.md     ✅ (copiar manualmente)
├── TOOLS.md         ✅ (copiar manualmente)
└── (skills/)        ⚠️ ( skills de ~/clawd/skills/)
```

**Scripts:**
- `migrate-from-openclaw.sh` — Migra el workspace de OpenClaw
- `install-swal-node.sh` — Instala en Termux

---

## Gateway API — Endpoints

```
http://localhost:42617

GET  /health              Health check
GET  /status             Estado del agente
POST /v1/chat            Enviar mensaje
POST /v1/tools/execute    Ejecutar tool
GET  /v1/memory          Listar memoria
POST /v1/memory/store    Guardar en memoria
GET  /v1/skills          Listar skills
```

---

## Tool Calls — Fix Termux

El problema de Termux (tool call failures) se resuelve usando **ZeroClaw Docker** como proxy en vez de Gemini CLI directo.

En Termux (lento, rate-limited):
```
Gemini CLI → 429 rate limit, políticas, parsing errors
```

En Docker (zeroclaw como agente HTTP):
```
OpenClaw → HTTP → ZeroClaw Gateway → Tools → Repos
            └── retry logic automático
            └── rate limiting por provider
            └── todas las tools habilitadas
```

---

## Build & Run

```bash
cd E:\scripts-python\zeroclaw

# 1. Build imagen
docker build -f Dockerfile.swal -t swal-zeroclaw .

# 2. Migrar workspace de OpenClaw (dry-run primero)
./migrate-from-openclaw.sh --dry-run
./migrate-from-openclaw.sh --force

# 3. Iniciar agente
docker compose -f docker-compose.swal.yml up -d

# 4. Verificar
curl http://localhost:42617/health

# 5. Test — enviar mensaje
curl -X POST http://localhost:42617/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Ejecuta git status en /swal-projects/gestalt-rust"}'
```

---

## Fases

| Fase | Descripción | Estado |
|------|-------------|--------|
| 1 | Docker + Termux scripts | ✅ |
| 2 | Script de migración OpenClaw | ✅ |
| 3 | Gestalt Swarm como tool | Pendiente |
| 4 | Cortex memory backend | Pendiente |
| 5 | Skills SWAL → ZeroClaw | Pendiente |
| 6 | Fix tool calls (retry, rate limit) | Pendiente |

---

## Issues

- [ ] Build del Dockerfile.swal
- [ ] Test migración dry-run
- [ ] Verificar mount de OpenClaw workspace en Docker
- [ ] Probar HTTP API del gateway
- [ ] Integrar Cortex
- [ ] Gestalt Swarm
