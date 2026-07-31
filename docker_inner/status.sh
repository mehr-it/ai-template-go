#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/slug.sh
source "${SCRIPT_DIR}/lib/slug.sh"

__project_prefix___resolve_worktree_root
__project_prefix___assert_not_main_checkout
__project_prefix___derive_slug >/dev/null

cd "${__PROJECT_PREFIX___WORKTREE_ROOT}"

echo "[docker_inner] stack: wasi-${__PROJECT_PREFIX___STACK_SLUG}"
echo ""

# Show raw compose ps output
docker compose \
  -p "wasi-${__PROJECT_PREFIX___STACK_SLUG}" \
  -f docker_inner/docker-compose.yml \
  ps 2>/dev/null || true

echo ""

# Build port table
printf "%-20s %s\n" "SERVICE" "ADDR"
# BOOTSTRAP_STATUS_ROWS — service rows appended by bootstrap

# Exit code: 0 if at least one container running, 1 otherwise
RUNNING="$(docker compose -p "wasi-${__PROJECT_PREFIX___STACK_SLUG}" -f docker_inner/docker-compose.yml ps --status running --quiet 2>/dev/null | wc -l)"
if [[ "${RUNNING}" -gt 0 ]]; then
    exit 0
else
    exit 1
fi
