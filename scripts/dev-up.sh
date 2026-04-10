#!/usr/bin/env bash
# Sobe a stack de dev local (FastAPI com hot reload + Redis).
# Usage: ./scripts/dev-up.sh [--build]

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "[dev-up] .env ausente, copiando de .env.example"
  cp .env.example .env
  echo "[dev-up] Preencha .env com suas chaves antes de continuar."
fi

BUILD_FLAG=""
if [[ "${1:-}" == "--build" ]]; then
  BUILD_FLAG="--build"
fi

exec docker compose -f docker-compose.dev.yml up $BUILD_FLAG
