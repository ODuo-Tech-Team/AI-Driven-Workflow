# Fase 0 — Setup de infra, skeleton e CI/CD

Fase invisível no plano original do chefe, mas essencial. Sem ela, qualquer coisa que a gente fizer depois vai ser instável, inauditável e inseguro.

## Objetivo

Ter um repo Python 3.12 + FastAPI vivo, com CI rodando, stack Docker Swarm pronto pra deploy, observability baseline e contrato de segurança claro com a VPS de produção compartilhada.

## Checklist

### Repositório

- [x] Repo `ODuo-Tech-Team/AI-Driven-Workflow` clonado
- [x] README.md com visão geral
- [x] CLAUDE.md com instruções pro Claude Code
- [x] `.gitignore`, `.python-version`, `.env.example`, `.dockerignore`
- [x] `pyproject.toml` com deps + Ruff + pytest config (uv managed)
- [x] Skeleton `src/ai_workflow/` com `main.py`, `config.py`, `routers/health.py`
- [x] Smoke test `tests/test_health.py`
- [ ] Primeiro commit + push pra `main`
- [ ] Branch protection em `main` (require PR + required reviews + status checks)

### Docker / Infra

- [x] `Dockerfile` multi-stage (builder + runtime) com uv
- [x] `docker-compose.dev.yml` pra dev local com hot reload
- [x] `docker-stack.yml` pra Swarm stack com Traefik labels, resource limits, secrets externos
- [x] VPS manager acessível via `ssh ai-workflow-manager` (chave ed25519, config local)
- [x] Namespace `/mnt/arquivo_midias/ai-workflow/{data,logs,tmp,backups}` criado na VPS
- [ ] Secrets externos criados na VPS (`docker secret create ai-workflow_*`)
- [ ] Network `ai-workflow_internal` criada (automático via `docker stack deploy`)
- [ ] Primeira deploy de smoke test: `/health` respondendo via `https://ai-workflow.5.161.248.113.nip.io/health`

### CI/CD

- [x] GitHub Actions workflow `ci.yml` (lint + test + docker build)
- [ ] Deploy job (SSH → `docker stack deploy`) — depende de secrets no GitHub Actions
- [ ] Secrets no repo: `ANTHROPIC_API_KEY`, `LINEAR_API_KEY`, `LINEAR_WEBHOOK_SECRET`, `GITHUB_WEBHOOK_SECRET`, `SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER`
- [ ] PR template + issue templates
- [x] PR template
- [x] Issue templates (bug / feature)

### Observability baseline

- [ ] `structlog` configurado com JSON output e `job_id` middleware
- [ ] OpenTelemetry instrumentação básica (FastAPI auto-instrument)
- [ ] Log shipping — decidir depois (Loki? Datadog? stdout só por agora?)

### Segurança / guardrails

- [x] Contrato de segurança da VPS em `docs/operations/vps-manager-rules.md`
- [ ] gitleaks pre-commit hook (pra quando o Executor clonar repos alvo)
- [ ] semgrep config no CI
- [ ] Budget hard cap por job implementado no config (`CLAUDE_BUDGET_USD_PER_JOB=2.0`)
- [x] Budget valor definido no `.env.example`

### Docs

- [x] `docs/architecture.md`
- [x] `docs/phase-0.md` (este arquivo)
- [x] `docs/deployment.md`
- [x] `docs/operations/vps-manager-rules.md`
- [x] `docs/decisions/0001-deploy-target-and-infra.md`
- [x] `docs/decisions/0002-runtime-stack.md`

## O que NÃO é Fase 0

- Código de agente (PM, Executor, Reviewer) — Fases 1, 2, 3
- Integração Linear / GitHub (além de webhooks stub) — Fases 1 e 2
- Sandbox Docker efêmero pro Executor — início da Fase 2
- Dashboard de métricas — Fase 4

## Bloqueadores

Nenhum pra Fase 0 ou Fase 1. Único pendente é **acesso ao monorepo de produção** pra Fase 2 (Executor clonar em runtime).

## Critério de "Fase 0 está pronta"

1. CI verde no primeiro PR
2. Deploy manual via SSH funcionou pelo menos uma vez
3. `https://ai-workflow.5.161.248.113.nip.io/health` retorna `{"status":"ok"}`
4. Branch protection ativa em `main`
5. Contrato de segurança da VPS revisado pelo Mauri
