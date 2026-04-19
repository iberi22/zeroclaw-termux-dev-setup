# ZeroClaw SWAN Node — Setup Completo

> Setup completo para replicar el entorno de desarrollo ZeroClaw + todas las tools SWAL.

**Uso:**
```bash
# Docker
curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/master/bootstrap.sh | bash

# Termux
curl -fsSL https://raw.githubusercontent.com/iberi22/zeroclaw-termux-dev-setup/master/install-swal-node.sh | bash
```

## Estructura
```
├── bootstrap.sh           # Docker bootstrap
├── install-swal-node.sh  # Termux installer completo
├── Dockerfile.swal        # Imagen Docker con TODAS las tools
├── docker-compose.swal.yml # Nodo + workspace compartido
├── swan-scripts/          # Scripts de control
│   ├── start.sh / stop.sh / status.sh / logs.sh
│   ├── replicate.sh      # Clonar nodo en otra maquina
│   ├── entrypoint.sh
│   └── healthcheck.sh
└── env.swal.example      # Template de variables
```

## CLI Agents Instalados
| Agent | Descripcion |
|-------|-------------|
| ZeroClaw + Gestalt Swarm | Gateway + orchestrator |
| Jules | Google's autonomous coding (iberi22/*) |
| Claude Code | Anthropic coding agent |
| OpenCode | MiniMax/M2.7 agent |
| Gemini CLI | Google's CLI agent |
| Qwen CLI | Alibaba coding agent |

## Infrastructure CLIs
| CLI | Descripcion |
|-----|-------------|
| Supabase CLI | DB, Auth, Edge Functions, D1 |
| AWS CLI | EC2, S3, Lambda |
| GCP (gcloud) | Cloud Run, GKE, BigQuery |
| Cloudflare Wrangler | Workers, Pages, R2 |
| Terraform | Infrastructure as Code |
| Pulumi | IaC con codigo |

## Development Tools
| Categoria | Tools |
|-----------|-------|
| Python | fastapi, langchain, pandas, pytest, playwright |
| Node.js | typescript, ts-node, pnpm, yarn |
| Go | golangci-lint, swag |
| Rust/Cargo | cargo-edit, cargo-watch |
| Databases | sqlite3, postgresql, redis |
| Build | cmake, ninja, clang |

## Instalacion

### Docker
```bash
cp env.swal.example .env
# Editar .env -> API_KEY
./swan-scripts/start.sh
```

### Termux
```bash
# Todos los agents
SWAL_INSTALL_ALL=1 bash install-swal-node.sh

# Especifico
SWAL_INSTALL_JULES=1 SWAL_INSTALL_AWS=1 bash install-swal-node.sh
```

## Workspace Compartido con OpenClaw
- Host: `~/.openclaw/workspace` -> Docker: `/zeroclaw/workspace`
- Comparten MEMORY.md, SOUL.md, AGENTS.md

## SSH
- Docker: puerto 2222
- Termux: puerto 8022
