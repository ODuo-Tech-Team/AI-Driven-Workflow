# CLAUDE.md — AI-Driven Workflow (repo)

Instruções pro Claude Code quando estiver trabalhando dentro deste repositório.

## Contexto

Este repo é o **orquestrador** (não o produto alvo). Roda 3 agentes Claude (PM, Executor, Reviewer) que ligam Linear ↔ GitHub. Stack: Python 3.12 + FastAPI + RQ + Claude Agent SDK. Deploy via Docker Swarm stack na VPS Hetzner.

Leitura obrigatória antes de editar qualquer coisa:
- `README.md` — visão geral
- `docs/architecture.md` — diagrama dos 3 agentes
- `docs/phase-0.md` — o que tá pronto e o que falta nesta fase
- `docs/decisions/` — ADRs com o "porquê" das decisões-chave
- `docs/operations/vps-manager-rules.md` — contrato de segurança da VPS de produção

## Regras de ouro

1. **NÃO usar n8n.** Decisão cravada. Só reabrir com justificativa técnica forte.
2. **Nunca tocar em services/containers/volumes alheios** na VPS manager. Escopo nosso: namespace `ai-workflow_*` + volume `/mnt/arquivo_midias/ai-workflow/`. Ver `docs/operations/vps-manager-rules.md`.
3. **Nada de `docker compose up`** em produção — a VPS roda Swarm. Use `docker stack deploy`.
4. **Toda mudança de infra passa por PR.** Nada de editar stack em produção direto por SSH.
5. **Hard cap de 2 iterações** no loop Reviewer↔Executor. Não aumentar sem discutir.
6. **PRs do Executor sempre `draft: true`.** Humano promove.
7. **Secrets NUNCA em código** — usar variáveis de ambiente ou Docker secrets.
8. **Limites de recurso obrigatórios** em todo service do stack. Sem limite = kill no review.

## Stack e tooling

| Camada | Tech | Comando |
|---|---|---|
| Deps | uv | `uv sync`, `uv add <pkg>` |
| Lint/format | Ruff | `uv run ruff check .`, `uv run ruff format .` |
| Tests | pytest | `uv run pytest` |
| Type check | (opcional) mypy | `uv run mypy src` |
| Run local | Uvicorn | `uv run uvicorn ai_workflow.main:app --reload` |
| Stack local | Docker Compose | `./scripts/dev-up.sh` |
| Deploy prod | Docker Swarm | `./scripts/deploy.sh` (chama `docker stack deploy`) |

Versão do Python: **3.12** (fixada em `.python-version`).

## Layout

```
src/ai_workflow/       # Código da aplicação
  main.py              # FastAPI app + lifespan
  config.py            # Settings via pydantic-settings
  routers/             # Endpoints FastAPI (health, webhooks, api)
  agents/              # PM, Executor, Reviewer (Fases 1-3)
  integrations/        # Linear, GitHub, Claude (Fases 1-3)
  queue/               # RQ workers (Fase 2+)
  prompts/             # System prompts versionados em .md (Fases 1-3)
tests/                 # pytest
docs/                  # architecture, phase-N, operations, decisions
```

## Antes de commitar

1. `uv run ruff check .` deve passar
2. `uv run ruff format --check .` deve passar
3. `uv run pytest` deve passar
4. Mensagem de commit segue Conventional Commits: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `ci:`, `test:`

## Ambiente de deploy

- **Produção**: VPS manager Hetzner (`ssh ai-workflow-manager`), Docker Swarm stack, hostname temporário `ai-workflow.5.161.248.113.nip.io` (nip.io enquanto não temos domínio real).
- **Dev local**: `docker-compose.dev.yml` com hot reload (Redis + FastAPI).
- **CI**: GitHub Actions em `.github/workflows/ci.yml` — roda lint + test em todo PR.

## Quando estiver em dúvida

Pergunta antes de:
- Tocar em qualquer coisa fora do namespace `ai-workflow` na VPS
- Mudar resource limits, networks ou volumes no `docker-stack.yml`
- Adicionar dependência nova ao `pyproject.toml`
- Mudar o system prompt de um agente
- Aumentar o hard cap de iterações do Reviewer
