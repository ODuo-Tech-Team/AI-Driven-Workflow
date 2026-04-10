# VPS `manager` — contrato de segurança

A VPS Hetzner `manager` (IP `5.161.248.113`, alias SSH `ai-workflow-manager`) é **produção**. Leader de um cluster Docker Swarm de 8 nodes, rodando 22 stacks do ecossistema Oduo: Typebot, Chatwoot, Evolution API (6 instâncias), Baserow, n8n, Postgres 17, RabbitMQ, MinIO, Traefik, Portainer, pgvector e 5 Redis dedicados.

**Qualquer ação que este projeto execute nessa VPS precisa respeitar as regras abaixo. Nada de "já que tô aqui" ou "só um ajustezinho".**

## Escopo permitido

Tudo dentro do "namespace" `ai-workflow`:

| Recurso | Path / nome |
|---|---|
| Stack Swarm | `ai-workflow` (prefixo automático em todos os services) |
| Volumes bind | `/mnt/arquivo_midias/ai-workflow/{data,logs,tmp,backups}` |
| Network interna | `ai-workflow_internal` (overlay, criada pelo nosso stack) |
| Network externa | Apenas **join** em `network_public` (externa, dona: Traefik stack) |
| Secrets | Prefixo `ai-workflow_*` |
| Configs | Prefixo `ai-workflow_*` |
| Traefik labels | Router/service prefixo `ai-workflow` |
| Hostname | `ai-workflow.5.161.248.113.nip.io` (temporário, migrar pra domínio real) |

## Proibido sem autorização explícita

- Modificar ou reiniciar **qualquer** service que não seja do stack `ai-workflow`
- Modificar a config do Traefik (inclui nome do resolver, certificados, middlewares globais)
- Criar/apagar volumes fora de `/mnt/arquivo_midias/ai-workflow/`
- Tocar em `/`, `/var/lib/docker`, `/etc/`, `/root/` (exceto `/root/ai-workflow/` pro docker-stack.yml)
- Instalar pacotes via `apt install` (exceto se imprescindível e Mauri autorizar)
- Rodar `docker system prune`, `docker volume prune`, `docker image prune -a`
- Mexer em `sshd_config`, firewall (UFW / iptables), fail2ban, kernel, timezone
- Trocar senha de outros usuários
- Apagar/modificar chaves SSH de outros usuários (inclui `gfmozzer@vscode` que é legítima)
- Criar usuários novos no sistema
- Tocar em secrets/configs/networks de outros stacks
- Rodar `docker swarm leave` ou qualquer operação de cluster
- Modificar labels de **outros containers** por qualquer motivo

## Budget de recursos

Hard cap do stack `ai-workflow` inteiro:

| Resource | Total |
|---|---|
| RAM | 1 GB |
| CPU | 1 vCPU |
| Disk (/mnt/arquivo_midias/ai-workflow/) | 5 GB iniciais, crescer sob demanda |

Breakdown entre services:

| Service | RAM limit | CPU limit |
|---|---|---|
| api (FastAPI) | 256 MB | 0.25 |
| worker (RQ) | 384 MB | 0.35 |
| redis | 128 MB | 0.15 |
| margem | 256 MB | 0.25 |

Se algo extrapolar: OOM kill do próprio service, sem afetar vizinhos.

## Descobertas de segurança (NÃO corrigir sem autorização do Mauri)

A recon feita em 2026-04-10 encontrou os seguintes pontos. Listados pro Mauri decidir se quer ticket ou fica assim:

1. `PermitRootLogin yes` + `PasswordAuthentication yes` em `/etc/ssh/sshd_config`
2. Sem UFW ativo, sem iptables rules
3. RabbitMQ management UI exposto em `0.0.0.0:15672`, AMQP em `0.0.0.0:5672`
4. Sem fail2ban
5. Disk root em 73% (52G/75G) — pouco espaço
6. Docker daemon com config padrão

**Nenhum desses é nosso problema pra resolver agora.** Só registrar.

## Processo pra qualquer mudança

1. Mudança só via `docker stack deploy -c docker-stack.yml ai-workflow` — NUNCA `docker service update` manual
2. Resource limits explícitos em TODO service — CI bloqueia se faltar (TODO: adicionar check)
3. Review humano obrigatório em PR que mexa no `docker-stack.yml`
4. Rollback plan documentado em todo PR de infra
5. Smoke test (`/health`) validado pós-deploy antes de considerar "pronto"

## Emergência

Se o stack `ai-workflow` estiver causando impacto em outros stacks:

```bash
ssh ai-workflow-manager
docker stack rm ai-workflow
# investiga, corrige, re-deploya
```

Se algo fora do nosso stack estiver quebrado: **NÃO mexer**, chamar o Mauri imediatamente.
