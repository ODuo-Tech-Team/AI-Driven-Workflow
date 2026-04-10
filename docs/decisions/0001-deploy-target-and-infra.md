# ADR 0001 — Deploy target e infraestrutura

- **Data**: 2026-04-10
- **Status**: Aceito
- **Contexto**: Fase 0

## Contexto

Precisamos de um lugar pra rodar o orquestrador (FastAPI + RQ worker + Redis). Opções consideradas:

1. **Vercel** (backend + frontend)
2. **Fly.io** ou **Railway** (backend + Redis managed)
3. **VPS Hetzner nova** (dedicada pro projeto)
4. **VPS Hetzner existente** (aproveitar `oduo-sites-sistemas` ou `manager`)

## Decisão

**Opção 4 — VPS Hetzner `manager` existente, como Docker Swarm stack isolado.**

## Justificativa

### Por que não Vercel
- Serverless functions tem timeout de 10-60s, incompatível com jobs de agente que podem levar minutos
- Sem suporte a worker long-running (RQ precisa de processo persistente)
- Sem Docker/sandbox pro Executor Agent (Fase 2)
- Redis precisa de serviço externo (custo extra)
- Só faz sentido pro frontend (Fase 4), não pro backend

### Por que não Fly/Railway
- Custo mensal extra ($5-20)
- Sem vantagem técnica real sobre a VPS existente
- Infra fragmentada (um serviço nosso em Fly, resto na Hetzner)

### Por que não VPS nova
- Custo extra (€5-17/mês)
- A `manager` tem 5.9GB RAM livres, folga sobra pra 1GB do nosso stack
- Overhead operacional de mais uma máquina pra manter

### Por que `manager` e não `oduo-sites-sistemas`
- `sistemas` é CPX11 (2GB RAM, 40GB disk) — tight, com aaPanel rodando sites
- `manager` é CCX13 (2vCPU dedicada, 8GB RAM, 80GB+280GB) — folga real
- `manager` já tem Docker Swarm + Traefik + Let's Encrypt configurados
- `manager` tem volume grande (`/mnt/arquivo_midias` 79G) com 85G livres pra dados

## Consequências

### Positivas
- Zero custo adicional
- Aproveita Traefik existente (HTTPS automático via Let's Encrypt)
- Deploy via `docker stack deploy` — consistente com o resto do ecossistema
- Hostname `ai-workflow.5.161.248.113.nip.io` funciona de imediato (nip.io)

### Negativas
- Blast radius alto: bug nosso pode derrubar vizinhos se não respeitar resource limits
- Precisa disciplina operacional pesada — ver `docs/operations/vps-manager-rules.md`
- Sem isolamento de rede completo (tudo no mesmo host)

### Mitigações
- Contrato de segurança explícito em `docs/operations/vps-manager-rules.md`
- Resource limits obrigatórios em todo service
- Network interna dedicada (`ai-workflow_internal`)
- Volume bind apenas em `/mnt/arquivo_midias/ai-workflow/`
- Redis dedicado nosso (não compartilhar com os 5 Redis existentes)
- PR review humano obrigatório em mudanças no `docker-stack.yml`

## Revisão futura

Reavaliar quando:
- Stack ultrapassar 1GB RAM ou 1 vCPU consistentemente → VPS dedicada
- Volume de jobs exigir mais de 1 worker → considerar auto-scale
- Domínio real comprado → migrar de `nip.io` pra domínio da empresa
