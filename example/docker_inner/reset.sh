#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[docker_inner] reset: down then up."

# Bring stack down (best-effort; tolerate if already down)
bash "${SCRIPT_DIR}/down.sh" || true

# Bring stack back up (with fresh volumes)
bash "${SCRIPT_DIR}/up.sh"
