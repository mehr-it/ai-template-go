#!/usr/bin/env bash
set -euo pipefail

# Prune orphan __project_prefix__-* compose stacks whose worktree no longer exists.
# Standalone — does NOT source lib/slug.sh (operates across all stacks).

MAIN_CHECKOUT="${__PROJECT_PREFIX___MAIN_CHECKOUT:-/home/ubuntu/workspace}"

YES=false
for arg in "$@"; do
    case "${arg}" in
        --yes) YES=true ;;
        *) echo "Unknown argument: ${arg}" >&2; exit 1 ;;
    esac
done

# Collect live worktree paths
mapfile -t LIVE_WORKTREES < <(git worktree list --porcelain | awk '/^worktree /{print $2}')

# Collect __project_prefix__-* compose projects
mapfile -t PROJECTS < <(docker compose ls --format json 2>/dev/null | \
    jq -r '.[] | select(.Name | startswith("__project_prefix__-")) | .Name' 2>/dev/null || true)

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    echo "[dev-container-inner] no orphan __project_prefix__-* stacks found."
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
        # Label is set to the directory containing docker-compose.yml (dev-container-inner), so dirname once to get worktree root
        if [[ -n "${LABEL_DIR}" ]]; then
            WORKING_DIR="$(dirname "${LABEL_DIR}")"
        fi
    fi

    # Fallback: derive from ConfigFiles path (dirname twice: strip /docker-compose.yml then /dev-container-inner)
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
    echo "[dev-container-inner] no orphan __project_prefix__-* stacks found."
    exit 0
fi

echo "[dev-container-inner] orphan stacks found:"
for entry in "${ORPHANS[@]}"; do
    name="${entry%%:*}"
    dir="${entry#*:}"
    echo "  - ${name} (worktree: ${dir})"
done

# Prompt or auto-reap
if [[ "${YES}" == "false" ]] && [[ -t 0 ]]; then
    read -r -p "[dev-container-inner] Reap ${#ORPHANS[@]} orphan(s)? [y/N] " REPLY
    if [[ "${REPLY}" != "y" ]] && [[ "${REPLY}" != "Y" ]]; then
        echo "[dev-container-inner] aborted."
        exit 0
    fi
elif [[ "${YES}" == "false" ]]; then
    echo "[dev-container-inner] non-interactive mode: pass --yes to reap orphans."
    exit 0
fi

for entry in "${ORPHANS[@]}"; do
    name="${entry%%:*}"
    echo "[dev-container-inner] reaping ${name}..."
    docker compose -p "${name}" down -v --remove-orphans
done

echo "[dev-container-inner] reaping complete."
