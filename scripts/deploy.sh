#!/usr/bin/env bash
# Deploy manual pra VPS manager (emergência — o normal é via GitHub Actions).
#
# Usage:
#   IMAGE_TAG=v0.0.1 ./scripts/deploy.sh
#
# Requer:
#   - SSH alias `ai-workflow-manager` configurado (~/.ssh/config)
#   - Imagem já publicada em ghcr.io/oduo-tech-team/ai-driven-workflow:$IMAGE_TAG
#   - Secrets já criados na VPS (docker secret create ai-workflow_*)

set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE_TAG="${IMAGE_TAG:-latest}"
REMOTE_HOST="ai-workflow-manager"
REMOTE_DIR="/root/ai-workflow"

echo "[deploy] tag=$IMAGE_TAG host=$REMOTE_HOST"

echo "[deploy] enviando docker-stack.yml"
ssh "$REMOTE_HOST" "mkdir -p $REMOTE_DIR"
scp docker-stack.yml "$REMOTE_HOST:$REMOTE_DIR/docker-stack.yml"

echo "[deploy] rodando docker stack deploy"
ssh "$REMOTE_HOST" \
  "cd $REMOTE_DIR && IMAGE_TAG=$IMAGE_TAG docker stack deploy \
    --with-registry-auth \
    --prune \
    -c docker-stack.yml \
    ai-workflow"

echo "[deploy] esperando o service ficar saudável"
sleep 10
ssh "$REMOTE_HOST" "docker service ls | grep ai-workflow"

echo "[deploy] smoke test"
curl -fsS https://ai-workflow.5.161.248.113.nip.io/health || {
  echo "[deploy] smoke test falhou — considere rollback com:"
  echo "  ssh $REMOTE_HOST 'docker service rollback ai-workflow_api'"
  exit 1
}

echo "[deploy] OK"
