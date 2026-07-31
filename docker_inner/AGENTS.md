> **When to read this**: You're starting/stopping the per-worktree dev stack, debugging a docker_inner script, or adding a new service to it.

# docker_inner — Per-Worktree Dev Stack

## Why docker_inner exists

Multiple agents run in parallel git worktrees (`.worktrees/<name>/`). Each needs its own
isolated services for integration tests. The inner Docker daemon (sysbox-runc outer,
plain runc inner, started by `docker/entrypoint.sh`) lets each worktree run an isolated
stack on dynamic `127.0.0.1` ports, so two agents never fight over the same port.

## Main checkout vs worktree

| Where you are | What you use | Why |
|---|---|---|
| Main checkout (`/home/ubuntu/workspace/`) | Nothing — the scripts refuse to run | No parallelism needed; there is no outer data stack to conflict with |
| Worktree (`.worktrees/<name>/`) | `docker_inner/up.sh` + generated `.env.testing` | Parallel isolated test stacks per agent |

Running `make dev-up` from the main checkout exits **64** by design.

## Quick start

```bash
cd .worktrees/<name>/
make dev-up
TEST_ENV_FILE=$PWD/.env.testing go test -race ./...
make dev-down
```

## Services

| Service | Container port | Purpose |
|---|---|---|
| _(none by default)_ | — | Services are added via `bootstrap/services/` during bootstrap; see `bootstrap/services/README.md` to add more |

## Generated `.env.testing` — NEVER COMMIT

`up.sh` **overwrites** `<worktree>/.env.testing` with the stack's dynamic ports, so
`git status` will show it. It is a generated artifact whose contents change on every
restart. It is gitignored; keep it that way. `down.sh` deletes it again.

## Stack identity

Each worktree stack gets a unique compose project name:

```
${__project_prefix__}-<slug>-<hash8>
```

- `slug` = `${__PROJECT_PREFIX___DEV_STACK}` (if set) or `basename` of the worktree directory
- `hash8` = first 8 chars of `sha1sum` of the worktree absolute path, so two worktrees
  with the same basename still get distinct stacks

Override the slug: `__PROJECT_PREFIX___DEV_STACK=my-custom-slug make dev-up`

The resolved value is exported as `__PROJECT_PREFIX___STACK_SLUG` and used by all
lifecycle scripts to address the correct compose project.

## Concurrency

The workspace container is capped at 25 GB. Watch `docker stats` if things slow down,
and `make dev-prune` to reap stacks from deleted worktrees.

## Adding a new service

Three steps, no abstraction layer:

1. Drop `docker_inner/<svc>.yml` (service definition with a `127.0.0.1::PORT` binding and
   `runtime: runc`)
2. Add it to the `include:` block in `docker_inner/docker-compose.yml`
3. Add a `_get_port` call plus a `sed` substitution stanza to `up.sh`, a placeholder to
   `.env.testing.template`, and a row to `status.sh`

That's it. No registry, no generator, no framework.

## Lifecycle scripts

| Script | What it does |
|---|---|
| `up.sh` | Start stack, wait for health, write `.env.testing` |
| `down.sh` | Stop containers, wipe volumes, remove generated `.env.testing` |
| `reset.sh` | `down.sh` then `up.sh` — fresh volumes |
| `status.sh` | `compose ps` + port table |
| `prune.sh [--yes]` | Reap project stacks whose worktree no longer exists |

`make dev-up` / `dev-down` / `dev-reset` / `dev-status` / `dev-prune` delegate to these.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `__PROJECT_PREFIX___STACK_SLUG is required` | Ran compose directly without `up.sh` | Use `make dev-up` |
| `docker_inner is for worktrees only` (exit 64) | Ran `make dev-up` from the main checkout | `cd .worktrees/<name>/` first |
| `Port already in use` | Stale containers from a crashed session | `make dev-down`, or `make dev-prune` |
| Healthcheck edits silently fail | The image has no `curl`/`wget`/`nc`, and `/bin/sh` is dash without `/dev/tcp` | Keep `CMD` + `bash -c`, never `CMD-SHELL` |
