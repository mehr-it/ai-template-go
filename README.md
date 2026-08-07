# ai-template

A template for AI-driven Go projects. It pairs a [sysbox](https://github.com/nestybox/sysbox)-backed outer Docker container (your persistent dev environment) with a per-worktree inner stack that the AI agent spins up on demand. Clone it, run bootstrap, hand the resulting repo to your agent, and you have a fully wired Go project with Docker-in-Docker, a structured agent knowledge base, and a reproducible dev loop.

## What this repo gives you

- `dev-container/` — outer container definition: the long-lived sysbox container your team SSHs into or `exec`s into for all dev work
- `dev-container-inner/` — inner stack templates: per-worktree compose files the agent brings up inside the outer container (database, app, tooling)
- `bootstrap/` — the 16-step interview and rewrite protocol that turns this template into a real project; run it once, then discard

## Prerequisites (Linux host)

- **Docker Engine** with [sysbox runtime](https://github.com/nestybox/sysbox) installed and enabled
- `git` and `gh` (GitHub CLI) authenticated
- An AI agent with shell access (OpenCode, Claude Code, or similar)

## Quickstart (owner)

Tell your AI agent:

```
Use `github.com/mehr-it/ai-template` to start a new Go AI project called `<name>` into `./<name>/`.
```

Substitute your fork URL for `github.com/mehr-it/ai-template` and your actual project name for `<name>`. The agent reads `bootstrap/AGENTS.md`, runs the 16-step interview, rewrites all placeholder values, and leaves you with a ready-to-run repo.

## After bootstrap

```bash
cd <name>/dev-container
docker compose up -d
docker exec -it <name>-dev bash
```

Inside the container, bring up the inner stack:

```bash
make dev-up
```

From there the agent can run builds, tests, and migrations inside the inner stack without touching your host.

## macOS note

sysbox is Linux-only. On macOS with Docker Desktop, the outer container will fail to start because `runtime: sysbox-runc` isn't available and nested Docker won't work reliably inside a standard container.

Your options:

- Run on a Linux host or Linux VM (recommended)
- Edit `dev-container/docker-compose.yml` to remove the `runtime: sysbox-runc` line — the outer container will start, but Docker-in-Docker inside it won't function
