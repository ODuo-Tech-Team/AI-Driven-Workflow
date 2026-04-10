# ADR 0002 — Runtime stack e tooling

- **Data**: 2026-04-10
- **Status**: Aceito
- **Contexto**: Fase 0

## Contexto

Precisamos escolher linguagem, framework, gerenciador de pacotes e tooling de qualidade. Restrições:
- Time Oduo já usa Python + FastAPI no produto principal
- Claude Agent SDK tem SDK oficial Python (e TypeScript)
- CI do produto alvo usa Flake8

## Decisão

| Camada | Escolha |
|---|---|
| Linguagem | **Python 3.12** |
| Web framework | **FastAPI** (>= 0.115) |
| Package manager | **uv** (Astral) |
| Lint + format | **Ruff** (Astral) |
| Tests | **pytest** + pytest-asyncio |
| Queue | **RQ** (Redis Queue) |
| Config | **pydantic-settings** v2 |
| HTTP client | **httpx** |
| Agent runtime | **claude-agent-sdk** (Python) |
| Logs | **structlog** |
| Retry | **tenacity** |

## Justificativa

### Python 3.12 (não 3.11 nem 3.13)
- 3.12 é LTS prático, estável, amplamente suportado
- Type hints melhores que 3.11 (`type` statement, f-string parser novo)
- 3.13 muito novo, alguns pacotes ainda não suportam

### FastAPI (não Flask/Django)
- Async nativo, essencial pra webhook receiver + agent runtime
- Pydantic models = validação de entrada grátis e type-safe
- Lifespan context manager pra recursos long-lived (Redis pool, HTTP clients)
- Time já conhece

### uv (não pip/poetry/pipenv)
- 10-100x mais rápido que poetry em install
- Lockfile `uv.lock` determinístico
- Sync de venv trivial
- Compatível com `pyproject.toml` PEP 621 padrão
- Astral é o time do Ruff — mesma qualidade de engenharia

### Ruff (não Flake8 + black + isort)
- Substitui Flake8, black, isort, pyupgrade, etc num binário só
- ~100x mais rápido que qualquer um deles
- Regras do Flake8 estão todas lá (o produto alvo usa Flake8 — compatibilidade total)
- Format + lint no mesmo tool

### RQ (não Celery nem arq)
- API simples, fácil de debugar
- Redis-only (já temos Redis, sem broker extra tipo RabbitMQ)
- Celery é overkill pra 3 agentes e ~dezenas de jobs/dia
- arq é mais novo mas menos maduro

### claude-agent-sdk Python
- SDK oficial da Anthropic (`pip install claude-agent-sdk`)
- Bundled com Claude Code CLI → mesma engine que a gente usa no dev
- Hooks system (`PreToolUse`, `PostToolUse`) pra deterministic guardrails
- `query()` async iterator + `ClaudeSDKClient` pra sessões de longa duração
- Evita reinventar tooling que o Claude Code já tem pronto

## Consequências

### Positivas
- Stack moderna e rápida
- Tempo de install local < 10s com uv
- Ruff roda em <1s em todo o projeto
- Consistência com produto alvo (Python + FastAPI + Flake8-compat)

### Negativas
- uv é relativamente novo (mas estável desde 0.4.x)
- `claude-agent-sdk` é API nova, pode ter breaking changes (pinning rigoroso no lockfile)
- RQ não tem retry automático robusto — a gente implementa com `tenacity` no call site

## Revisão futura

- Se `claude-agent-sdk` Python quebrar muito: considerar TypeScript SDK ou chamadas raw pra Anthropic API
- Se RQ virar gargalo: migrar pra arq ou Temporal
- Python 3.13 quando a maioria das deps suportar
