#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_PORT="${APP_PORT:-3000}"
HEALTH_URL="http://localhost:${APP_PORT}/health"
MAX_RETRIES=30
SLEEP_SECONDS=2

echo "==> Verificando se o Docker está disponível..."
if ! command -v docker >/dev/null 2>&1; then
  echo "[ERRO] Docker não encontrado no PATH. Instale o Docker antes de continuar." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "[ERRO] O daemon do Docker não está em execução." >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "[ERRO] Docker Compose não encontrado." >&2
  exit 1
fi

echo "==> Subindo os serviços com Docker Compose..."
"${COMPOSE[@]}" up -d --build

echo "==> Aguardando o healthcheck do container da aplicação..."
CONTAINER_ID="$("${COMPOSE[@]}" ps -q app)"

if [ -z "$CONTAINER_ID" ]; then
  echo "[ERRO] Não foi possível localizar o container do serviço 'app'." >&2
  exit 1
fi

STATUS="starting"
for ((i = 1; i <= MAX_RETRIES; i++)); do
  STATUS="$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_ID" 2>/dev/null || echo "unknown")"

  if [ "$STATUS" = "healthy" ]; then
    echo "==> Container está saudável."
    break
  fi

  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "[ERRO] O container não ficou saudável a tempo (status: ${STATUS})." >&2
    echo "----- logs do serviço app -----" >&2
    "${COMPOSE[@]}" logs app || true
    exit 1
  fi

  sleep "$SLEEP_SECONDS"
done

echo "==> Executando smoke test em ${HEALTH_URL}..."
if curl -fs "$HEALTH_URL" >/dev/null; then
  echo ""
  echo "[OK] Deploy concluído com sucesso. API disponível em http://localhost:${APP_PORT}"
  echo "[OK] Métricas Prometheus em http://localhost:${APP_PORT}/metrics"
  echo "[OK] Prometheus disponível em http://localhost:9090"
else
  echo ""
  echo "[FALHA] Smoke test: ${HEALTH_URL} não respondeu como esperado." >&2
  exit 1
fi
