#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/slug.sh
source "${SCRIPT_DIR}/lib/slug.sh"

wasi_resolve_worktree_root
wasi_assert_not_main_checkout
wasi_derive_slug >/dev/null

cd "${WASI_WORKTREE_ROOT}"

echo "[docker_inner] slug=${WASI_STACK_SLUG} worktree=${WASI_WORKTREE_ROOT}"

# Acquire flock to serialize port-discovery against concurrent up.sh invocations
LOCK_DIR="${WASI_WORKTREE_ROOT}/docker_inner/lock"
mkdir -p "${LOCK_DIR}"
LOCK_FILE="${LOCK_DIR}/up.lock"

(
  flock -x 200

  # Bring stack up (--wait blocks until all healthchecks green).
  # signal-cli is a JVM: cold start runs ~15-20s, so allow generous headroom.
  docker compose \
    -p "wasi-${WASI_STACK_SLUG}" \
    -f "${WASI_WORKTREE_ROOT}/docker_inner/docker-compose.yml" \
    up -d --wait --wait-timeout 180

  # Discover dynamic ports (poll until non-empty, max 20 attempts × 5s)
  _get_port() {
    local svc="$1" port="$2" result
    for _ in $(seq 1 20); do
      result="$(docker compose \
        -p "wasi-${WASI_STACK_SLUG}" \
        -f "${WASI_WORKTREE_ROOT}/docker_inner/docker-compose.yml" \
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

  SIGNAL_HTTP_PORT="$(_get_port signal-cli 8080)"
  POSTGRES_PORT="$(_get_port postgres 5432)"

  # Check idempotency: if .env.testing already has these exact ports, skip rewrite
  ENV_FILE="${WASI_WORKTREE_ROOT}/.env.testing"
  TEMPLATE="${WASI_WORKTREE_ROOT}/docker_inner/.env.testing.template"
  TMPFILE="${WASI_WORKTREE_ROOT}/.env.testing.tmp"

  if [[ -f "${ENV_FILE}" ]] && \
     grep -q "127.0.0.1:${SIGNAL_HTTP_PORT}" "${ENV_FILE}" && \
     grep -q "127.0.0.1:${POSTGRES_PORT}" "${ENV_FILE}"; then
    echo "[docker_inner] stack already up with matching ports — skipping env file rewrite."
  else
    # Generate env file from template (atomic: write to .tmp, then mv)
    sed \
      -e "s/__SIGNAL_HTTP_PORT__/${SIGNAL_HTTP_PORT}/g" \
      -e "s/__POSTGRES_PORT__/${POSTGRES_PORT}/g" \
      "${TEMPLATE}" > "${TMPFILE}"

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
  fi

  echo "[docker_inner] stack 'wasi-${WASI_STACK_SLUG}' is up."
  echo "[docker_inner] signal-cli  127.0.0.1:${SIGNAL_HTTP_PORT}  (JSON-RPC /api/v1/rpc, SSE /api/v1/events)"
  echo "[docker_inner] postgres    127.0.0.1:${POSTGRES_PORT}"
  echo "[docker_inner] env file: ${ENV_FILE}  (NEVER COMMIT — generated artifact)"
  echo "[docker_inner] run tests with: TEST_ENV_FILE=${ENV_FILE} go test ..."

) 200>"${LOCK_FILE}"
