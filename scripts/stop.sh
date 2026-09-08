#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "[ERRO] Docker Compose não encontrado." >&2
  exit 1
fi

echo "==> Encerrando os containers do projeto..."
"${COMPOSE[@]}" down

echo "[OK] Containers encerrados."
