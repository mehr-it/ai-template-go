#!/usr/bin/env bash
set -euo pipefail

# Prune orphan wasi-* compose stacks whose worktree no longer exists.
# Standalone — does NOT source lib/slug.sh (operates across all stacks).

MAIN_CHECKOUT="${WASI_MAIN_CHECKOUT:-/home/ubuntu/workspace}"

YES=false
for arg in "$@"; do
    case "${arg}" in
        --yes) YES=true ;;
        *) echo "Unknown argument: ${arg}" >&2; exit 1 ;;
    esac
done

# Collect live worktree paths
mapfile -t LIVE_WORKTREES < <(git worktree list --porcelain | awk '/^worktree /{print $2}')

# Collect wasi-* compose projects
mapfile -t PROJECTS < <(docker compose ls --format json 2>/dev/null | \
    jq -r '.[] | select(.Name | startswith("wasi-")) | .Name' 2>/dev/null || true)

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    echo "[docker_inner] no orphan wasi-* stacks found."
    exit 0
fi

# Identify orphans
ORPHANS=()
for project in "${PROJECTS[@]}"; do
    # Primary: get working_dir from container label (most reliable — this is the dir where compose was invoked)
    CONTAINER="$(docker ps -a --filter "label=com.docker.compose.project=${project}" --format '{{.ID}}' | head -1)"
    WORKING_DIR=""
    if [[ -n "${CONTAINER}" ]]; then
        LABEL_DIR="$(docker inspect "${CONTAINER}" --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' 2>/dev/null || true)"
        # Label is set to the directory containing docker-compose.yml (docker_inner), so dirname once to get worktree root
        if [[ -n "${LABEL_DIR}" ]]; then
            WORKING_DIR="$(dirname "${LABEL_DIR}")"
        fi
    fi

    # Fallback: derive from ConfigFiles path (dirname twice: strip /docker-compose.yml then /docker_inner)
    if [[ -z "${WORKING_DIR}" ]]; then
        CONFIG_FILE="$(docker compose ls --format json | \
            jq -r --arg name "${project}" '.[] | select(.Name == $name) | .ConfigFiles' | \
            head -1 || true)"
        if [[ -n "${CONFIG_FILE}" ]]; then
            WORKING_DIR="$(dirname "$(dirname "${CONFIG_FILE}")")"
        fi
    fi

    # Skip if no working_dir found or if it's the main checkout
    if [[ -z "${WORKING_DIR}" ]] || [[ "${WORKING_DIR}" == "${MAIN_CHECKOUT}" ]]; then
        continue
    fi

    # Check if working_dir is in live worktrees
    is_live=false
    for live in "${LIVE_WORKTREES[@]}"; do
        if [[ "${WORKING_DIR}" == "${live}" ]]; then
            is_live=true
            break
        fi
    done

    if [[ "${is_live}" == "false" ]]; then
        ORPHANS+=("${project}:${WORKING_DIR}")
    fi
done

if [[ ${#ORPHANS[@]} -eq 0 ]]; then
    echo "[docker_inner] no orphan wasi-* stacks found."
    exit 0
fi

echo "[docker_inner] orphan stacks found:"
for entry in "${ORPHANS[@]}"; do
    name="${entry%%:*}"
    dir="${entry#*:}"
    echo "  - ${name} (worktree: ${dir})"
done

# Prompt or auto-reap
if [[ "${YES}" == "false" ]] && [[ -t 0 ]]; then
    read -r -p "[docker_inner] Reap ${#ORPHANS[@]} orphan(s)? [y/N] " REPLY
    if [[ "${REPLY}" != "y" ]] && [[ "${REPLY}" != "Y" ]]; then
        echo "[docker_inner] aborted."
        exit 0
    fi
elif [[ "${YES}" == "false" ]]; then
    echo "[docker_inner] non-interactive mode: pass --yes to reap orphans."
    exit 0
fi

for entry in "${ORPHANS[@]}"; do
    name="${entry%%:*}"
    echo "[docker_inner] reaping ${name}..."
    docker compose -p "${name}" down -v --remove-orphans
done

echo "[docker_inner] reaping complete."
