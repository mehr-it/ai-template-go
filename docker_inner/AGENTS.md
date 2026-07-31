> **When to read this**: You're starting/stopping the per-worktree dev stack, debugging a docker_inner script, or adding a new service to it.

# docker_inner — Per-Worktree Dev Stack

## Why docker_inner exists

Multiple agents run in parallel git worktrees (`.worktrees/<name>/`). Each needs its own
signal-cli daemon and database for integration tests. The inner Docker daemon
(sysbox-enabled, started by `docker/entrypoint.sh`) lets each worktree run an isolated
stack on dynamic `127.0.0.1` ports, so two agents never fight over port 8080.

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
| `signal-cli` | 8080 | JSON-RPC daemon: `POST /api/v1/rpc`, SSE stream `GET /api/v1/events`, health `GET /api/v1/check` |
| `postgres` | 5432 | Optional whatsmeow session store. Unused while the bridge stays on SQLite. |

There is no WhatsApp service: whatsmeow is a library that talks to WhatsApp's servers
directly, so the only WhatsApp-side state is the local session store.

## Generated `.env.testing` — NEVER COMMIT

`up.sh` **overwrites** `<worktree>/.env.testing` with the stack's dynamic ports, so
`git status` will show it. It is a generated artifact whose contents change on every
restart. It is gitignored; keep it that way. `down.sh` deletes it again.

## Stack identity

Each worktree stack gets a unique compose project name:

```
wasi-<slug>-<hash8>
```

- `slug` = `${WASI_DEV_STACK}` (if set) or `basename` of the worktree directory
- `hash8` = first 8 chars of `sha1sum` of the worktree absolute path, so two worktrees
  with the same basename still get distinct stacks

Override the slug: `WASI_DEV_STACK=my-custom-slug make dev-up`

## Linking a Signal account

The daemon starts in **multi-account mode with no account linked**. That is enough to
develop and test the JSON-RPC client — `version` and `listAccounts` both answer, and
`listAccounts` returns `[]`. Account-scoped calls like `send` will fail until you link.

**First-class path — `wasi-bridge --link-signal`:**

```bash
cd .worktrees/<name>/
make dev-up   # stack must be running; writes .env.testing with SIGNAL_RPC_URL
wasi-bridge --link-signal --config config.yaml --qr-terminal
```

Scan the QR printed to your terminal from Signal → Settings → Linked devices. The
bridge pairs, reports success, and exits. Credentials land in the `signal_cli_data`
volume; see the warning below about `--qr-terminal` and container logs — prefer
`--qr-dir` (the default) if you're not on an interactive TTY.

**Fallback — one-off container (no binary required):**

```bash
cd .worktrees/<name>/
source docker_inner/lib/slug.sh
wasi_resolve_worktree_root && wasi_derive_slug >/dev/null

docker compose -p "wasi-${WASI_STACK_SLUG}" -f docker_inner/docker-compose.yml \
  run --rm signal-cli link -n wasi-bridge-dev
```

It prints the `sgnl://linkdevice?...` URI, then blocks until the phone completes the scan.

Prefer **linking as a secondary device** over `register`ing a fresh number — see the root
`AGENTS.md`. Credentials land in the `signal_cli_data` volume, which `make dev-down`
**wipes** (`down -v`). Use `docker compose stop` instead if you want to keep a linked
account between sessions.

## Concurrency

signal-cli is a JVM and is the heavy service here; postgres is light. The workspace
container is capped at 25 GB. Watch `docker stats` if things slow down, and
`make dev-prune` to reap stacks from deleted worktrees.

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
| `prune.sh [--yes]` | Reap `wasi-*` stacks whose worktree no longer exists |

`make dev-up` / `dev-down` / `dev-reset` / `dev-status` / `dev-prune` delegate to these.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `WASI_STACK_SLUG is required` | Ran compose directly without `up.sh` | Use `make dev-up` |
| `docker_inner is for worktrees only` (exit 64) | Ran `make dev-up` from the main checkout | `cd .worktrees/<name>/` first |
| signal-cli healthcheck never goes green | JVM cold start exceeded `start_period` | Check `docker compose logs signal-cli`; it must log `Started HTTP server on /0.0.0.0:8080` |
| RPC returns "account not registered" | No account linked — expected on a fresh stack | Link one (above), or stick to `version` / `listAccounts` |
| `Port already in use` | Stale containers from a crashed session | `make dev-down`, or `make dev-prune` |
| Healthcheck edits silently fail | The image has no `curl`/`wget`/`nc`, and `/bin/sh` is dash without `/dev/tcp` | Keep `CMD` + `bash -c`, never `CMD-SHELL` |
