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
- [x] Primeiro commit + push pra `main`
- [x] Branch protection em `main` (require PR + required reviews + status checks) — 2 required checks (Lint+Test, Docker build), 1 reviewer, linear history, admin bypass permitido pra manutenção

### Docker / Infra

- [x] `Dockerfile` multi-stage (builder + runtime) com uv
- [x] `docker-compose.dev.yml` pra dev local com hot reload
- [x] `docker-stack.yml` pra Swarm stack com Traefik labels, resource limits, secrets externos
- [x] VPS manager acessível via `ssh ai-workflow-manager` (chave ed25519, config local)
- [x] Namespace `/mnt/arquivo_midias/ai-workflow/{data,logs,tmp,backups}` criado na VPS
- [x] Secrets externos criados na VPS (`docker secret create ai-workflow_*`) — 5 secrets placeholder (`anthropic_api_key`, `linear_api_key`, `linear_webhook_secret`, `github_token`, `github_webhook_secret`), valor `PLACEHOLDER_PHASE0_REPLACE_BEFORE_PHASE1`
- [x] Network `ai-workflow_internal` criada (automático via `docker stack deploy`)
- [x] Primeira deploy de smoke test: `/health` respondendo via `https://ai-workflow.5.161.248.113.nip.io/health` — HTTP 200, cert Let's Encrypt válido, api + redis + worker todos 1/1

### CI/CD

- [x] GitHub Actions workflow `ci.yml` (lint + test + docker build + push pra GHCR no main) — imagem tagueada como `:latest` e `:sha-<short>`
- [ ] Deploy job (SSH → `docker stack deploy`) — adiado pra Fase 1, depende de chave SSH dedicada pra GH Actions (hoje o deploy é manual via `./scripts/deploy.sh` da máquina do Mauri)
- [ ] Secrets no repo: `ANTHROPIC_API_KEY`, `LINEAR_API_KEY`, `LINEAR_WEBHOOK_SECRET`, `GITHUB_WEBHOOK_SECRET`, `SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER` — adiado pra Fase 1
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

1. CI verde no primeiro PR — **OK** (CI verde no primeiro push direto após admin bypass, PRs futuros vão passar pelas mesmas gates)
2. Deploy manual via SSH funcionou pelo menos uma vez — **OK** (`./scripts/deploy.sh` rodou, stack deployada)
3. `https://ai-workflow.5.161.248.113.nip.io/health` retorna `{"status":"ok"}` — **OK** (HTTP 200, cert válido)
4. Branch protection ativa em `main` — **OK**
5. Contrato de segurança da VPS revisado pelo Mauri — **pendente revisão final**

## Status de fechamento (2026-04-10)

Fase 0 está **funcionalmente pronta**. O que ficou pra fora:

- **Rotação de credenciais (Mauri)**: PAT `ghp_AAKy...Mrpke` e senha root SSH da VPS vazaram no chat e precisam ser rotacionados. Depois da rotação, rodar `rm /root/.docker/config.json` na VPS pra limpar o PAT cacheado no login do GHCR. MauMau não toca em rotação de credenciais sem ordem explícita.
- **Observability baseline, gitleaks, semgrep, budget hard cap**: empurrados pra começo da Fase 1. Não são blockers do skeleton.
- **Secrets reais (Anthropic, Linear, GitHub webhook)**: placeholders na VPS esperando os valores reais pra trocar via `docker secret rm` + `docker secret create`. Isso é pré-requisito de Fase 1, não de Fase 0.

### Infra bugs encontrados e corrigidos durante o fechamento

- `restart_policy: on-failure` + RQ worker = 0/1 permanente. RQ sai exit 0 em SIGTERM (warm shutdown), `on-failure` ignora. Fix: `restart_policy.condition: any` no worker.
- `HEALTHCHECK` no `Dockerfile` é herdado por todos os containers da imagem. Worker usa a mesma imagem mas roda `rq worker` (sem uvicorn na :8000), então o probe falhava sempre e Swarm matava ~75s depois do start. Fix: `healthcheck.disable: true` no service do worker (sem mexer no Dockerfile, API ainda precisa dele).
- Bind mounts em Swarm multi-node exigem `placement.constraints: [node.role == manager]` em todo service que usa `/mnt/arquivo_midias/ai-workflow/*`, senão Swarm escalona em worker nodes onde o path não existe e task fica `Rejected`.
- `Dockerfile` precisa de `COPY README.md ./` antes de `COPY src ./src` porque `pyproject.toml` declara `readme = "README.md"` e hatchling tenta ler no build.
