#!/usr/bin/env bash
# This file is SOURCED, not executed directly.
# Provides: wasi_resolve_worktree_root, wasi_assert_not_main_checkout, wasi_derive_slug
set -euo pipefail

WASI_MAIN_CHECKOUT="${WASI_MAIN_CHECKOUT:-/home/ubuntu/workspace}"

# Sets WASI_WORKTREE_ROOT to the absolute path of the git repo root.
# Exits non-zero if not in a git repo.
wasi_resolve_worktree_root() {
    WASI_WORKTREE_ROOT="$(git rev-parse --show-toplevel)"
    export WASI_WORKTREE_ROOT
}

# Exits 64 (EX_USAGE) if running from the main checkout.
# Must be called after wasi_resolve_worktree_root.
wasi_assert_not_main_checkout() {
    if [[ "${WASI_WORKTREE_ROOT}" == "${WASI_MAIN_CHECKOUT}" ]]; then
        echo "docker_inner is for worktrees only; the main checkout has no inner stack" >&2
        exit 64
    fi
}

# Derives and exports WASI_STACK_SLUG.
# Slug = sanitized(basename or WASI_DEV_STACK) + "-" + sha1[:8] of worktree path.
# Exits 65 (EX_DATAERR) if the sanitized slug is empty.
wasi_derive_slug() {
    local raw_slug
    if [[ -n "${WASI_DEV_STACK:-}" ]]; then
        raw_slug="${WASI_DEV_STACK}"
    else
        raw_slug="$(basename "${WASI_WORKTREE_ROOT}")"
    fi

    # Sanitize: lowercase, replace non-alphanumeric-dash with dash, collapse dashes, trim
    local sanitized
    sanitized="$(printf '%s' "${raw_slug}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')"

    if [[ -z "${sanitized}" ]]; then
        echo "docker_inner: slug is empty after sanitization (raw='${raw_slug}')" >&2
        exit 65
    fi

    # Uniqueness suffix: 8-char sha1 of the worktree absolute path
    local suffix
    suffix="$(printf '%s' "${WASI_WORKTREE_ROOT}" | sha1sum | cut -c1-8)"

    export WASI_STACK_SLUG="${sanitized}-${suffix}"
    printf '%s\n' "${WASI_STACK_SLUG}"
}
