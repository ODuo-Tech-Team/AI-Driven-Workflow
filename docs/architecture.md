# Arquitetura — AI-Driven Workflow

## Visão de 30 segundos

3 agentes Claude orquestrados por FastAPI + RQ, ligados a Linear (planejamento) e GitHub (código). Cada agente é um processo Python rodando dentro de um worker RQ, usa o Claude Agent SDK pra falar com a Anthropic e expõe métricas via logs estruturados.

```
         Linear                                    GitHub
            │ webhook                                 │ webhook + Action
            ▼                                         ▼
  ┌─────────────────┐                        ┌─────────────────┐
  │  FastAPI        │── enqueue ──►  Redis  ◄── poll ──│ RQ workers │
  │  routers/*      │                        │  agents/*       │
  └─────────────────┘                        └─────────────────┘
            │                                         │
            │ GraphQL                                 │ REST
            ▼                                         ▼
         Linear                                    GitHub
```

## Os 3 agentes

### PM Agent (Fase 1)

- **Trigger**: webhook Linear (`issue.created` com label `ai-pm`) ou `POST /api/pm/ideate`
- **Input**: ideia em linguagem natural + contexto opcional
- **Output**: Epic + issues filhas no Linear (com AC, contexto técnico, estimativa)
- **Tools do Claude**: `web_search` (nativo da Anthropic), leitura de GraphQL Linear pra pegar metadata do time
- **Risco**: baixo — só gera texto e metadata

### Executor Agent (Fase 2)

- **Trigger**: issue muda pra status `Ready for Dev` no Linear
- **Input**: issue Linear + repo alvo + branch base
- **Output**: branch + commits + PR draft no GitHub
- **Sandbox**: container Docker efêmero, FS isolado, sem rede arbitrária, sem secrets de produção
- **Hard gates**: `ruff check` + `pytest` precisam passar antes do PR abrir
- **Tools do Claude Agent SDK**: Read/Write/Edit, Bash (restrito via hooks `PreToolUse`), Glob, Grep
- **Risco**: ALTO — ponto mais frágil do projeto

### Reviewer Agent (Fase 3)

- **Trigger**: GitHub Actions `on: pull_request` chama `POST /api/reviewer/review`
- **Input**: PR URL + issue Linear linkada (via branch name `ai/issue-{id}`)
- **Output**: review inline no PR + decisão (approve / request_changes / need_human)
- **Loop**: Reviewer pede mudança → Executor re-roda → Reviewer revisa de novo. **Hard cap: 2 iterações.**
- **Escape hatch**: se CI estiver vermelho, nunca passa pra humano; se diff repetir 2x, encerra e flaga.

## Por que FastAPI + RQ e não n8n

| Critério | n8n | FastAPI + RQ |
|---|---|---|
| Prompts versionados | Difícil (blob em DB) | Trivial (`.md` no git) |
| Testes unitários | Praticamente zero | pytest nativo |
| Debug | UI opaca | logs estruturados + breakpoints |
| Deploy | Container extra pra manter | Junto com o resto |
| Vendor lock-in | Alto | Zero |
| Curva de aprendizado | Média (workflow visual) | Baixa pro time já usar FastAPI |

## Fluxo de um job (end-to-end)

1. Ideia entra via webhook Linear ou POST manual
2. FastAPI valida assinatura do webhook, cria `job_id`, enfileira na queue `default`
3. Worker RQ pega o job, carrega o prompt da fase correspondente em `prompts/<agent>/system.md`
4. Abre sessão com Claude Agent SDK, injeta contexto (issue, arquivos relevantes, AC)
5. Agent roda até completar ou bater `CLAUDE_BUDGET_USD_PER_JOB`
6. Resultado é persistido (Linear comment, PR draft, review)
7. `job_id` propaga end-to-end em todo log — rastreabilidade total

## Observabilidade

- **Logs**: `structlog` JSON, sempre com `job_id`, `agent`, `phase`, `cost_usd`, `tokens_in`, `tokens_out`
- **Tracing**: OpenTelemetry (Fase 0 plumbing, Fase 4 dashboard)
- **Métricas**: tempo por fase, custo por job, iterações Reviewer↔Executor, taxa de aprovação humana

## Deploy target

- **Backend**: VPS Hetzner (swarm cluster), stack `ai-workflow`, hostname temporário `ai-workflow.5.161.248.113.nip.io`
- **Frontend (Fase 4)**: Vercel free tier (Next.js dashboard)
- **CI/CD**: GitHub Actions → build image → push GHCR → SSH `docker stack deploy`

Ver `docs/deployment.md` pro passo-a-passo e `docs/operations/vps-manager-rules.md` pras regras de segurança da VPS compartilhada.
