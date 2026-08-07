> **When to read this**: You're an AI agent that just opened this repo. Read this file first.

# __PROJECT_NAME__

Module: `__PROJECT_MODULE__`.

## Dev environment

The outer container is the long-lived sysbox container where all dev work happens. Start it and get a shell:

```bash
cd dev-container
docker compose up -d
docker exec -it __project_prefix__-dev bash
```

OpenCode and Claude Code are preinstalled inside the container. Run your agent from there.

## AI session storage

Credentials and session data are split:

- **Credentials** are bind-mounted from the host — `~/.local/share/opencode/auth.json`, `~/.local/share/opencode/account.json`, `~/.claude/.credentials.json`. Log in once on the host and every container inherits. Source files must exist before `docker compose up`; if you don't use one of the tools, comment out its overlay in `dev-container/docker-compose.yml`.
- **Session data** (opencode SQLite DB, claude project histories, transcripts, todos) lives at `.ai-sessions/` in the repo root — isolated from your host sessions, shared across all worktrees inside the container, persistent across `docker compose down`/`up`. Opencode and Claude internally namespace sessions by CWD, so each worktree still sees its own session list in the TUI picker.

`.ai-sessions/` is gitignored. **`git clean -fdx` will wipe it** — use `git clean -fdx -e .ai-sessions` if you want to preserve session history through a clean.

## Parallel worktrees for test isolation

Integration tests need isolated services. Each agent works in its own git worktree under `.worktrees/<name>/` and brings up a private inner stack there. See `dev-container-inner/AGENTS.md` for the full picture.

The pattern for running tests in a worktree:

```bash
cd .worktrees/<name>/
make dev-up
TEST_ENV_FILE=$PWD/.env.testing go test -race ./...
make dev-down
```

`make dev-up` from the **main checkout** exits 64 by design. The inner stack is for worktrees only. If you see exit code 64, you're in the wrong directory.

## Layout

- `dev-container/` — outer container definition (sysbox-runc, long-lived)
- `dev-container-inner/` — per-worktree inner stack (compose files, lifecycle scripts)
- `cmd/__project_prefix__/` — main binary entrypoint (if skeleton was generated)
- `bootstrap/` — bootstrap scripts and interview protocol, kept as reference (KEEP_BOOTSTRAP=yes default); add more services later via `bootstrap/services/README.md`

## Bootstrap history

Bootstrapped from `mehr-it/ai-template-go`. Template updates are cherry-picked manually. No re-bootstrap.
