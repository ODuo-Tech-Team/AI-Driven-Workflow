# Deployment

## Ambientes

| Ambiente | Host | Hostname público | Deploy |
|---|---|---|---|
| dev | localhost | http://localhost:8000 | `./scripts/dev-up.sh` (compose) |
| prod | VPS manager Hetzner | https://ai-workflow.5.161.248.113.nip.io | `docker stack deploy` via CI |

Não temos staging separado na Fase 0. A VPS manager é compartilhada com outros 22 stacks de produção. Ver `docs/operations/vps-manager-rules.md` pras regras obrigatórias.

## Pré-requisitos (primeira vez)

1. Acesso SSH à VPS: `ssh ai-workflow-manager` (alias já configurado em `~/.ssh/config`)
2. GitHub repo access: `gh auth login`
3. Secrets criados na VPS como Docker secrets:
   ```bash
   ssh ai-workflow-manager
   printf '%s' "$ANTHROPIC_API_KEY"       | docker secret create ai-workflow_anthropic_api_key -
   printf '%s' "$LINEAR_API_KEY"          | docker secret create ai-workflow_linear_api_key -
   printf '%s' "$LINEAR_WEBHOOK_SECRET"   | docker secret create ai-workflow_linear_webhook_secret -
   printf '%s' "$GITHUB_TOKEN"            | docker secret create ai-workflow_github_token -
   printf '%s' "$GITHUB_WEBHOOK_SECRET"   | docker secret create ai-workflow_github_webhook_secret -
   ```
4. Verificar que a rede `network_public` existe (owned pelo stack Traefik):
   ```bash
   docker network ls | grep network_public
   ```

## Deploy manual (emergência)

```bash
# Do laptop
export IMAGE_TAG=v0.0.1
scp docker-stack.yml ai-workflow-manager:/root/ai-workflow/
ssh ai-workflow-manager "cd /root/ai-workflow && IMAGE_TAG=$IMAGE_TAG docker stack deploy -c docker-stack.yml ai-workflow"
```

## Deploy via CI (padrão)

CI roda em todo push pra `main`:

1. Lint + test (bloqueia deploy se falhar)
2. Build Docker image
3. Push pra `ghcr.io/oduo-tech-team/ai-driven-workflow:<sha>`
4. SSH na VPS manager, roda `docker stack deploy` com a tag nova

Secrets necessários no repo GitHub:
- `GHCR_TOKEN` — PAT com scope `write:packages`
- `SSH_PRIVATE_KEY` — chave `ai-workflow-manager` (não a do Mauri)
- `SSH_HOST` — `5.161.248.113`
- `SSH_USER` — `root`

## Rollback

```bash
ssh ai-workflow-manager
docker service rollback ai-workflow_api
docker service rollback ai-workflow_worker
```

Docker Swarm mantém o estado anterior por default. `update_config.failure_action: rollback` no `docker-stack.yml` já faz rollback automático se o novo deploy falhar healthcheck.

## Smoke test pós-deploy

```bash
curl -fsS https://ai-workflow.5.161.248.113.nip.io/health
# esperado: {"status":"ok","version":"..."}

curl -fsS https://ai-workflow.5.161.248.113.nip.io/ready
# esperado: {"status":"ready"}
```

## Logs

```bash
ssh ai-workflow-manager
docker service logs -f ai-workflow_api
docker service logs -f ai-workflow_worker
# ou num node específico:
docker node ps <node>
```

Logs persistentes em `/mnt/arquivo_midias/ai-workflow/logs/`.

## Shutdown / cleanup

```bash
ssh ai-workflow-manager
docker stack rm ai-workflow
# secrets e volumes NÃO são removidos junto — precisa ser explícito
```
