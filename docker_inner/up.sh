#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/slug.sh
source "${SCRIPT_DIR}/lib/slug.sh"

__project_prefix___resolve_worktree_root
__project_prefix___assert_not_main_checkout
__project_prefix___derive_slug >/dev/null

cd "${__PROJECT_PREFIX___WORKTREE_ROOT}"

echo "[docker_inner] slug=${__PROJECT_PREFIX___STACK_SLUG} worktree=${__PROJECT_PREFIX___WORKTREE_ROOT}"

# Acquire flock to serialize port-discovery against concurrent up.sh invocations
LOCK_DIR="${__PROJECT_PREFIX___WORKTREE_ROOT}/docker_inner/lock"
mkdir -p "${LOCK_DIR}"
LOCK_FILE="${LOCK_DIR}/up.lock"

(
  flock -x 200

  # Bring stack up (--wait blocks until all healthchecks green).
  # Timeout accommodates slow-starting services (JVM cold starts, DB init, etc.).
  docker compose \
    -p "wasi-${__PROJECT_PREFIX___STACK_SLUG}" \
    -f "${__PROJECT_PREFIX___WORKTREE_ROOT}/docker_inner/docker-compose.yml" \
    up -d --wait --wait-timeout 180

  # Discover dynamic ports (poll until non-empty, max 20 attempts × 5s)
  _get_port() {
    local svc="$1" port="$2" result
    for _ in $(seq 1 20); do
      result="$(docker compose \
        -p "wasi-${__PROJECT_PREFIX___STACK_SLUG}" \
        -f "${__PROJECT_PREFIX___WORKTREE_ROOT}/docker_inner/docker-compose.yml" \
        port "${svc}" "${port}" 2>/dev/null | cut -d: -f2)"
      if [[ -n "${result}" ]]; then
        printf '%s' "${result}"
        return 0
      fi
      sleep 5
    done
    echo "up.sh: timed out waiting for port ${svc}:${port}" >&2
    return 1
  }

  # BOOTSTRAP_SERVICE_PORTS — port-discovery + sed stanzas appended by bootstrap when services are selected

  ENV_FILE="${__PROJECT_PREFIX___WORKTREE_ROOT}/.env.testing"
  TEMPLATE="${__PROJECT_PREFIX___WORKTREE_ROOT}/docker_inner/.env.testing.template"
  TMPFILE="${__PROJECT_PREFIX___WORKTREE_ROOT}/.env.testing.tmp"

  # Generate env file from template (atomic: write to .tmp, then mv).
  # Bootstrap injects sed -i substitutions on ${TMPFILE} at the marker above.
  cp "${TEMPLATE}" "${TMPFILE}"

  # Validate: no placeholders remain
  if grep -q '__' "${TMPFILE}"; then
    echo "up.sh: generated env file still contains placeholders:" >&2
    grep '__' "${TMPFILE}" >&2
    rm -f "${TMPFILE}"
    exit 1
  fi

  # Atomic publish
  mv "${TMPFILE}" "${ENV_FILE}"
  echo "[docker_inner] wrote ${ENV_FILE}"

  echo "[docker_inner] stack 'wasi-${__PROJECT_PREFIX___STACK_SLUG}' is up."
  # BOOTSTRAP_SUMMARY_LINES — service summary lines appended by bootstrap
  echo "[docker_inner] env file: ${ENV_FILE}  (NEVER COMMIT — generated artifact)"
  echo "[docker_inner] run tests with: TEST_ENV_FILE=${ENV_FILE} go test ..."

) 200>"${LOCK_FILE}"
