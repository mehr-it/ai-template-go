#!/usr/bin/env bash
# This file is SOURCED, not executed directly.
# Provides: __project_prefix___resolve_worktree_root, __project_prefix___assert_not_main_checkout, __project_prefix___derive_slug
set -euo pipefail

__PROJECT_PREFIX___MAIN_CHECKOUT="${__PROJECT_PREFIX___MAIN_CHECKOUT:-/home/ubuntu/workspace}"

# Sets __PROJECT_PREFIX___WORKTREE_ROOT to the absolute path of the git repo root.
# Exits non-zero if not in a git repo.
__project_prefix___resolve_worktree_root() {
    __PROJECT_PREFIX___WORKTREE_ROOT="$(git rev-parse --show-toplevel)"
    export __PROJECT_PREFIX___WORKTREE_ROOT
}

# Exits 64 (EX_USAGE) if running from the main checkout.
# Must be called after __project_prefix___resolve_worktree_root.
__project_prefix___assert_not_main_checkout() {
    if [[ "${__PROJECT_PREFIX___WORKTREE_ROOT}" == "${__PROJECT_PREFIX___MAIN_CHECKOUT}" ]]; then
        echo "docker_inner is for worktrees only; the main checkout has no inner stack" >&2
        exit 64
    fi
}

# Derives and exports __PROJECT_PREFIX___STACK_SLUG.
# Slug = sanitized(basename or __PROJECT_PREFIX___DEV_STACK) + "-" + sha1[:8] of worktree path.
# Exits 65 (EX_DATAERR) if the sanitized slug is empty.
__project_prefix___derive_slug() {
    local raw_slug
    if [[ -n "${__PROJECT_PREFIX___DEV_STACK:-}" ]]; then
        raw_slug="${__PROJECT_PREFIX___DEV_STACK}"
    else
        raw_slug="$(basename "${__PROJECT_PREFIX___WORKTREE_ROOT}")"
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
    suffix="$(printf '%s' "${__PROJECT_PREFIX___WORKTREE_ROOT}" | sha1sum | cut -c1-8)"

    export __PROJECT_PREFIX___STACK_SLUG="${sanitized}-${suffix}"
    printf '%s\n' "${__PROJECT_PREFIX___STACK_SLUG}"
}
