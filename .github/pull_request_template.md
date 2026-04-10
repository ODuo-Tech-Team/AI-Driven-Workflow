## O que muda

<!-- Descreva em 1-3 bullets. Foque no "porquê". -->

## Fase / escopo

<!-- Marque a fase que esse PR toca. -->
- [ ] Fase 0 — Setup
- [ ] Fase 1 — PM Agent
- [ ] Fase 2 — Executor Agent
- [ ] Fase 3 — Reviewer Agent
- [ ] Fase 4 — Polish
- [ ] Outro (ops, docs, infra)

## Checklist

- [ ] `uv run ruff check .` passa
- [ ] `uv run ruff format --check .` passa
- [ ] `uv run pytest` passa
- [ ] Não introduz secrets em código
- [ ] Se mexeu em `docker-stack.yml`: resource limits continuam definidos
- [ ] Se mexeu em prompt de agente: ADR ou nota no PR explicando o porquê
- [ ] Se mexeu em dependência: justificado no PR body
- [ ] Docs atualizadas (se aplicável)

## Riscos / observações

<!-- Qualquer coisa que o reviewer precisa saber: migrations, breaking changes,
     rollback plan, rate limits, mudanças que afetam outros stacks. -->
