#!/usr/bin/env bash
set -euo pipefail

sudo service docker start

# Docker auto-creates missing bind-mount sources as root. Reclaim ownership so
# uid 1000 (ubuntu) can write session data. No-op when host dirs already exist
# owned by uid 1000. Non-recursive: credential file overlays inside are untouched.
sudo chown ubuntu:ubuntu /home/ubuntu/.local/share/opencode /home/ubuntu/.claude 2>/dev/null || true

MCP_DIR="$HOME/.opencode"
MCP_PACKAGES=(
  "@upstash/context7-mcp"
  "@modelcontextprotocol/server-filesystem"
  "@playwright/mcp@latest"
)

needs_install=false
for pkg in "${MCP_PACKAGES[@]}"; do
  if [ ! -d "$MCP_DIR/node_modules/$pkg" ]; then
    needs_install=true
    break
  fi
done

if [ "$needs_install" = true ]; then
  echo "Installing MCP server packages..."
  npm install --prefix "$MCP_DIR" "${MCP_PACKAGES[@]}"
fi

# Wrapper: launch opencode with a plugin-less config. Must keep the shebang
# (a single `echo` line without one will not exec reliably).
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/opencode-ohno" <<'EOF'
#!/usr/bin/env bash
export OPENCODE_CONFIG="$HOME/.config/opencode/opencode-no-open-agent.jsonc"
exec opencode "$@"
EOF
chmod +x "$HOME/.local/bin/opencode-ohno"

cd /home/ubuntu/workspace
codegraph init

exec opencode "$@"
