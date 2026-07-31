#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/slug.sh
source "${SCRIPT_DIR}/lib/slug.sh"

wasi_resolve_worktree_root
wasi_assert_not_main_checkout
wasi_derive_slug >/dev/null

cd "${WASI_WORKTREE_ROOT}"

echo "[docker_inner] stack: wasi-${WASI_STACK_SLUG}"
echo ""

# Show raw compose ps output
docker compose \
  -p "wasi-${WASI_STACK_SLUG}" \
  -f docker_inner/docker-compose.yml \
  ps 2>/dev/null || true

echo ""

# Build port table
SIGNAL_HTTP_PORT="$(docker compose -p "wasi-${WASI_STACK_SLUG}" -f docker_inner/docker-compose.yml port signal-cli 8080 2>/dev/null | cut -d: -f2 || echo '-')"
POSTGRES_PORT="$(docker compose -p "wasi-${WASI_STACK_SLUG}" -f docker_inner/docker-compose.yml port postgres 5432 2>/dev/null | cut -d: -f2 || echo '-')"

printf "%-20s %s\n" "SERVICE" "ADDR"
printf "%-20s %s\n" "signal-cli" "127.0.0.1:${SIGNAL_HTTP_PORT}"
printf "%-20s %s\n" "postgres"   "127.0.0.1:${POSTGRES_PORT}"

# Exit code: 0 if at least one container running, 1 otherwise
RUNNING="$(docker compose -p "wasi-${WASI_STACK_SLUG}" -f docker_inner/docker-compose.yml ps --status running --quiet 2>/dev/null | wc -l)"
if [[ "${RUNNING}" -gt 0 ]]; then
    exit 0
else
    exit 1
fi
