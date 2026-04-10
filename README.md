# AI-Driven Workflow

Orquestrador de 3 agentes Claude que transforma uma ideia num PR revisado, ligando **Linear + GitHub + Claude** via **FastAPI + Claude Agent SDK**.

## Os 3 agentes

| Agent | Entrada | Saída | Status |
|---|---|---|---|
| **PM Agent** | Ideia (Linear webhook ou POST) | Epic + issues filhas no Linear com AC, contexto, estimativa | Fase 1 |
| **Executor Agent** | Issue em `Ready for Dev` | Branch + código + PR draft no GitHub (lint + test passando) | Fase 2 |
| **Reviewer Agent** | PR aberto | Review inline + iterações com Executor (max 2) ou flag pra humano | Fase 3 |

## Stack

- **Runtime**: Python 3.12
- **Package manager**: [uv](https://docs.astral.sh/uv/)
- **API**: FastAPI + Uvicorn
- **Queue**: RQ + Redis
- **Agents**: [Claude Agent SDK (Python)](https://github.com/anthropics/claude-agent-sdk-python)
- **Lint/format**: Ruff
- **Tests**: pytest
- **Container**: Docker (Swarm stack em produção)
- **Reverse proxy**: Traefik existente (na VPS de deploy)

## Estrutura

```
.
├── src/ai_workflow/        # Código da aplicação
│   ├── main.py             # FastAPI app + lifespan
│   ├── config.py           # Settings via pydantic-settings
│   └── routers/            # Endpoints (health, webhooks, api)
├── tests/                  # pytest
├── docs/
│   ├── architecture.md     # Diagrama e fluxo dos 3 agentes
│   ├── phase-0.md          # Plano detalhado da Fase 0 (setup)
│   ├── deployment.md       # Como fazer deploy no alvo
│   ├── operations/         # Runbooks
│   └── decisions/          # ADRs (Architecture Decision Records)
├── Dockerfile              # Multi-stage build
├── docker-stack.yml        # Swarm stack com Traefik labels (produção)
├── docker-compose.dev.yml  # Dev local com hot reload
├── pyproject.toml          # uv-managed, deps + ruff/pytest config
└── scripts/                # dev-up.sh, deploy.sh
```

## Quick start (dev local)

```bash
# 1. Clone e entra no repo
git clone https://github.com/ODuo-Tech-Team/AI-Driven-Workflow.git
cd AI-Driven-Workflow

# 2. Copia env vars e preenche
cp .env.example .env
# edita .env com suas chaves

# 3. Sobe stack local (Redis + FastAPI com hot reload)
./scripts/dev-up.sh

# 4. Abre http://localhost:8000/health
```

## Status atual

**Fase 0 — Setup de infra, skeleton e CI/CD.**

Leia [`docs/phase-0.md`](docs/phase-0.md) pra ver o que tá pronto e o que falta. Cada fase tem seu próprio doc em `docs/`.

## Decisões-chave

Ver [`docs/decisions/`](docs/decisions/) pros ADRs. Resumão:

1. **Sem n8n** — FastAPI + Claude Agent SDK diretos, prompts versionados como código.
2. **Repo dedicado** (não dentro do monorepo do produto) — isolamento total durante dev.
3. **Deploy em Docker Swarm stack** na VPS Hetzner existente, integrando com Traefik via labels.
4. **Python 3.12 + uv + Ruff** — tooling moderno e rápido.

## Licença

Propriedade da Oduo Tech Team. Uso interno.
