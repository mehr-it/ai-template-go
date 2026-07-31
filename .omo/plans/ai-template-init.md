# ai-template-init - Work Plan

## TL;DR (For humans)

**What you'll get:** A self-bootstrapping template repo that any AI coding agent (opencode, Claude Code, Cursor, etc.) can turn into a real Go project in one interactive session. Sitting in any directory, an owner tells their agent "use this template repo to start a new project", the agent fetches the repo, asks a handful of questions (project name, Go module path, which services like Postgres they need, whether to scaffold a starter Go program, whether to start with a fresh git history), and hands back a working project skeleton with a Docker-based dev container and per-worktree isolated test stacks — ready for daily use.

**Why this approach:** The bootstrap knowledge lives in the repo itself as plain markdown that any agent can read and follow. No plugin to install, no npm package to publish, no CLI to distribute. That means it works today with whatever coding agent the owner already uses, and it stays useful even for humans who read the docs directly. The alternative — a distributed plugin/skill — was considered and explicitly ruled out to maximize portability and minimize maintenance surface.

**What it will NOT do:** It will NOT pre-install a database or any other service in the template (the owner picks during bootstrap). It will NOT dictate a Go framework (no gin/echo/gorm pre-chosen — you get a bare `hello world`). It will NOT auto-trigger on generic phrases like "new Go project" — the owner explicitly names the repo URL to their agent. And it will NOT set up CI/CD or a release pipeline.

**Effort:** Medium — 35 atomic changes across 5 sequenced waves.
**Risk:** Low — a documentation/shell/config restructure with a scripted end-to-end dry-run that proves the whole bootstrap flow works before the plan is called done.
**Decisions to sanity-check:** Docs-in-repo distribution (no plugin); Postgres as the sole worked-example service (owners pick more during bootstrap); a fresh git repo by default when bootstrapping (template's git history is discarded); `bootstrap/` directory kept as reference by default (so more services can be added later).

Your next move: approve to start work — or ask for a high-accuracy dual review (Metis + Oracle) first. Full execution detail follows below.

---

> TL;DR (machine): Medium effort / Low risk / 35 atomic todos across 5 waves; docs-in-repo template restructure that turns this repo into a self-bootstrapping starter for AI-driven Go projects.

## Scope
### Must have

**C1 — `docker/` fixes and defaults**
- Rename `docker/entyrpoint.sh` → `docker/entrypoint.sh` (fixes Dockerfile `COPY entrypoint.sh` failure).
- Delete the unused `op` user block from `docker/Dockerfile` (lines 13-15).
- Add `${PROJECT_NAME:-ai-template}` fallback in `docker/docker-compose.yml` so `compose config` renders without `.env`; add explicit `env_file: .env` so the `.env` is loaded intentionally.
- Create `docker/.env.example` with `PROJECT_NAME=ai-template`, `UID=1000`, `GID=1000` and inline documentation.
- Create `docker/opencode/config/.gitkeep` so the compose bind-mount source exists.
- Sysbox prerequisite documented in root `README.md` (with install pointer).

**C2 — `docker_inner/` generic template**
- Copy every file from `example/docker_inner/` to `docker_inner/`.
- Rewrite all `WASI_*` env references to `__PROJECT_PREFIX___*` (double-underscore case-preserving sed).
- Rewrite all `wasi_*` shell function references to `__project_prefix___*`.
- Rewrite `wasi-${WASI_STACK_SLUG}` compose project name to `__project_prefix__-${__PROJECT_PREFIX___STACK_SLUG}`.
- Keep `/home/ubuntu/workspace` default for `__PROJECT_PREFIX___MAIN_CHECKOUT` — matches outer container.
- Empty the compose `include:` block; add `# BOOTSTRAP_SERVICE_INCLUDES` marker comment + 3-step "add a service" recipe.
- Add `# BOOTSTRAP_SERVICE_PORTS` marker in `up.sh` and `# BOOTSTRAP_ENV_LINES` marker in `.env.testing.template` for service injection during bootstrap.
- Rewrite `docker_inner/AGENTS.md` — strip signal-cli/WhatsApp specifics, generalize.
- Delete `signal-cli.yml` and `postgres.yml` from `docker_inner/` (they move to `bootstrap/services/`).
- Keep `.gitignore` (`/lock/`).

**C3 — Root entry point for ANY visiting agent**
- Root `AGENTS.md` — short: identifies the repo, detects `TEMPLATE_UNINITIALIZED` state, delegates to `bootstrap/AGENTS.md`, hard-states bootstrap runs on the owner's host (not inside a container).
- Root `README.md` — human-facing: what this repo is, prerequisites (Linux host + docker + sysbox), quickstart (owner's exact copyable prompt), sysbox install pointer, post-bootstrap dev flow overview.
- `TEMPLATE_UNINITIALIZED` marker at repo root with one comment line.

**C4 — `bootstrap/` protocol + post-bootstrap replacement**
- `bootstrap/AGENTS.md` — the authoritative 16-step agent-executable protocol including non-interactive mode via `BOOTSTRAP_ANSWERS_FILE`.
- `bootstrap/AGENTS.md.tpl` — post-bootstrap replacement for root `AGENTS.md` with placeholders describing the concrete project (dev flow, worktree instructions).
- `bootstrap/README.md` — one-paragraph explainer.

**C5 — `bootstrap/services/` snippet library + `bootstrap/go-skeleton/`**
- `bootstrap/services/postgres.yml` — generalized postgres service (dropped WASI-specific user/db, uses `__project_prefix__`).
- `bootstrap/services/postgres.env.snippet` — `.env.testing` fragment for postgres DSN using `__POSTGRES_PORT__` placeholder.
- `bootstrap/services/postgres.up-snippet.sh` — `up.sh` port-discovery + sed stanza for postgres.
- `bootstrap/services/README.md` — 3-step "add a service" recipe, snippet-set convention (`<svc>.yml` + `<svc>.env.snippet` + `<svc>.up-snippet.sh`), current catalog, contributor guide.
- `bootstrap/go-skeleton/go.mod.tpl` — `module __PROJECT_MODULE__` + `go 1.26`.
- `bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/main.go.tpl` — minimal `package main`.
- `bootstrap/go-skeleton/Makefile.tpl` — build/test/dev-up/dev-down/dev-reset/dev-status/dev-prune targets.
- `bootstrap/go-skeleton/README.md` — one-line explainer.

**C6 — Cleanup**
- Delete `example/` directory entirely.
- Create root `.gitignore` (env files, worktrees, DB files, common Go build outputs).

**C7 — Verification harness (plan-time, not shipped)**
- `bash -n` sweep across every shell script under `docker/`, `docker_inner/`, `bootstrap/**`.
- `docker compose -f docker/docker-compose.yml config` with both empty env AND `.env.example` values.
- Non-interactive end-to-end bootstrap dry-run in `/tmp/ai-template-e2e-<timestamp>/` using `BOOTSTRAP_ANSWERS_FILE`.
- Grep sweep: no `WASI_`, `wasi_`, `wasi-bridge`, `signal-cli`, `whatsmeow`, `entyrpoint` string survives outside `.git/` and `.omo/`.

### Must NOT have (guardrails, anti-slop, scope boundaries)

- **No opencode plugin, no npm package, no `SKILL.md`** — Option 1 hard constraint.
- **No auto-trigger phrases** — owner names the repo URL explicitly; the repo does not squat generic phrases.
- **No changes to `opencode.jsonc`, `.codegraph/`, `.idea/`.**
- **No Go application code** beyond the opt-in `bootstrap/go-skeleton/main.go.tpl` stub.
- **No framework opinions** (no gin/echo/cobra/zap/sqlc/gorm pre-chosen).
- **No pre-baked services in `docker_inner/`** — fresh template has an empty `include:`.
- **No Dockerfile toolchain changes** beyond removing dead `op` user and matching the entrypoint rename. Go 1.26.2, Node 26, opencode, claude, docker, codegraph versions unchanged.
- **No CI/CD** (`.github/workflows/`, `.gitlab-ci.yml`), no release engineering (tags, changelog).
- **No git operations by the plan** — the plan writes files and runs read-only validation; it does not `git init`, `git add`, `git commit`. The runtime bootstrap agent may commit at end of interactive bootstrap, but that's not this plan.
- **No renaming of `PROJECT_NAME`, `docker/`, or `docker_inner/`** — user's structure decisions.
- **No unit-test framework for the template infrastructure** — `bash -n` + `docker compose config` + end-to-end dry-run only.
- **No Windows/macOS first-class bootstrap paths** — Linux host with sysbox is the supported path; macOS via Docker Desktop is a README note only.
- **No auto-detection of "what services does the code need"** — always a human-in-the-loop interview.
- **No conditional single-file for root `AGENTS.md`** — pre/post are physically separate files (`bootstrap/AGENTS.md.tpl` moves into place).
- **No self-updating / re-bootstrap command** — traceability via commit message SHA only. Owners cherry-pick template updates manually.
- **No handling of the outer container's own opencode config bootstrap** — inherited via mount from host.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- **Test decision: tests-after.** This is a docs + shell + YAML deliverable, not application code. No unit-test framework is added.
- **Framework: `bash -n` (POSIX shell syntax check) + `docker compose config` (compose file validation with interpolation) + `grep -rn` (string presence/absence assertions) + a scripted end-to-end bootstrap dry-run in `/tmp/`.**
- **Evidence path:** every todo writes verification output to `.omo/evidence/task-<N>-ai-template-init.txt` (or `.log` when appropriate).
- **The end-to-end dry-run (Wave 5, task 34) is the load-bearing gate:** it copies the repo to a tempdir, invokes `bootstrap/AGENTS.md` in non-interactive mode (via `BOOTSTRAP_ANSWERS_FILE=/tmp/answers.env`), and asserts (a) zero surviving `__PROJECT_*__` placeholders outside `bootstrap/`, (b) marker deleted, (c) postgres service wired into `docker_inner/` (yml + env line + up.sh stanza), (d) `go.mod` at target root, (e) `docker compose config` renders for both outer and inner stacks. This is the empirical proof the bootstrap protocol is agent-executable, not just written down.
- **Grep-sweep** (Wave 5, task 35) is the anti-regression check: confirms no `WASI_`/`wasi_`/`signal-cli`/`whatsmeow`/`entyrpoint` string survives anywhere outside `.git/` and `.omo/`.
- **Per-todo QA scenarios:** every todo defines a happy scenario (verify the change works) AND a failure scenario (verify the change rejects the expected wrong state — e.g. rejects a non-empty target dir, rejects a missing marker, etc.).

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.

- **Wave 1 — Preflight + `docker/` fixes** (7 todos: 1-7). Baseline evidence capture (todo 1) plus five atomic `docker/` fixes (todos 2-6) plus a compose-config verification (todo 7). Todos 2-6 fully parallelize; todo 7 waits for 4 and 5.
- **Wave 2 — `docker_inner/` generic template** (8 todos: 8-15). Copy from `example/` (todo 8) blocks 9-14 which rewrite the copied files; todos 9-14 mostly parallelize (each touches a distinct file); `bash -n` verification (todo 15) waits for 10 (all shell script rewrites).
- **Wave 3 — Documentation surface** (6 todos: 16-21). Root entry point (16-18) + bootstrap protocol docs (19-21). All parallelize once Wave 2 is done (bootstrap docs reference the `docker_inner/` file structure). Root docs (16-18) could technically start earlier but are grouped here for wave coherence.
- **Wave 4 — Bootstrap library** (8 todos: 22-29). Service snippets (22-25) + Go skeleton (26-29). Fully parallel; independent files.
- **Wave 5 — Cleanup + final verification** (6 todos: 30-35). Delete `example/` (30) + root `.gitignore` (31) — parallel. Then `bash -n` sweep (32) + outer compose config (33) — parallel. Then end-to-end dry-run (34) which depends on ALL prior — this is the load-bearing gate. Then grep sweep (35) which depends on 30 completing.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | — | — | 2, 3, 4, 5, 6 |
| 2 | — | — | 1, 3, 4, 5, 6 |
| 3 | — | — | 1, 2, 4, 5, 6 |
| 4 | — | 7 | 1, 2, 3, 5, 6 |
| 5 | — | 7 | 1, 2, 3, 4, 6 |
| 6 | — | — | 1, 2, 3, 4, 5 |
| 7 | 4, 5 | — | (waits for wave) |
| 8 | — | 9, 10, 11, 12, 13, 14 | (blocks wave 2) |
| 9 | 8 | 15, 19, 20 | 11, 13, 14 (10 touches related files) |
| 10 | 8 | 15, 19, 22, 24 | 11, 13, 14 |
| 11 | 8 | 19, 22 | 9, 10, 13, 14 |
| 12 | 8 | — | 9, 10, 11, 13, 14 |
| 13 | 8 | 22, 23 | 9, 10, 11, 14 |
| 14 | 8 | 19, 20 | 9, 10, 11, 13 |
| 15 | 9, 10 | 32 | (verification) |
| 16 | — | 30 (bootstrap agent overwrites this at end of runtime) | 17, 18, 19, 20, 21 |
| 17 | — | — | 16, 18, 19, 20, 21 |
| 18 | — | 34 (bootstrap gates on this) | 16, 17, 19, 20, 21 |
| 19 | 9, 10, 11, 14, 24, 28 | 34 | 20, 21 (partial) |
| 20 | 14 | 34 | 19, 21 |
| 21 | — | — | 19, 20 |
| 22 | 10, 11 | 34 | 23, 24, 25, 26, 27, 28, 29 |
| 23 | 13 | 34 | 22, 24, 25, 26, 27, 28, 29 |
| 24 | 10 | 32, 34 | 22, 23, 25, 26, 27, 28, 29 |
| 25 | 22, 23, 24 | — | 26, 27, 28, 29 |
| 26 | — | 34 | 22-25, 27, 28, 29 |
| 27 | — | 34 | 22-26, 28, 29 |
| 28 | — | 32, 34 | 22-27, 29 |
| 29 | — | — | 22-28 |
| 30 | 8, 22, 23, 24 (all uses of `example/` complete) | 35 | 31 |
| 31 | — | — | 30 |
| 32 | 2, 10, 24, 28 | — | 33 |
| 33 | 4, 5 | — | 32 |
| 34 | ALL previous | — | (load-bearing gate) |
| 35 | 30 | — | (final anti-regression) |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->

<!-- =========================================================================
     WAVE 1 — Preflight + docker/ fixes (7 todos: 1-7)
     ========================================================================= -->

- [x] 1. `.omo/evidence/task-1-baseline.txt`: Capture pre-change repo snapshot for audit trail — expect diffable file with tree + selected file contents + before-grep
  What to do / Must NOT do: Run `ls -laR .` on repo root (excluding `.git/`, `.omo/`, `.idea/`, `.codegraph/`); concat `docker/Dockerfile`, `docker/docker-compose.yml`, `docker/entyrpoint.sh`; run `grep -RnE 'WASI_|wasi_|signal-cli|whatsmeow|wasi-bridge|entyrpoint' . --exclude-dir=.git --exclude-dir=.omo`; write everything to `.omo/evidence/task-1-baseline.txt`. MUST NOT edit any repo file.
  Parallelization: Wave 1 | Blocked by: none | Blocks: none
  References: `docker/*`, `example/docker_inner/*`, `opencode.jsonc`
  Acceptance criteria: `test -s .omo/evidence/task-1-baseline.txt && grep -q 'WASI_STACK_SLUG' .omo/evidence/task-1-baseline.txt && grep -q 'entyrpoint' .omo/evidence/task-1-baseline.txt`
  QA scenarios: happy = `wc -l .omo/evidence/task-1-baseline.txt` returns >100 lines; failure = if file missing/empty, re-run. Evidence `.omo/evidence/task-1-baseline.txt`
  Commit: N (evidence-only)

- [x] 2. `docker/entyrpoint.sh` → `docker/entrypoint.sh`: Rename to match Dockerfile COPY line 71 — expect Dockerfile COPY reference resolves
  What to do / Must NOT do: `git mv docker/entyrpoint.sh docker/entrypoint.sh` (or `mv` + `git add -A`). Content unchanged. MUST NOT edit Dockerfile (which already says `entrypoint.sh`). MUST NOT touch permissions (was 775 via COPY --chmod).
  Parallelization: Wave 1 | Blocked by: none | Blocks: 32
  References: `docker/entyrpoint.sh:1-39` (file), `docker/Dockerfile:71` (already correct)
  Acceptance criteria: `test -f docker/entrypoint.sh && ! test -e docker/entyrpoint.sh && head -1 docker/entrypoint.sh | grep -q '#!/usr/bin/env bash' && grep -q 'COPY.*entrypoint.sh' docker/Dockerfile`
  QA scenarios: happy = **static check** `grep -q 'COPY.*entrypoint.sh' docker/Dockerfile && test -f docker/entrypoint.sh` (Dockerfile source and target file both exist as expected; a full `docker build` requires network for apt/npm/curl-based RUN steps and a running docker daemon — out of scope for this task's QA); failure = if both files or neither exist, git restore + re-run. Evidence `.omo/evidence/task-2-rename.txt` (git status output + static check result)
  Commit: Y | `fix(docker): rename entyrpoint.sh → entrypoint.sh (typo)`

- [x] 3. `docker/Dockerfile:13-15`: Delete dead `op` user creation block — expect no unused user, `USER ubuntu` still active
  What to do / Must NOT do: Remove lines 13-15 (the `RUN useradd -m -s /bin/bash op && echo "op ALL=..." && chmod 0440 ...` block). MUST NOT touch line 32-33 (ubuntu-group sudoers — that IS used) or line 35 (`USER ubuntu`).
  Parallelization: Wave 1 | Blocked by: none | Blocks: none
  References: `docker/Dockerfile:13-15` (block to delete), `docker/Dockerfile:31-35` (keep intact)
  Acceptance criteria: `! grep -q 'useradd -m -s /bin/bash op' docker/Dockerfile && grep -q 'USER ubuntu' docker/Dockerfile && grep -q 'sudoers.d/ubuntu' docker/Dockerfile`
  QA scenarios: happy = `docker build -t ai-template-test docker/ 2>&1 | tail -20` reaches USER ubuntu without complaint; failure = if `op` referenced anywhere else (verified by inspection: it is not), revert. Evidence `.omo/evidence/task-3-dockerfile-diff.txt` (diff output)
  Commit: Y | `chore(docker): remove unused op user block from Dockerfile`

- [x] 4. `docker/docker-compose.yml:4` + new `env_file: .env`: Add `${PROJECT_NAME:-ai-template}` fallback and explicit env_file — expect `docker compose config` renders without a `.env` file
  What to do / Must NOT do: Change `container_name: ${PROJECT_NAME}-dev` to `container_name: ${PROJECT_NAME:-ai-template}-dev`. Add `env_file:` block under `workspace:` immediately before `environment:` with one entry `- .env` — but only load if it exists (compose treats missing env_file as fatal, so wrap: use `env_file: - path: .env\n      required: false` — Compose Spec v3.9+ supports this; if fails, fall back to relying on implicit `.env` auto-load and omit the explicit block). MUST NOT change sysbox-runc runtime, volumes, memory limit, network.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 7
  References: `docker/docker-compose.yml:1-31`
  Acceptance criteria: `docker compose -f docker/docker-compose.yml config >/dev/null 2>&1 && docker compose -f docker/docker-compose.yml config 2>/dev/null | grep -q 'container_name: ai-template-dev'`
  QA scenarios: happy = both with-`.env` and without-`.env` render successfully; failure = if `env_file` block with `required: false` unsupported by installed compose version, fall back to implicit-only. Evidence `.omo/evidence/task-4-compose-diff.txt`
  Commit: Y | `fix(docker): add PROJECT_NAME fallback and explicit env_file to compose`

- [x] 5. `docker/.env.example`: Create owner-copyable env template with PROJECT_NAME/UID/GID defaults + inline docs — expect `cp .env.example .env` gives a working env
  What to do / Must NOT do: Write `docker/.env.example` with header comment, `PROJECT_NAME=ai-template` (bootstrap rewrites), `UID=1000`, `GID=1000`, each with a one-line explanation. MUST NOT include secrets, real service credentials, or opencode config paths.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 7
  References: `docker/docker-compose.yml:6-10` (uses PROJECT_NAME, UID, GID)
  Acceptance criteria: `test -s docker/.env.example && grep -q '^PROJECT_NAME=ai-template$' docker/.env.example && grep -q '^UID=1000$' docker/.env.example && grep -q '^GID=1000$' docker/.env.example`
  QA scenarios: happy = `cp docker/.env.example docker/.env && docker compose -f docker/docker-compose.yml config >/dev/null && rm docker/.env`; failure = if malformed KEY=VALUE, compose errors. Evidence `.omo/evidence/task-5-env-example.txt` (file contents)
  Commit: Y | `feat(docker): add .env.example with PROJECT_NAME/UID/GID defaults`

- [x] 6. `docker/opencode/config/.gitkeep`: Create directory placeholder for compose bind-mount source — expect mount `./opencode/config/` no longer errors
  What to do / Must NOT do: `mkdir -p docker/opencode/config && touch docker/opencode/config/.gitkeep`. MUST NOT put any real opencode config here (it's a placeholder mount source; owner populates later).
  Parallelization: Wave 1 | Blocked by: none | Blocks: none
  References: `docker/docker-compose.yml:12` (mounts `./opencode/config/`)
  Acceptance criteria: `test -d docker/opencode/config && test -f docker/opencode/config/.gitkeep && [ "$(wc -c < docker/opencode/config/.gitkeep)" = "0" ]`
  QA scenarios: happy = `docker compose -f docker/docker-compose.yml config` no longer warns about missing bind source; failure = if `.gitkeep` accidentally non-empty, `truncate -s 0`. Evidence `.omo/evidence/task-6-gitkeep.txt` (ls output)
  Commit: Y | `fix(docker): create docker/opencode/config/ mount source placeholder`

- [x] 7. `.omo/evidence/task-7-outer-compose*.txt`: Verify `docker compose config` on outer twice (with/without `.env`) — expect both exit 0
  What to do / Must NOT do: `docker compose -f docker/docker-compose.yml config > .omo/evidence/task-7-outer-compose-no-env.txt 2>&1` (no .env present). Then `cp docker/.env.example docker/.env && docker compose -f docker/docker-compose.yml config > .omo/evidence/task-7-outer-compose-with-env.txt 2>&1; rm docker/.env`. MUST clean up test `.env` file — must NOT leave it on disk.
  Parallelization: Wave 1 | Blocked by: 4, 5 | Blocks: none
  References: `docker/docker-compose.yml`, `docker/.env.example`
  Acceptance criteria: `grep -q 'container_name: ai-template-dev' .omo/evidence/task-7-outer-compose-no-env.txt && grep -q 'container_name:' .omo/evidence/task-7-outer-compose-with-env.txt && ! test -e docker/.env`
  QA scenarios: happy = both files non-empty, no `error` lines; failure = if compose errors in either mode, revisit task 4 or 5. Evidence `.omo/evidence/task-7-outer-compose-*.txt`
  Commit: N (validation only)

<!-- =========================================================================
     WAVE 2 — docker_inner/ generic template (8 todos: 8-15)
     ========================================================================= -->

- [x] 8. `docker_inner/`: Copy `example/docker_inner/*` (preserving hidden files, lib/) — expect working seed for template rewrite; **abort if `docker_inner/` already exists and is non-empty**
  What to do / Must NOT do: **Preflight:** `if test -d docker_inner && [ -n "$(ls -A docker_inner 2>/dev/null)" ]; then echo "docker_inner/ already exists and is non-empty — aborting to avoid silent overwrite. Delete it manually if intentional." >&2; exit 1; fi`. Then `cp -a example/docker_inner/ docker_inner/` — preserves `.gitignore`, `lib/slug.sh`, all files, permissions, no dereferencing (no symlinks in source, `-a` is safe). MUST NOT delete `example/` yet (that's task 30, after tasks 22-24 also consume from example/). MUST NOT modify content during copy. MUST NOT silently overwrite an existing non-empty `docker_inner/` (that would clobber Wave 2 partial work on a re-run).
  Parallelization: Wave 2 | Blocked by: none | Blocks: 9, 10, 11, 12, 13, 14
  References: `example/docker_inner/*` (source: `AGENTS.md`, `docker-compose.yml`, `.env.testing.template`, `.gitignore`, `down.sh`, `lib/slug.sh`, `postgres.yml`, `prune.sh`, `reset.sh`, `signal-cli.yml`, `status.sh`, `up.sh`)
  Acceptance criteria: `diff -r example/docker_inner/ docker_inner/ | wc -l | grep -q '^0$' && test -f docker_inner/lib/slug.sh && test -f docker_inner/.gitignore && test -f docker_inner/up.sh`
  QA scenarios: happy = 12 entries in `docker_inner/` matching source; failure = if `diff -r` shows any output, re-copy from clean state; if preflight abort fires, the executor knows to intervene before proceeding. Evidence `.omo/evidence/task-8-copy-diff.txt`
  Commit: Y | `chore(docker_inner): seed template from example/`

- [x] 9. `docker_inner/lib/slug.sh`: Case-preserving sed replace WASI_→__PROJECT_PREFIX___ and wasi_→__project_prefix___ — expect greppable placeholders, `bash -n` passes, default `/home/ubuntu/workspace` preserved
  What to do / Must NOT do: Run `sed -i 's/WASI_/__PROJECT_PREFIX___/g; s/wasi_/__project_prefix___/g' docker_inner/lib/slug.sh`. Verify `/home/ubuntu/workspace` is unchanged (matches outer container mount target). MUST NOT change `set -euo pipefail`, shebang, sanitize regex, sha1sum uniqueness logic, or the `export` keyword usage.
  Parallelization: Wave 2 | Blocked by: 8 | Blocks: 15, 19, 20
  References: `docker_inner/lib/slug.sh:1-50` (from task 8 copy)
  Acceptance criteria: `! grep -qE 'WASI_|wasi_' docker_inner/lib/slug.sh && grep -q '__PROJECT_PREFIX___STACK_SLUG' docker_inner/lib/slug.sh && grep -q '__project_prefix___resolve_worktree_root' docker_inner/lib/slug.sh && grep -q '/home/ubuntu/workspace' docker_inner/lib/slug.sh && bash -n docker_inner/lib/slug.sh`
  QA scenarios: happy = `bash -n` exits 0; the triple-underscore function names (`__project_prefix___resolve_worktree_root`) parse as valid bash function names — verify by defining `__project_prefix___test() { :; }` in a subshell. Failure = if any WASI_/wasi_ survives, sed missed → re-run. Evidence `.omo/evidence/task-9-slug-diff.txt`
  Commit: Y | `feat(docker_inner): rewrite slug.sh with __PROJECT_PREFIX__ placeholders`

- [x] 10. `docker_inner/{up,down,reset,status,prune}.sh`: Case-preserving placeholder rewrite + insert THREE distinct markers (`# BOOTSTRAP_SERVICE_PORTS`, `# BOOTSTRAP_SUMMARY_LINES`, `# BOOTSTRAP_STATUS_ROWS`) + strip signal-cli/postgres-specific port-discovery + rewrite `wasi-` (hyphen) in prune.sh — expect empty-service scripts with injection markers, `bash -n` all pass
  What to do / Must NOT do: For each of `up.sh`, `down.sh`, `reset.sh`, `status.sh`, `prune.sh`:
    (a) `sed -i 's/WASI_/__PROJECT_PREFIX___/g; s/wasi_/__project_prefix___/g' <file>` — note this handles UNDERSCORE forms only.
    (b) In `up.sh`: replace lines 50-51 (`SIGNAL_HTTP_PORT="..."` and `POSTGRES_PORT="..."`) plus the two sed stanzas at lines 65-66 with a single marker line `  # BOOTSTRAP_SERVICE_PORTS — port-discovery + sed stanzas appended by bootstrap when services are selected`; keep the `_get_port` helper function (lines 33-48) intact — that's the reusable primitive.
    (c) In `up.sh`: replace the two `echo "[docker_inner] signal-cli..."` and `echo "[docker_inner] postgres..."` summary lines with `  # BOOTSTRAP_SUMMARY_LINES — service summary lines appended by bootstrap` (DISTINCT name from BOOTSTRAP_STATUS_ROWS in status.sh — one goes in up.sh's post-startup summary, the other in status.sh's port table).
    (d) In `status.sh`: replace the two `SIGNAL_HTTP_PORT="..."` / `POSTGRES_PORT="..."` lookup lines and the two `printf` port-table lines with a single marker `# BOOTSTRAP_STATUS_ROWS — service rows appended by bootstrap`.
    (e) In `prune.sh`: BOTH the underscore sed (a) AND an explicit hyphen-form sed `sed -i 's/startswith("wasi-")/startswith("__project_prefix__-")/g' docker_inner/prune.sh` (the generic sed at (a) misses `wasi-` with a hyphen since it only rewrites `wasi_`).
    (f) `bash -n` each after rewrite.
  MUST NOT change flock serialization, atomic .env.testing write pattern, `_get_port` helper body, or `down -v` volume-wipe behavior. MUST NOT collapse markers into inline comments (they need to be greppable single lines). MUST use THREE distinct marker names — do NOT reuse `BOOTSTRAP_STATUS_ROWS` for both up.sh and status.sh.
  Parallelization: Wave 2 | Blocked by: 8 | Blocks: 15, 19, 22, 24
  References: `docker_inner/up.sh:1-88`, `docker_inner/down.sh:1-31`, `docker_inner/reset.sh:1-12`, `docker_inner/status.sh:1-40`, `docker_inner/prune.sh:1-102` (line 22: `startswith("wasi-")` — hyphen form the generic sed does NOT catch)
  Acceptance criteria: `! grep -RnE 'WASI_|wasi_|signal-cli|SIGNAL_HTTP_PORT|"postgres" "5432"' docker_inner/*.sh && ! grep -q 'startswith("wasi-")' docker_inner/prune.sh && grep -c '# BOOTSTRAP_SERVICE_PORTS' docker_inner/up.sh | grep -q '^1$' && grep -c '# BOOTSTRAP_SUMMARY_LINES' docker_inner/up.sh | grep -q '^1$' && grep -c '# BOOTSTRAP_STATUS_ROWS' docker_inner/status.sh | grep -q '^1$' && grep -q '__project_prefix__-' docker_inner/prune.sh && for f in docker_inner/*.sh; do bash -n "$f" || exit 1; done`
  QA scenarios: happy = every script parses; each of the three marker names appears exactly once in its target file; `prune.sh` contains `startswith("__project_prefix__-")` and NOT `startswith("wasi-")`; failure = if `grep -c` returns 0 (missed) or >1 (duplicated), adjust the sed target. If `wasi-` (hyphen) survives in prune.sh, step (e)'s explicit sed was skipped — re-run. Evidence `.omo/evidence/task-10-scripts-diff.txt` (per-file diff)
  Commit: Y | `feat(docker_inner): rewrite lifecycle scripts with placeholders and service-injection markers`

- [x] 11. `docker_inner/docker-compose.yml`: Rewrite with placeholder project name + empty `include:` + `# BOOTSTRAP_SERVICE_INCLUDES` marker + 3-step add-a-service recipe comment — expect empty-service compose file that renders with a sample prefix
  What to do / Must NOT do: Overwrite `docker_inner/docker-compose.yml` (currently 7 lines) with:
  ```
  # Assembled by docker_inner/up.sh — do not invoke directly.
  # Requires __PROJECT_PREFIX___STACK_SLUG, which up.sh derives from the worktree path.
  name: __project_prefix__-${__PROJECT_PREFIX___STACK_SLUG:?__PROJECT_PREFIX___STACK_SLUG is required}

  # BOOTSTRAP_SERVICE_INCLUDES — service .yml files appended below by bootstrap.
  # To add a service manually (post-bootstrap):
  #   1. Drop docker_inner/<svc>.yml with a 127.0.0.1::PORT binding and runtime: runc
  #   2. Add "  - <svc>.yml" to the include: block below
  #   3. Add a _get_port stanza to up.sh at BOOTSTRAP_SERVICE_PORTS and a status row to status.sh at BOOTSTRAP_STATUS_ROWS
  include: []
  ```
  Note: `include: []` is valid YAML for an empty list; docker-compose v2 accepts it. MUST NOT add any real service. MUST NOT remove the `name:` line.
  Parallelization: Wave 2 | Blocked by: 8 | Blocks: 19, 22
  References: `docker_inner/docker-compose.yml:1-7` (from task 8 copy)
  Acceptance criteria: `grep -q 'name: __project_prefix__-\${__PROJECT_PREFIX___STACK_SLUG' docker_inner/docker-compose.yml && grep -q 'include: \[\]' docker_inner/docker-compose.yml && grep -q '# BOOTSTRAP_SERVICE_INCLUDES' docker_inner/docker-compose.yml && __PROJECT_PREFIX___STACK_SLUG=test docker compose -f docker_inner/docker-compose.yml config >/dev/null 2>&1`
  QA scenarios: happy = compose config renders with a fake env var and no services; failure = if `include: []` unsupported, fall back to omitting the `include:` key and adding `services: {}` — re-verify. Evidence `.omo/evidence/task-11-compose-config.txt`
  Commit: Y | `feat(docker_inner): make compose file service-empty with BOOTSTRAP_SERVICE_INCLUDES marker`

- [x] 12. `docker_inner/signal-cli.yml`, `docker_inner/postgres.yml`: Delete both project-specific service files — expect only `docker-compose.yml` remains as a .yml file in docker_inner/
  What to do / Must NOT do: `rm docker_inner/signal-cli.yml docker_inner/postgres.yml`. MUST NOT touch `example/docker_inner/postgres.yml` or `example/docker_inner/signal-cli.yml` (still needed for tasks 22-24). MUST NOT delete `docker_inner/docker-compose.yml`.
  Parallelization: Wave 2 | Blocked by: 8 | Blocks: none
  References: `example/docker_inner/postgres.yml`, `example/docker_inner/signal-cli.yml` (untouched)
  Acceptance criteria: `! test -e docker_inner/signal-cli.yml && ! test -e docker_inner/postgres.yml && test -e example/docker_inner/postgres.yml && test -e docker_inner/docker-compose.yml && [ "$(ls docker_inner/*.yml 2>/dev/null | wc -l)" = "1" ]`
  QA scenarios: happy = `ls docker_inner/*.yml` shows only `docker_inner/docker-compose.yml`; failure = if example/ files accidentally deleted, `git restore example/`. Evidence `.omo/evidence/task-12-ls.txt`
  Commit: Y | `chore(docker_inner): remove project-specific service files (moved to bootstrap/)`

- [x] 13. `docker_inner/.env.testing.template`: Overwrite with generic header + `# BOOTSTRAP_ENV_LINES` marker + commented placeholder-pattern example — expect empty-service template that documents the pattern
  What to do / Must NOT do: Overwrite `docker_inner/.env.testing.template` with:
  ```
  # Generated by docker_inner/up.sh — DO NOT COMMIT.
  # Ports are dynamic and change every time the stack restarts.
  #
  # Placeholder pattern: use __<SERVICE>_PORT__ as a sed target; up.sh replaces
  # each with the actual port discovered from `docker compose port <svc> <port>`.
  #
  # Example (uncomment and adapt after adding a service):
  # __PROJECT_PREFIX___POSTGRES_DSN=postgres://user:pass@127.0.0.1:__POSTGRES_PORT__/db?sslmode=disable

  # BOOTSTRAP_ENV_LINES — service env lines appended here by bootstrap.
  ```
  MUST keep the `# Generated by docker_inner/up.sh` header — `down.sh:26` uses it as the deletion heuristic. MUST NOT reference signal-cli, whatsmeow, or hardcoded ports.
  Parallelization: Wave 2 | Blocked by: 8 | Blocks: 22, 23
  References: `example/docker_inner/.env.testing.template:1-20`, `docker_inner/down.sh:26` (heuristic)
  Acceptance criteria: `grep -q '# BOOTSTRAP_ENV_LINES' docker_inner/.env.testing.template && ! grep -qE 'WASI_SIGNAL|whatsmeow' docker_inner/.env.testing.template && grep -q '# Generated by docker_inner/up.sh' docker_inner/.env.testing.template`
  QA scenarios: happy = down.sh deletion heuristic still matches (grep for `Generated by docker_inner/up.sh` returns 1); failure = if header lost, down.sh won't delete generated file → restore header. Evidence `.omo/evidence/task-13-env-template.txt` (cat output)
  Commit: Y | `feat(docker_inner): make .env.testing.template generic with BOOTSTRAP_ENV_LINES marker`

- [x] 14. `docker_inner/AGENTS.md`: Strip signal-cli/WhatsApp specifics; keep generic per-worktree stack docs — expect project-agnostic guidance covering rationale, main-vs-worktree table, stack identity, add-a-service recipe, troubleshooting
  What to do / Must NOT do: Overwrite `docker_inner/AGENTS.md`. KEEP (generalized): "When to read this" preamble; "Why docker_inner exists" (per-worktree parallel test isolation on dynamic ports, sysbox-runc outer, plain runc inner); "Main checkout vs worktree" table (`make dev-up` from main exits 64 by design); "Quick start" (make dev-up, TEST_ENV_FILE, make dev-down); "Services" table (empty by default with note: "Services are added via `bootstrap/services/` during bootstrap; see `bootstrap/services/README.md` to add more"); "Generated .env.testing warning" (never commit, gitignored); "Stack identity" (compose project = `${__project_prefix__}-<slug>-<hash8>`, slug = `__PROJECT_PREFIX___DEV_STACK` or basename, hash8 = sha1[:8] of absolute path, override with `__PROJECT_PREFIX___DEV_STACK=my-slug`); "Concurrency" notes (25G cap, docker stats, make dev-prune); "Adding a new service" (3-step recipe from example lines 103-113, generalized); "Lifecycle scripts" table (up/down/reset/status/prune); "Troubleshooting" matrix (generalize: keep `__PROJECT_PREFIX___STACK_SLUG is required`, `docker_inner is for worktrees only (exit 64)`, `Port already in use`, `Healthcheck edits silently fail`; drop signal-cli/JVM cold-start row and "account not registered" row). REMOVE entirely: signal-cli linking section, wasi-bridge/whatsmeow-specific paragraphs, sgnl://linkdevice references.
  Parallelization: Wave 2 | Blocked by: 8 | Blocks: 19, 20
  References: `example/docker_inner/AGENTS.md:1-136` (source), `:103-113` (recipe), `:128-136` (troubleshooting), `docker_inner/*.sh` and `docker_inner/lib/slug.sh` (structure references)
  Acceptance criteria: `grep -c 'signal-cli\|whatsmeow\|wasi-bridge' docker_inner/AGENTS.md | grep -q '^0$' && grep -q '__PROJECT_PREFIX___STACK_SLUG' docker_inner/AGENTS.md && grep -qi 'Adding a new service' docker_inner/AGENTS.md && grep -qi 'main checkout' docker_inner/AGENTS.md && [ $(wc -l < docker_inner/AGENTS.md) -ge 60 ] && [ $(wc -l < docker_inner/AGENTS.md) -le 130 ]`
  QA scenarios: happy = markdown renders (no dead internal links); failure = if any project-specific string survives, re-sweep. Evidence `.omo/evidence/task-14-agents-md.txt` (grep -c summary)
  Commit: Y | `docs(docker_inner): rewrite AGENTS.md as project-agnostic per-worktree stack guide`

- [x] 15. `.omo/evidence/task-15-bash-syntax.txt`: Run `bash -n` on all `docker_inner/**/*.sh` — expect every file passes (proof placeholder rewrite is syntactically valid)
  What to do / Must NOT do: `{ for f in docker_inner/lib/*.sh docker_inner/*.sh; do printf '=== %s ===\n' "$f"; if bash -n "$f" 2>&1; then echo OK; else echo FAIL; fi; done; } > .omo/evidence/task-15-bash-syntax.txt 2>&1`. MUST NOT modify any script; validation-only.
  Parallelization: Wave 2 | Blocked by: 9, 10 | Blocks: 32
  References: outputs of tasks 9, 10
  Acceptance criteria: `! grep -q FAIL .omo/evidence/task-15-bash-syntax.txt && [ "$(grep -c '=== docker_inner/' .omo/evidence/task-15-bash-syntax.txt)" -ge 6 ]`
  QA scenarios: happy = every listed file shows `OK`; failure = any FAIL → identify offender and revisit its authoring task. Evidence `.omo/evidence/task-15-bash-syntax.txt`
  Commit: N (validation only)

<!-- =========================================================================
     WAVE 3 — Documentation surface (6 todos: 16-21)
     ========================================================================= -->

- [x] 16. `AGENTS.md` (root): Create protocol pointer + `TEMPLATE_UNINITIALIZED` state detector + delegate to `bootstrap/AGENTS.md` — expect any visiting agent knows what to do
  What to do / Must NOT do: Create root `AGENTS.md` with:
    (1) "When to read this" preamble targeting fresh-clone AI agents
    (2) One-paragraph repo identification ("template for AI-driven Go projects using sysbox docker outer + per-worktree inner stack; see README.md for humans")
    (3) State-detection block: "If `TEMPLATE_UNINITIALIZED` exists at root, this template has NOT been bootstrapped. Read `bootstrap/AGENTS.md` for the 16-step interview + rewrite protocol."
    (4) Hard-state warning: "**Bootstrap runs on the owner's host, NOT inside a container.** The outer docker container only comes up after bootstrap. Do NOT `docker compose up` before bootstrap — placeholders would leak into container config."
    (5) Post-bootstrap fallback: "If `TEMPLATE_UNINITIALIZED` is absent, bootstrap has run. This template-version root AGENTS.md should have been replaced from `bootstrap/AGENTS.md.tpl`. If you're reading this in a bootstrapped repo, something went wrong — restore from the template or ask the owner."
  MUST NOT include the actual bootstrap protocol (that's `bootstrap/AGENTS.md`). MUST NOT include human-facing prose (that's `README.md`).
  Parallelization: Wave 3 | Blocked by: none | Blocks: 30 (bootstrap agent overwrites this at runtime, but pre-bootstrap it lives here)
  References: `bootstrap/AGENTS.md` (task 19), `bootstrap/AGENTS.md.tpl` (task 20), `TEMPLATE_UNINITIALIZED` (task 18), `example/docker_inner/AGENTS.md:1` (preamble format)
  Acceptance criteria: `test -s AGENTS.md && grep -q 'TEMPLATE_UNINITIALIZED' AGENTS.md && grep -q 'bootstrap/AGENTS.md' AGENTS.md && grep -qi "on the owner.s host" AGENTS.md && grep -q 'bootstrap/AGENTS.md.tpl' AGENTS.md`
  QA scenarios: happy = any agent reading this immediately knows what the repo is, whether to bootstrap, and which file to read next; failure = if state detection is ambiguous, add explicit `test -e TEMPLATE_UNINITIALIZED` example. Evidence `.omo/evidence/task-16-agents-md.txt` (cat output)
  Commit: Y | `docs: add root AGENTS.md as agent entry point`

- [x] 17. `README.md` (root): Create human-facing intro with owner's copyable quickstart prompt + prereqs + post-bootstrap dev flow — expect owner reads and knows what to do
  What to do / Must NOT do: Create root `README.md` with sections:
    (1) `# ai-template` — one-paragraph "what it is"
    (2) `## What this repo gives you` — bullet list of `docker/`, `docker_inner/`, `bootstrap/`
    (3) `## Prerequisites (Linux host)` — Docker Engine + sysbox (link https://github.com/nestybox/sysbox), `git`/`gh`, an AI agent with shell access
    (4) `## Quickstart (owner)` — the exact copyable prompt: `> "Use \`github.com/mehr-it/ai-template\` to start a new Go AI project called \`<name>\` into \`./<name>/\`."` (with backticks for exact copy-paste); note that substituting fork URL and name is expected
    (5) `## After bootstrap` — the `cd <name>/docker && docker compose up -d && docker exec -it <name>-dev bash` sequence, then the inner-stack `make dev-up` flow
    (6) `## macOS note` — sysbox is Linux-only; on macOS via Docker Desktop the outer sysbox runtime will fail — either use a Linux VM or edit `docker/docker-compose.yml` to drop `runtime: sysbox-runc` (nested docker won't work reliably)
  MUST NOT duplicate the bootstrap protocol. MUST NOT invent service catalogs. MUST include the exact prompt owner can copy verbatim.
  Parallelization: Wave 3 | Blocked by: none | Blocks: none
  References: `docker/`, `docker_inner/`, `bootstrap/`, sysbox project
  Acceptance criteria: `test -s README.md && grep -qi 'sysbox' README.md && grep -q 'github.com/mehr-it/ai-template' README.md && grep -q 'TEMPLATE_UNINITIALIZED\|bootstrap' README.md && grep -qi 'macOS' README.md && grep -q '## Quickstart' README.md`
  QA scenarios: happy = a human can read README, satisfy prereqs, and copy the quickstart prompt into their agent verbatim; failure = if quickstart references files that don't yet exist (like `<name>-dev` container without explaining), add clarifying line. Evidence `.omo/evidence/task-17-readme.txt` (cat output)
  Commit: Y | `docs: add root README.md with owner quickstart`

- [x] 18. `TEMPLATE_UNINITIALIZED`: Create empty marker with one-line hash comment at repo root — expect bootstrap agent detects fresh template
  What to do / Must NOT do: Write `TEMPLATE_UNINITIALIZED` at repo root with single line: `# Bootstrap has not been run yet. See AGENTS.md.` (hash-comment style; single line). MUST NOT make it executable. MUST NOT add multiple lines.
  Parallelization: Wave 3 | Blocked by: none | Blocks: 34 (dry-run consumes marker)
  References: root `AGENTS.md` (task 16), `bootstrap/AGENTS.md` step 0 preflight (task 19)
  Acceptance criteria: `test -f TEMPLATE_UNINITIALIZED && [ "$(wc -l < TEMPLATE_UNINITIALIZED | tr -d ' ')" = "1" ] && head -1 TEMPLATE_UNINITIALIZED | grep -q '^#' && [ ! -x TEMPLATE_UNINITIALIZED ]`
  QA scenarios: happy = `test -e TEMPLATE_UNINITIALIZED` in bootstrap preflight succeeds; failure = if accidentally +x, `chmod -x`. Evidence `.omo/evidence/task-18-marker.txt` (ls -la output)
  Commit: Y | `feat: add TEMPLATE_UNINITIALIZED marker for bootstrap detection`

- [x] 19. `bootstrap/AGENTS.md`: Author authoritative 16-step bootstrap protocol including non-interactive mode via `BOOTSTRAP_ANSWERS_FILE` — expect any capable agent can execute bootstrap end-to-end
  What to do / Must NOT do: Create `bootstrap/AGENTS.md`. Required sections in order:
    - Preamble ("When to read this")
    - `## Modes` — interactive (default) vs non-interactive (`BOOTSTRAP_ANSWERS_FILE=<path>` reads KEY=VALUE fixture; required keys: `TARGET_DIR`, `PROJECT_NAME`, `PROJECT_PREFIX`, `project_prefix`, `PROJECT_MODULE`, `SERVICES` (csv or empty), `GO_SKELETON`, `BINARY`, `FRESH_GIT`, `COMMIT`, `KEEP_BOOTSTRAP`, `BOOTSTRAP_TEMPLATE_SHA`)
    - `## Protocol` with 16 numbered steps:
      `### 0. Preflight` — assert `test -f TEMPLATE_UNINITIALIZED`, abort with "Bootstrap already completed" if absent; capture `BOOTSTRAP_TEMPLATE_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"` BEFORE any `.git/` reset; check `git`/`sed`/`bash` on PATH; if GO_SKELETON=yes also check `go`
      `### 1. Target-directory interview` — options (a)/(b)/(c); refuse non-empty non-owned target unless confirmed
      `### 2. Project identity interview` — PROJECT_NAME (human), PROJECT_PREFIX (uppercase alnum, auto-derived from name), project_prefix (lowercase alnum), PROJECT_MODULE (Go module path); confirm/override each auto-derivation
      `### 3. Service selection` — list `bootstrap/services/*.yml` (excluding README); owner picks csv
      `### 4. Go skeleton` — Y/N + BINARY (default = project_prefix)
      `### 5. Fresh git` — Y/n default Y
      `### 6. Commit on completion` — Y/n default Y
      `### 7. Keep bootstrap dir` — Y/n default Y
      `### 8. Sed rewrite protocol` — for every file under target EXCEPT `bootstrap/`, `.git/`, `.omo/`, `example/`:
        ```
        sed -i "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g; s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g; s|__project_prefix__|${project_prefix}|g; s|__PROJECT_SLUG__|${BINARY}|g; s|__PROJECT_NAME__|${PROJECT_NAME}|g" "$file"
        ```
        **Order matters:**
        - `__PROJECT_MODULE__` first (contains `/`; sed delimiter is `|` for safety, but doing it first also lets the executor sanity-check the delimiter change).
        - `__PROJECT_PREFIX__` (UPPERCASE) before `__project_prefix__` (lowercase). Case-sensitive; safe either way, but consistent order aids review.
        - `__PROJECT_SLUG__` before `__PROJECT_NAME__` — SLUG is a distinct fifth placeholder used ONLY in the directory name `bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/`; we still include it in the sed list defensively in case future template additions put it in file content.
        - `__PROJECT_NAME__` last (least constrained; contains human text).
        **Triple-underscore convention:** After the WASI→PREFIX rewrite in template authoring, template files contain forms like `__PROJECT_PREFIX___STACK_SLUG` (three underscores between prefix and word). This is a natural consequence: `WASI_STACK_SLUG` had underscore between `WASI` and `STACK`; template sed `s/WASI_/__PROJECT_PREFIX___/g` (note trailing underscore) yields `__PROJECT_PREFIX___STACK_SLUG` = `__PROJECT_PREFIX__` (marker) + `_STACK_SLUG` (original suffix). Bootstrap's `s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g` correctly reduces this to `${PROJECT_PREFIX}_STACK_SLUG` (single underscore). Verify post-rewrite with `grep -q '${PROJECT_PREFIX}_STACK_SLUG' docker_inner/lib/slug.sh` (single underscore expected, NOT `${PROJECT_PREFIX}__STACK_SLUG` with double).
        **Directory renames** (do AFTER file content sed): `mv bootstrap/go-skeleton/cmd/__PROJECT_SLUG__ bootstrap/go-skeleton/cmd/${BINARY}`. Any other placeholder-named directories in future template additions get the same treatment.
      `### 9. Wire selected services` — for each svc in SERVICES:
        (a) `cp bootstrap/services/<svc>.yml docker_inner/<svc>.yml` — then run step-8 sed on the copy (the .yml has `__project_prefix__` etc.).
        (b) Compose include: change `include: []` in **`docker_inner/docker-compose.yml`** to `include:\n  - <svc>.yml` (or if include already non-empty, append `  - <svc>.yml`).
        (c) Splice port-discovery: insert `bootstrap/services/<svc>.up-snippet.sh` content at the `# BOOTSTRAP_SERVICE_PORTS` marker line in **`docker_inner/up.sh`**.
        (d) Splice env line: append `bootstrap/services/<svc>.env.snippet` content at the `# BOOTSTRAP_ENV_LINES` marker in **`docker_inner/.env.testing.template`**.
        (e) Auto-generate summary line: at the `# BOOTSTRAP_SUMMARY_LINES` marker in **`docker_inner/up.sh`**, insert `  echo "[docker_inner] <svc>  127.0.0.1:${<SVC>_PORT}"` (where `<SVC>` is the uppercase form used in the up-snippet, e.g. `POSTGRES`).
        (f) Auto-generate status row: at the `# BOOTSTRAP_STATUS_ROWS` marker in **`docker_inner/status.sh`**, insert the port lookup + printf pair: `<SVC>_PORT="$(docker compose -p "__project_prefix__-${__PROJECT_PREFIX___STACK_SLUG}" -f docker_inner/docker-compose.yml port <svc> <container-port> 2>/dev/null | cut -d: -f2 || echo '-')"` and `printf "%-20s %s\n" "<svc>" "127.0.0.1:${<SVC>_PORT}"` (this is executed AFTER step 8's sed has rewritten the prefix placeholders in status.sh, so the surrounding lines are correct).
        Note: three DISTINCT marker names — `BOOTSTRAP_SERVICE_PORTS` and `BOOTSTRAP_SUMMARY_LINES` both live in `up.sh` (different jobs); `BOOTSTRAP_STATUS_ROWS` lives in `status.sh`. Do NOT conflate them.
      `### 10. Go skeleton (if selected)` — cp go.mod.tpl → go.mod (target root), sed rewrite; cp -r cmd/__PROJECT_SLUG__/ → cmd/${BINARY}/, sed rewrite + rename main.go.tpl → main.go; cp Makefile.tpl → Makefile, sed rewrite (preserve tab indentation); `go mod tidy` (best-effort)
      `### 11. Replace root AGENTS.md` — `cp bootstrap/AGENTS.md.tpl AGENTS.md`, sed rewrite
      `### 12. Delete TEMPLATE_UNINITIALIZED` — `rm TEMPLATE_UNINITIALIZED`
      `### 13. Optionally delete bootstrap/` — if KEEP_BOOTSTRAP=no
      `### 14. Optionally reset git and commit` — if FRESH_GIT=yes: `rm -rf .git && git init`; if COMMIT=yes: `git add . && git commit -m "Bootstrap from mehr-it/ai-template@${BOOTSTRAP_TEMPLATE_SHA}"`
      `### 15. Post-bootstrap validation` — `docker compose -f docker/docker-compose.yml config >/dev/null`; with PREFIX exported, `docker compose -f docker_inner/docker-compose.yml config >/dev/null`; `bash -n` sweep; `grep -Rn '__PROJECT_' . --exclude-dir=bootstrap --exclude-dir=.git --exclude-dir=.omo` returns empty
      `### 16. Success summary` — print block: `✓ Bootstrap complete: <PROJECT_NAME> in <TARGET_DIR>`, services wired, go skeleton, git status, next steps
  MUST NOT bake in specific service list beyond postgres. MUST NOT require docker to be running during rewrite steps (only at step 15 validation, which is a `config` render — no daemon needed for that command).
  Parallelization: Wave 3 | Blocked by: 9, 10, 11, 14, 24, 28 (references file paths + markers created there) | Blocks: 34
  References: `docker_inner/*` (tasks 8-14), `bootstrap/services/postgres.{yml,env.snippet,up-snippet.sh}` (tasks 22-24), `bootstrap/go-skeleton/*` (tasks 26-28), `TEMPLATE_UNINITIALIZED` (task 18)
  Acceptance criteria: `test -s bootstrap/AGENTS.md && grep -q '## Modes' bootstrap/AGENTS.md && grep -q '### 0. Preflight' bootstrap/AGENTS.md && grep -q '### 16. Success summary' bootstrap/AGENTS.md && grep -q 'BOOTSTRAP_ANSWERS_FILE' bootstrap/AGENTS.md && grep -q 'sed -i' bootstrap/AGENTS.md && grep -q 'BOOTSTRAP_TEMPLATE_SHA' bootstrap/AGENTS.md && [ "$(grep -c '^### [0-9]' bootstrap/AGENTS.md)" = "17" ]` (17 = steps 0-16)
  QA scenarios: happy = an agent can execute every step with unambiguous instructions and no follow-up questions; failure = if any step references a nonexistent file or has an ambiguous conditional, revise. Evidence `.omo/evidence/task-19-protocol.txt` (grep of numbered steps)
  Commit: Y | `feat(bootstrap): add authoritative 16-step bootstrap protocol`

- [x] 20. `bootstrap/AGENTS.md.tpl`: Author post-bootstrap replacement for root AGENTS.md with placeholders — expect concrete project doc after bootstrap moves it into place
  What to do / Must NOT do: Create `bootstrap/AGENTS.md.tpl` describing a bootstrapped project (post-sed-rewrite becomes the project's own root AGENTS.md). Sections:
    - Preamble ("When to read this" — targets agents working on the project)
    - `# __PROJECT_NAME__` + one-liner "Module: `__PROJECT_MODULE__`."
    - `## Dev environment` — `cd docker && docker compose up -d && docker exec -it __project_prefix__-dev bash`; opencode/claude preinstalled inside
    - `## Parallel worktrees for test isolation` — reference `docker_inner/AGENTS.md`; the `make dev-up` + `TEST_ENV_FILE=$PWD/.env.testing go test -race ./...` + `make dev-down` pattern; explicit note that `make dev-up` from main checkout exits 64 by design
    - `## Layout` — bullet: `docker/`, `docker_inner/`, `cmd/__project_prefix__/` (if skeleton), `bootstrap/` (kept as reference if KEEP_BOOTSTRAP=yes; instructions to add more services later via `bootstrap/services/README.md`)
    - `## Bootstrap history` — "Bootstrapped from `mehr-it/ai-template`; template updates cherry-picked manually; no re-bootstrap."
  MUST NOT reference `TEMPLATE_UNINITIALIZED` (it's gone post-bootstrap). MUST NOT include the interview protocol.
  Parallelization: Wave 3 | Blocked by: 14 (needs to reference docker_inner/AGENTS.md structure) | Blocks: 34
  References: `docker/`, `docker_inner/AGENTS.md`, `bootstrap/services/README.md`
  Acceptance criteria: `test -s bootstrap/AGENTS.md.tpl && grep -q '__PROJECT_NAME__' bootstrap/AGENTS.md.tpl && grep -q '__PROJECT_MODULE__' bootstrap/AGENTS.md.tpl && grep -q '__project_prefix__' bootstrap/AGENTS.md.tpl && ! grep -q 'TEMPLATE_UNINITIALIZED' bootstrap/AGENTS.md.tpl && grep -q 'exit 64\|exits 64' bootstrap/AGENTS.md.tpl`
  QA scenarios: happy = after sed rewrite by bootstrap step 11, the resulting AGENTS.md is a coherent project doc with no stray placeholders; failure = if placeholder unbalanced, verify with `grep -c '__PROJECT_' bootstrap/AGENTS.md.tpl` and adjust. Evidence `.omo/evidence/task-20-tpl.txt`
  Commit: Y | `feat(bootstrap): add AGENTS.md.tpl (post-bootstrap root replacement)`

- [x] 21. `bootstrap/README.md`: One-paragraph explainer stating "don't run anything from here directly" — expect clear directory-purpose guidance for humans/agents
  What to do / Must NOT do: Create `bootstrap/README.md` (< 100 words): explain that this dir drives one-time template initialization; agents follow `AGENTS.md` here (invoked from root AGENTS.md); humans don't run things from this directory directly — the owner tells their agent to use the parent repo URL. Note that post-bootstrap, this dir may be kept as reference so new services can be added via `services/README.md`. MUST NOT duplicate the protocol.
  Parallelization: Wave 3 | Blocked by: none | Blocks: none
  References: `bootstrap/AGENTS.md`, root `AGENTS.md`
  Acceptance criteria: `test -s bootstrap/README.md && [ "$(wc -w < bootstrap/README.md)" -lt 150 ] && grep -qi "don.t run" bootstrap/README.md && grep -q 'AGENTS.md' bootstrap/README.md`
  QA scenarios: happy = human reading knows the dir's purpose without opening AGENTS.md; failure = if too long or duplicative, trim. Evidence `.omo/evidence/task-21-readme.txt` (word count + cat)
  Commit: Y | `docs(bootstrap): add README explaining directory purpose`

<!-- =========================================================================
     WAVE 4 — Bootstrap library: services + go-skeleton (8 todos: 22-29)
     ========================================================================= -->

- [x] 22. `bootstrap/services/postgres.yml`: Author generalized postgres service with `__project_prefix__` user/db + `runtime: runc` — expect bootstrap can cp+sed to wire postgres into `docker_inner/`
  What to do / Must NOT do: Create `bootstrap/services/postgres.yml`. Content: header comment ("Copied into docker_inner/postgres.yml during bootstrap when the owner picks postgres. Placeholders below (`__project_prefix__`) are sed-rewritten by bootstrap."); `services.postgres` with `image: postgres:17-alpine`, `runtime: runc` (NOT sysbox-runc — that's outer-only), `environment` block with `POSTGRES_USER: __project_prefix__`, `POSTGRES_PASSWORD: __project_prefix__`, `POSTGRES_DB: __project_prefix___test` (three underscores between prefix and `test`); `volumes: - postgres_data:/var/lib/postgresql/data`; `ports: - "127.0.0.1::5432"` (dynamic host port); healthcheck `["CMD-SHELL", "pg_isready -U __project_prefix__ -d __project_prefix___test"]` with `interval: 5s`, `timeout: 5s`, `retries: 20`; top-level `volumes: postgres_data:`.
  MUST NOT use hardcoded `wasi` username. MUST NOT set `runtime: sysbox-runc`. MUST NOT bind a fixed host port (must be ephemeral `127.0.0.1::5432`).
  Parallelization: Wave 4 | Blocked by: 10, 11 (references marker conventions in docker_inner) | Blocks: 34
  References: `example/docker_inner/postgres.yml:1-21` (source pattern), `docker_inner/docker-compose.yml` marker (task 11)
  Acceptance criteria: `test -s bootstrap/services/postgres.yml && grep -q '__project_prefix__' bootstrap/services/postgres.yml && ! grep -q 'wasi' bootstrap/services/postgres.yml && grep -q 'runtime: runc' bootstrap/services/postgres.yml && ! grep -q 'runtime: sysbox' bootstrap/services/postgres.yml && grep -q '127.0.0.1::5432' bootstrap/services/postgres.yml`
  QA scenarios: happy = `sed 's/__project_prefix__/testproj/g' bootstrap/services/postgres.yml | docker compose -f - config` renders without errors; failure = if YAML indentation broken (postgres compose files are tab-sensitive in ports/environment blocks), fix. Evidence `.omo/evidence/task-22-postgres-yml.txt`
  Commit: Y | `feat(bootstrap): add postgres service snippet`

- [x] 23. `bootstrap/services/postgres.env.snippet`: Author .env.testing DSN fragment with `__POSTGRES_PORT__` placeholder — expect bootstrap appends to project's `.env.testing.template`
  What to do / Must NOT do: Create `bootstrap/services/postgres.env.snippet` with:
  ```
  # Postgres DSN (dynamic port set by up.sh at each dev-up).
  __PROJECT_PREFIX___POSTGRES_DSN=postgres://__project_prefix__:__project_prefix__@127.0.0.1:__POSTGRES_PORT__/__project_prefix___test?sslmode=disable
  ```
  MUST NOT include real credentials. MUST NOT hardcode a port number (must use `__POSTGRES_PORT__`). Filename intentionally lacks `.sh`/`.env` extension so it's clearly a fragment, not a runnable file.
  Parallelization: Wave 4 | Blocked by: 13 (references marker + placeholder pattern) | Blocks: 34
  References: `bootstrap/services/postgres.yml` (task 22), `docker_inner/.env.testing.template` (task 13)
  Acceptance criteria: `test -s bootstrap/services/postgres.env.snippet && grep -q '__POSTGRES_PORT__' bootstrap/services/postgres.env.snippet && grep -q '__PROJECT_PREFIX___POSTGRES_DSN' bootstrap/services/postgres.env.snippet && grep -q '__project_prefix__' bootstrap/services/postgres.env.snippet`
  QA scenarios: happy = every non-comment line is valid KEY=VALUE (`awk -F= 'NF < 2 && !/^\s*#/ {exit 1}' bootstrap/services/postgres.env.snippet` returns 0); failure = if KEY has spaces or equals sign missing, fix. Evidence `.omo/evidence/task-23-env-snippet.txt`
  Commit: Y | `feat(bootstrap): add postgres env snippet`

- [x] 24. `bootstrap/services/postgres.up-snippet.sh`: Author `up.sh` port-discovery fragment for postgres — expect bootstrap splices into `up.sh` at `# BOOTSTRAP_SERVICE_PORTS` marker
  What to do / Must NOT do: Create `bootstrap/services/postgres.up-snippet.sh`:
  ```
  # Postgres port discovery (spliced into up.sh at BOOTSTRAP_SERVICE_PORTS by bootstrap).
    POSTGRES_PORT="$(_get_port postgres 5432)"
    sed -i "s/__POSTGRES_PORT__/${POSTGRES_PORT}/g" "${TMPFILE}"
  ```
  Two-space leading indent on the two functional lines matches the `(flock ...)` subshell body indent in `up.sh`. MUST NOT redefine `_get_port` (it lives in up.sh already). MUST NOT include a shebang (this is a fragment, not a standalone script).
  Parallelization: Wave 4 | Blocked by: 10 (references up.sh marker + `_get_port` helper) | Blocks: 32, 34
  References: `docker_inner/up.sh` around `# BOOTSTRAP_SERVICE_PORTS` marker (task 10), `docker_inner/up.sh:33-48` (`_get_port` helper preserved in task 10)
  Acceptance criteria: `test -s bootstrap/services/postgres.up-snippet.sh && grep -q '_get_port postgres 5432' bootstrap/services/postgres.up-snippet.sh && grep -q 'sed -i "s/__POSTGRES_PORT__' bootstrap/services/postgres.up-snippet.sh && ! head -1 bootstrap/services/postgres.up-snippet.sh | grep -q '#!' && bash -n bootstrap/services/postgres.up-snippet.sh`
  QA scenarios: happy = after splicing into a copy of up.sh, `bash -n <spliced-up.sh>` still passes; failure = if indent mismatched, `bash -n` may still pass but visual review flags — verify with `cat -A bootstrap/services/postgres.up-snippet.sh` shows two-space indent on functional lines. Evidence `.omo/evidence/task-24-up-snippet.txt`
  Commit: Y | `feat(bootstrap): add postgres up.sh snippet`

- [ ] 25. `bootstrap/services/README.md`: Author 3-step add-a-service recipe + snippet-triplet convention + catalog + contributor guide — expect agents and humans can add new services
  What to do / Must NOT do: Create `bootstrap/services/README.md`. Required sections:
    - `# bootstrap/services/` — one-liner "Snippet library for services that can be added to `docker_inner/` during bootstrap or later."
    - `## Snippet convention (per service)` — table with three files (`<svc>.yml`, `<svc>.env.snippet`, `<svc>.up-snippet.sh`), their purpose, and splice targets (docker-compose.yml `include:` / `.env.testing.template` `BOOTSTRAP_ENV_LINES` / `up.sh` `BOOTSTRAP_SERVICE_PORTS`)
    - `## Current catalog` — table with one row: `postgres` = reference (postgres:17-alpine, dynamic port, pg_isready healthcheck, user/db = `__project_prefix__`)
    - `## Add-a-service (post-bootstrap, without re-running bootstrap)` — 3-step recipe: (1) drop new file trio; (2) splice into docker_inner/ (cp yml, add include line, insert up-snippet at marker, append env-snippet at marker, add status.sh row at marker); (3) `make dev-reset` in a worktree to verify healthy startup
    - `## Contribute a new snippet` — pointer to copy `postgres.*` triplet as a starting point; keep placeholders consistent (`__PROJECT_PREFIX__`, `__project_prefix__`, `__<SVC>_PORT__`)
  MUST NOT list services that don't exist here yet. MUST reference the exact marker names.
  Parallelization: Wave 4 | Blocked by: 22, 23, 24 | Blocks: none
  References: `bootstrap/services/postgres.{yml,env.snippet,up-snippet.sh}` (tasks 22-24), `docker_inner/*` markers (tasks 10, 11, 13)
  Acceptance criteria: `test -s bootstrap/services/README.md && grep -q 'BOOTSTRAP_SERVICE_PORTS' bootstrap/services/README.md && grep -q 'BOOTSTRAP_SUMMARY_LINES' bootstrap/services/README.md && grep -q 'BOOTSTRAP_STATUS_ROWS' bootstrap/services/README.md && grep -q 'BOOTSTRAP_ENV_LINES' bootstrap/services/README.md && grep -q 'BOOTSTRAP_SERVICE_INCLUDES' bootstrap/services/README.md && grep -qi 'add-a-service\|add a service' bootstrap/services/README.md && grep -q 'postgres' bootstrap/services/README.md`
  QA scenarios: happy = an agent following this recipe can wire in a new service without reading `bootstrap/AGENTS.md`; failure = if any marker name inconsistent with actual scripts, fix. Evidence `.omo/evidence/task-25-services-readme.txt`
  Commit: Y | `docs(bootstrap): add services README with 3-step add-a-service recipe`

- [x] 26. `bootstrap/go-skeleton/go.mod.tpl`: Author go.mod template with `__PROJECT_MODULE__` + `go 1.26` directive — expect bootstrap copies + rewrites to project-root go.mod
  What to do / Must NOT do: Create `bootstrap/go-skeleton/go.mod.tpl`:
  ```
  module __PROJECT_MODULE__

  go 1.26
  ```
  Matches `go1.26.2` installed in Dockerfile. MUST NOT add `require` blocks (fresh skeleton has no deps). MUST NOT hardcode a module path.
  Parallelization: Wave 4 | Blocked by: none | Blocks: 34
  References: `bootstrap/AGENTS.md` step 10 (task 19), `docker/Dockerfile:18-21`
  Acceptance criteria: `test -s bootstrap/go-skeleton/go.mod.tpl && grep -q '^module __PROJECT_MODULE__$' bootstrap/go-skeleton/go.mod.tpl && grep -q '^go 1\.' bootstrap/go-skeleton/go.mod.tpl`
  QA scenarios: happy = `sed 's|__PROJECT_MODULE__|example.com/test|' bootstrap/go-skeleton/go.mod.tpl > /tmp/go.mod && cd /tmp && go mod tidy` succeeds (no deps to fetch); failure = if go version drift (Dockerfile has 1.26.2 but tpl says 1.25), align. Evidence `.omo/evidence/task-26-go-mod-tpl.txt`
  Commit: Y | `feat(bootstrap): add go.mod skeleton template`

- [x] 27. `bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/main.go.tpl`: Author minimal `package main` hello-world with `__PROJECT_NAME__` placeholder — expect scaffolded project compiles
  What to do / Must NOT do: `mkdir -p bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/`. Create `bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/main.go.tpl`:
  ```
  package main

  import "fmt"

  func main() {
      fmt.Println("hello from __PROJECT_NAME__")
  }
  ```
  Directory name literally contains `__PROJECT_SLUG__` — bootstrap step 10 renames it. MUST NOT add third-party imports (stdlib-only). MUST NOT pick a framework.
  Parallelization: Wave 4 | Blocked by: none | Blocks: 34
  References: `bootstrap/AGENTS.md` step 10 (task 19)
  Acceptance criteria: `test -f 'bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/main.go.tpl' && grep -q 'package main' 'bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/main.go.tpl' && grep -q '__PROJECT_NAME__' 'bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/main.go.tpl'`
  QA scenarios: happy = after rename + sed rewrite, `go build ./...` succeeds in a project with the go.mod from task 26; failure = if compilation fails (unlikely — hello world has no non-fmt imports), inspect. Evidence `.omo/evidence/task-27-main-tpl.txt`
  Commit: Y | `feat(bootstrap): add cmd/main.go skeleton template`

- [x] 28. `bootstrap/go-skeleton/Makefile.tpl`: Author build/test/dev-* targets with tab indentation preserved — expect scaffolded project has usable Makefile
  What to do / Must NOT do: Create `bootstrap/go-skeleton/Makefile.tpl` with TAB indentation for recipe lines (critical — Make requires tabs):
  ```
  # __PROJECT_NAME__ — Makefile

  .PHONY: build test dev-up dev-down dev-reset dev-status dev-prune

  build:
  <TAB>go build -o ./bin/__project_prefix__ ./cmd/...

  test:
  <TAB>go test -race ./...

  dev-up:
  <TAB>@bash docker_inner/up.sh

  dev-down:
  <TAB>@bash docker_inner/down.sh

  dev-reset:
  <TAB>@bash docker_inner/reset.sh

  dev-status:
  <TAB>@bash docker_inner/status.sh

  dev-prune:
  <TAB>@bash docker_inner/prune.sh
  ```
  (Substitute `<TAB>` with a literal tab character (`\t`). Use `printf '\t'` or a tab-aware editor.) MUST NOT use spaces on recipe lines. MUST NOT add `wget`/`curl` to build recipe.
  Parallelization: Wave 4 | Blocked by: none | Blocks: 32, 34
  References: `docker_inner/{up,down,reset,status,prune}.sh` (task 10)
  Acceptance criteria: `test -s bootstrap/go-skeleton/Makefile.tpl && grep -qP '^\t' bootstrap/go-skeleton/Makefile.tpl && grep -q 'dev-up:' bootstrap/go-skeleton/Makefile.tpl && grep -q 'dev-prune:' bootstrap/go-skeleton/Makefile.tpl && grep -q '__project_prefix__' bootstrap/go-skeleton/Makefile.tpl && [ "$(grep -c '^\t' bootstrap/go-skeleton/Makefile.tpl)" -ge 7 ]` (at least 7 tab-indented recipe lines: build/test + 5 dev-* targets)
  QA scenarios: happy = after sed rewrite, `make -n -f bootstrap/go-skeleton/Makefile.tpl build 2>&1 | grep -q "go build"` (dry-run recipe expansion works); failure = if tabs become spaces, Make prints `*** missing separator. Stop.` → verify `cat -A bootstrap/go-skeleton/Makefile.tpl` shows `^I` at recipe lines. Evidence `.omo/evidence/task-28-makefile-tpl.txt` (cat -A output)
  Commit: Y | `feat(bootstrap): add Makefile skeleton template with dev-* targets`

- [x] 29. `bootstrap/go-skeleton/README.md`: One-line explainer of skeleton contents + rename map — expect agent/owner knows what's here
  What to do / Must NOT do: Create `bootstrap/go-skeleton/README.md` (< 100 words): "Optional Go module skeleton copied into project root during bootstrap when owner picks Y for Go skeleton. Placeholders (`__PROJECT_MODULE__`, `__project_prefix__`, `__PROJECT_NAME__`, dir `__PROJECT_SLUG__`) are sed-rewritten. Files: `go.mod.tpl` → `go.mod` at project root; `cmd/__PROJECT_SLUG__/main.go.tpl` → `cmd/<binary>/main.go`; `Makefile.tpl` → `Makefile` at project root (build/test/dev-up/dev-down/dev-reset/dev-status/dev-prune)." MUST NOT duplicate the protocol.
  Parallelization: Wave 4 | Blocked by: none | Blocks: none
  References: `bootstrap/AGENTS.md` step 10 (task 19)
  Acceptance criteria: `test -s bootstrap/go-skeleton/README.md && [ "$(wc -w < bootstrap/go-skeleton/README.md)" -lt 150 ] && grep -q 'go.mod.tpl' bootstrap/go-skeleton/README.md && grep -q 'Makefile.tpl' bootstrap/go-skeleton/README.md && grep -q 'main.go.tpl' bootstrap/go-skeleton/README.md`
  QA scenarios: happy = reader immediately understands the dir's role and the rename map; failure = trivial file, unlikely to fail. Evidence `.omo/evidence/task-29-go-skeleton-readme.txt`
  Commit: Y | `docs(bootstrap): add go-skeleton README`

<!-- =========================================================================
     WAVE 5 — Cleanup + final verification (6 todos: 30-35)
     ========================================================================= -->

- [ ] 30. `example/`: Delete entire directory — expect repo top-level is `docker/`, `docker_inner/`, `bootstrap/`, and root files
  What to do / Must NOT do: `rm -rf example/`. Verify with `ls -1` afterwards. MUST NOT delete anything outside `example/`. MUST NOT run before tasks 8, 22, 23, 24 completed (they consume from `example/`).
  Parallelization: Wave 5 | Blocked by: 8, 22, 23, 24 (all consumers of `example/`) | Blocks: 35
  References: `example/docker_inner/*` (to delete)
  Acceptance criteria: `! test -e example && test -d docker && test -d docker_inner && test -d bootstrap && test -f AGENTS.md && test -f README.md && test -f TEMPLATE_UNINITIALIZED`
  QA scenarios: happy = `find example -type f 2>&1 | head -1` returns "No such file or directory"; failure = if adjacent dirs accidentally deleted, `git restore` immediately. Evidence `.omo/evidence/task-30-ls-after-delete.txt` (`ls -la` output)
  Commit: Y | `chore: delete example/ directory (contents templated into docker_inner/ and bootstrap/)`

- [x] 31. `.gitignore` (root): Create with env/worktree/db exclusions + commented Go build outputs — expect owner-inherited .gitignore covers common cases without ignoring bootstrap/ or the marker
  What to do / Must NOT do: Create root `.gitignore`:
  ```
  # Local env overrides (secrets, dev-only settings)
  .env
  .env.testing
  .env.local
  .env.local.testing
  docker/.env

  # Per-worktree state (worktree dirs are conventionally at .worktrees/)
  .worktrees/

  # SQLite DBs from tests
  *.db
  *-shm
  *-wal

  # Go build outputs (post-bootstrap — uncomment after scaffolding)
  # /bin/
  # /dist/
  # *.test
  # *.out
  # coverage.*
  ```
  MUST NOT ignore `.env.example` (committed). MUST NOT ignore `bootstrap/` (kept as reference post-bootstrap). MUST NOT ignore `TEMPLATE_UNINITIALIZED` (needs to be tracked pre-bootstrap so a fresh clone has it).
  Parallelization: Wave 5 | Blocked by: none | Blocks: none
  References: `example/docker_inner/.gitignore` (unchanged in `docker_inner/.gitignore` via task 8), `.idea/.gitignore` (untouched)
  Acceptance criteria: `test -s .gitignore && grep -q '^\.env$' .gitignore && grep -q '^\.env\.testing$' .gitignore && grep -q '^docker/\.env$' .gitignore && ! grep -q '^bootstrap/' .gitignore && ! grep -q '^TEMPLATE_UNINITIALIZED' .gitignore && ! grep -q '^\.env\.example' .gitignore`
  QA scenarios: happy = `git check-ignore -q .env.testing` exits 0 (ignored); `git check-ignore -q bootstrap/AGENTS.md` exits 1 (not ignored); `git check-ignore -q TEMPLATE_UNINITIALIZED` exits 1 (not ignored — must be tracked); failure = if any assertion inverts, fix .gitignore. Evidence `.omo/evidence/task-31-gitignore.txt`
  Commit: Y | `chore: add root .gitignore`

- [ ] 32. `.omo/evidence/task-32-bash-syntax.txt`: Full `bash -n` sweep across every `.sh` under `docker/`, `docker_inner/`, `bootstrap/**` (including snippet fragments) — expect all pass
  What to do / Must NOT do: `{ find docker docker_inner bootstrap -type f -name '*.sh' | sort | while read -r f; do printf '=== %s ===\n' "$f"; if bash -n "$f" 2>&1; then echo OK; else echo FAIL; fi; done; } > .omo/evidence/task-32-bash-syntax.txt 2>&1`. Include `bootstrap/services/*.up-snippet.sh` (fragments must parse standalone). MUST NOT skip any `.sh` file.
  Parallelization: Wave 5 | Blocked by: 10, 24, 28 | Blocks: none
  References: outputs of tasks 2 (renamed entrypoint.sh), 10 (docker_inner scripts), 24 (postgres.up-snippet.sh), 28 (Makefile.tpl is NOT bash — separate check)
  Acceptance criteria: `! grep -q FAIL .omo/evidence/task-32-bash-syntax.txt && [ "$(grep -c '=== ' .omo/evidence/task-32-bash-syntax.txt)" -ge 8 ]` (expect ≥ 8 scripts: entrypoint.sh + 5 docker_inner/*.sh + lib/slug.sh + postgres.up-snippet.sh)
  QA scenarios: happy = every listed line pair `=== <file> ===\nOK`; failure = any FAIL → identify offender and revisit its authoring task. Evidence `.omo/evidence/task-32-bash-syntax.txt`
  Commit: N (validation only)

- [ ] 33. `.omo/evidence/task-33-outer-compose-*.txt`: Re-run `docker compose config` on `docker/docker-compose.yml` both with/without `.env` — expect both exit 0 (post-Wave-2 state)
  What to do / Must NOT do: Same as task 7, re-run to capture the state after any Wave 2+ changes. `docker compose -f docker/docker-compose.yml config > .omo/evidence/task-33-outer-compose-no-env.txt 2>&1` (no .env). Then `cp docker/.env.example docker/.env && docker compose -f docker/docker-compose.yml config > .omo/evidence/task-33-outer-compose-with-env.txt 2>&1; rm docker/.env`. MUST clean up test `docker/.env` at end.
  Parallelization: Wave 5 | Blocked by: 4, 5 | Blocks: none
  References: `docker/docker-compose.yml`, `docker/.env.example`
  Acceptance criteria: `grep -q 'container_name: ai-template-dev' .omo/evidence/task-33-outer-compose-no-env.txt && grep -q 'container_name:' .omo/evidence/task-33-outer-compose-with-env.txt && ! test -e docker/.env && ! grep -qi 'error' .omo/evidence/task-33-outer-compose-no-env.txt`
  QA scenarios: happy = both files non-empty, no `error` lines; failure = if compose config fails, revisit tasks 4-5. Evidence `.omo/evidence/task-33-outer-compose-*.txt`
  Commit: N (validation only)

- [ ] 34. `.omo/evidence/task-34-e2e-dryrun.log`: **Load-bearing gate** — copy repo to `/tmp/`, invoke `bootstrap/AGENTS.md` non-interactively via `BOOTSTRAP_ANSWERS_FILE`, verify every assertion — expect PASS on all 12 checks (A1-A12)
  What to do / Must NOT do:
    (0) **Compose version preflight:** `docker compose version 2>&1 | grep -qE 'v2\.(2[0-9]|[3-9][0-9])' || { echo "Compose v2.20+ required for include: [] support"; exit 1; }`. If preflight fails, abort with a clear message pointing at task 11's fallback (change `include: []` → omit key + `services: {}`).
    (1) `E2E_DIR="/tmp/ai-template-e2e-$(date +%s)"; cp -a "$(pwd)" "$E2E_DIR"; cd "$E2E_DIR"; rm -rf "$E2E_DIR/.omo"`. **Removing `.omo/` is intentional** — the source repo has plan artifacts under `.omo/` that would otherwise pollute the placeholder sweep (A2); the bootstrap protocol's exclusion list still handles a missing `.omo/` correctly (it just excludes a non-existent dir).
    (2) Write `/tmp/answers-$$.env`:
    ```
    TARGET_DIR=.
    PROJECT_NAME=TestProj
    PROJECT_PREFIX=TESTPROJ
    project_prefix=testproj
    PROJECT_MODULE=example.com/testproj
    SERVICES=postgres
    GO_SKELETON=yes
    BINARY=testproj
    FRESH_GIT=no
    COMMIT=no
    KEEP_BOOTSTRAP=yes
    BOOTSTRAP_TEMPLATE_SHA=e2e-dryrun
    ```
    (3) Execute the 17-step protocol (steps 0-16) from `bootstrap/AGENTS.md` — either the executing agent follows it manually with the answers file, or a small driver script scripted-executes each numbered step (agent's choice; the protocol is designed to be scriptable).
    (4) After bootstrap completes, run 12 assertions (each fails the task if false):
      A1. `! test -e "$E2E_DIR/TEMPLATE_UNINITIALIZED"`
      A2. `! grep -ERn '__PROJECT_[A-Z_]+__|__project_prefix__' "$E2E_DIR" --exclude-dir=bootstrap --exclude-dir=.git --exclude-dir=.omo` — **portable ERE syntax** (`grep -E`, no GNU-specific `\|`); explicit uppercase `[A-Z_]+` bounds prevent matching partial words.
      A3. `test -f "$E2E_DIR/docker_inner/postgres.yml"`
      A4. `grep -q 'TESTPROJ_POSTGRES_DSN' "$E2E_DIR/docker_inner/.env.testing.template"`
      A5. `grep -q '_get_port postgres 5432' "$E2E_DIR/docker_inner/up.sh"`
      A6. `test -f "$E2E_DIR/go.mod" && grep -q 'module example.com/testproj' "$E2E_DIR/go.mod"`
      A7. `docker compose -f "$E2E_DIR/docker/docker-compose.yml" config >/dev/null`
      A8. `TESTPROJ_STACK_SLUG=test docker compose -f "$E2E_DIR/docker_inner/docker-compose.yml" config >/dev/null`
      A9. `test -f "$E2E_DIR/cmd/testproj/main.go" && grep -q 'hello from TestProj' "$E2E_DIR/cmd/testproj/main.go"`
      A10. `grep -q '# Generated by docker_inner/up.sh' "$E2E_DIR/docker_inner/.env.testing.template"` — **`down.sh` deletion heuristic depends on this header surviving bootstrap's sed rewrite; if lost, `down.sh` won't delete generated `.env.testing`.**
      A11. `grep -q 'TESTPROJ_STACK_SLUG' "$E2E_DIR/docker_inner/lib/slug.sh" && ! grep -q 'TESTPROJ__STACK_SLUG' "$E2E_DIR/docker_inner/lib/slug.sh"` — **triple-underscore reduction check:** template file had `__PROJECT_PREFIX___STACK_SLUG` (three underscores); bootstrap sed should reduce to `TESTPROJ_STACK_SLUG` (single underscore between prefix and STACK), NOT `TESTPROJ__STACK_SLUG` (double).
      A12. `test -f "$E2E_DIR/AGENTS.md" && ! grep -q 'TEMPLATE_UNINITIALIZED' "$E2E_DIR/AGENTS.md" && grep -q 'TestProj' "$E2E_DIR/AGENTS.md"` — **root `AGENTS.md` was replaced from `bootstrap/AGENTS.md.tpl` in step 11** (no template-marker reference, contains project name).
    (5) Capture full log (commands + outputs + per-assertion PASS/FAIL + summary line `E2E: PASS` or `E2E: FAIL`) to `.omo/evidence/task-34-e2e-dryrun.log`.
    (6) Cleanup: `rm -rf "$E2E_DIR" /tmp/answers-$$.env`.
  MUST NOT leave the tempdir behind. MUST NOT modify the source repo (only the copy). MUST log every assertion with visible PASS/FAIL. If any assertion fails, the log records which and the task FAILS overall. MUST use portable ERE syntax for grep (compose environments may be non-GNU).
  Parallelization: Wave 5 | Blocked by: ALL previous todos | Blocks: none
  References: `bootstrap/AGENTS.md` (task 19), all Wave 1-4 outputs
  Acceptance criteria: `grep -q '^E2E: PASS$' .omo/evidence/task-34-e2e-dryrun.log && [ "$(grep -c '^A[0-9]*: PASS$' .omo/evidence/task-34-e2e-dryrun.log)" -ge 12 ] && ! ls -d /tmp/ai-template-e2e-* 2>/dev/null` (tempdir cleaned up)
  QA scenarios: happy = log ends with `E2E: PASS` and all 12 assertions individually pass; failure = any assertion FAIL → the log identifies which wave's output is broken (e.g. A5 fail → task 24 or task 10 marker mismatch; A10 fail → sed accidentally rewrote the `# Generated by` header; A11 fail → triple-underscore convention broken in slug.sh); re-run after fix. Evidence `.omo/evidence/task-34-e2e-dryrun.log`
  Commit: N (validation only, but log stays committed under `.omo/evidence/`)

- [ ] 35. `.omo/evidence/task-35-grep-sweep.txt`: Anti-regression grep — assert no `WASI_`/`wasi_`/`wasi-bridge`/`signal-cli`/`whatsmeow`/`entyrpoint` survives outside `.git/` and `.omo/` — expect empty result (zero matches)
  What to do / Must NOT do: `grep -RnE 'WASI_|wasi_|wasi-bridge|signal-cli|whatsmeow|entyrpoint' . --exclude-dir=.git --exclude-dir=.omo --exclude-dir=.idea > .omo/evidence/task-35-grep-sweep.txt 2>&1 || true`. Also run the same sweep against `.git/` deliberately excluded to make sure the pattern actually matches (sanity check the regex). MUST NOT exclude anything else beyond `.git/`, `.omo/`, `.idea/`. If file is non-empty, treat as FAIL — surface for inspection.
  Parallelization: Wave 5 | Blocked by: 30 (example/ deletion is the biggest source of stale WASI strings) | Blocks: none
  References: outputs of tasks 9, 10, 11, 13, 14, 30
  Acceptance criteria: `test ! -s .omo/evidence/task-35-grep-sweep.txt` (empty file = clean sweep)
  QA scenarios: happy = zero-byte file, meaning no stale strings; failure = any match → identify the surviving string, fix in the offending source, re-run. Log the non-empty content so the fix is obvious. Evidence `.omo/evidence/task-35-grep-sweep.txt`
  Commit: N (validation only; log committed if non-empty for diagnosis)

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit
- [ ] F2. Code quality review
- [ ] F3. Real manual QA
- [ ] F4. Scope fidelity

## Commit strategy

**One commit per todo** where `Commit: Y`; validation-only todos (`Commit: N`) leave evidence under `.omo/evidence/` but do not commit. All commits use Conventional Commits format (`<type>(<scope>): <summary>`).

**Commit types used in this plan:**
- `fix(docker):` — bug fixes in `docker/` (typo, missing mount, missing default)
- `chore(docker):` — non-behavior cleanup (removing dead `op` user, seeding from `example/`)
- `feat(docker):` — new artifacts (`docker/.env.example`)
- `feat(docker_inner):` — generic template files
- `docs(docker_inner):` — generalized AGENTS.md
- `feat(bootstrap):` — bootstrap protocol, snippets, skeleton templates
- `docs(bootstrap):` — bootstrap README files
- `docs:` — root README + root AGENTS.md
- `feat:` — root-level features (TEMPLATE_UNINITIALIZED marker)
- `chore:` — root-level cleanup (delete `example/`, add `.gitignore`)

**Ordering (recommended commit sequence, aligned with wave order):**
1. Wave 1: `fix(docker): rename entyrpoint.sh → entrypoint.sh`, `chore(docker): remove unused op user block`, `fix(docker): add PROJECT_NAME fallback and explicit env_file`, `feat(docker): add .env.example with defaults`, `fix(docker): create opencode/config/ mount source placeholder` (task 1 evidence-only; task 7 validation-only).
2. Wave 2: `chore(docker_inner): seed template from example/`, `feat(docker_inner): rewrite slug.sh with placeholders`, `feat(docker_inner): rewrite lifecycle scripts with placeholders and service-injection markers`, `feat(docker_inner): make compose file service-empty with BOOTSTRAP_SERVICE_INCLUDES marker`, `chore(docker_inner): remove project-specific service files`, `feat(docker_inner): make .env.testing.template generic with BOOTSTRAP_ENV_LINES marker`, `docs(docker_inner): rewrite AGENTS.md as project-agnostic per-worktree stack guide` (task 15 validation-only).
3. Wave 3: `docs: add root AGENTS.md as agent entry point`, `docs: add root README.md with owner quickstart`, `feat: add TEMPLATE_UNINITIALIZED marker for bootstrap detection`, `feat(bootstrap): add authoritative 16-step bootstrap protocol`, `feat(bootstrap): add AGENTS.md.tpl (post-bootstrap root replacement)`, `docs(bootstrap): add README explaining directory purpose`.
4. Wave 4: `feat(bootstrap): add postgres service snippet`, `feat(bootstrap): add postgres env snippet`, `feat(bootstrap): add postgres up.sh snippet`, `docs(bootstrap): add services README with 3-step add-a-service recipe`, `feat(bootstrap): add go.mod skeleton template`, `feat(bootstrap): add cmd/main.go skeleton template`, `feat(bootstrap): add Makefile skeleton template with dev-* targets`, `docs(bootstrap): add go-skeleton README`.
5. Wave 5: `chore: delete example/ directory (contents templated into docker_inner/ and bootstrap/)`, `chore: add root .gitignore` (tasks 32-35 all validation-only, no commits — evidence lands in `.omo/evidence/`).

**Total: 26 commits** across 35 todos (9 tasks are validation-only or evidence-only: 1, 7, 15, 32, 33, 34, 35 + implicit "no commit" for the plan file changes themselves).

**Squash policy:** DO NOT squash. Every commit is an atomic step with a self-contained diff; the sequence tells the story of the restructure and makes reverts cheap if one wave introduces a regression.

**Branch:** stay on the current branch (whatever the worker checks out). This plan does NOT dictate a branch name — that's the worker's decision and depends on whether they're working on `main`, a feature branch, or a worktree.

## Success criteria

**The plan is complete when ALL of the following hold:**

1. **`docker/` builds cleanly:** `docker build -t ai-template-test docker/` completes at least through the `COPY entrypoint.sh` step without a "no such file" error (the full build may still need sysbox on host — that's out of scope, we only prove the Dockerfile references are correct). `docker compose -f docker/docker-compose.yml config` exits 0 both with and without `docker/.env` present.
2. **`docker_inner/` is project-agnostic:** every `WASI_*`, `wasi_*`, `signal-cli`, `whatsmeow`, `wasi-bridge`, `entyrpoint` string is gone (verified by task 35). Placeholders `__PROJECT_PREFIX__`, `__project_prefix__` appear where expected. `bash -n` passes on every shell script (task 32). `include: []` compose file renders with a dummy `__PROJECT_PREFIX___STACK_SLUG=test` env var.
3. **Root entry point is complete:** `AGENTS.md` (agent-facing), `README.md` (human-facing with the exact copyable owner prompt), and `TEMPLATE_UNINITIALIZED` marker exist at repo root. The root `.gitignore` covers env files but NOT `TEMPLATE_UNINITIALIZED` or `bootstrap/`.
4. **Bootstrap surface is executable:** `bootstrap/AGENTS.md` contains all 17 numbered steps (0-16), documents `BOOTSTRAP_ANSWERS_FILE` non-interactive mode with the required key list, and the sed order (`__PROJECT_MODULE__` first). `bootstrap/AGENTS.md.tpl` contains the four placeholders (`__PROJECT_NAME__`, `__PROJECT_MODULE__`, `__project_prefix__`, and NOT `TEMPLATE_UNINITIALIZED`).
5. **Service snippet library is coherent:** `bootstrap/services/` contains the `postgres.{yml,env.snippet,up-snippet.sh}` triplet plus `README.md`. Placeholders inside snippets match the sed rewrite pattern. The postgres `.yml` uses `runtime: runc` (not `sysbox-runc`).
6. **Go skeleton templates parse:** `bootstrap/go-skeleton/{go.mod.tpl, cmd/__PROJECT_SLUG__/main.go.tpl, Makefile.tpl}` exist. Makefile.tpl uses TAB indentation (verified). After sed rewrite of go.mod.tpl → go.mod with a test module path, `go mod tidy` succeeds (no external deps to fetch).
7. **`example/` is gone.** Repo top-level is exactly: dirs `docker/`, `docker_inner/`, `bootstrap/`, `.codegraph/`, `.idea/`, `.git/`, `.omo/`; files `AGENTS.md`, `README.md`, `TEMPLATE_UNINITIALIZED`, `.gitignore`, `opencode.jsonc`. Nothing else at root.
8. **The end-to-end dry-run passes** (task 34): non-interactive bootstrap on `/tmp/` copy with fixed answers produces a project where all 9 assertions pass (no surviving placeholders, marker deleted, postgres wired into 3 places, `go.mod` at root, both compose configs render, `main.go` compiles conceptually). Tempdir cleaned up.
9. **Anti-regression sweep is clean** (task 35): zero surviving `WASI_`/`wasi_`/`signal-cli`/`whatsmeow`/`wasi-bridge`/`entyrpoint` matches outside `.git/`, `.omo/`, `.idea/`.
10. **26 atomic commits landed** (per the Commit strategy sequence). Each commit's diff is self-contained and reverts cleanly.
11. **Final verification wave (F1-F4) all APPROVE** before declaring the plan complete.

**The plan is NOT complete if:**
- Any todo's acceptance criteria fails.
- The end-to-end dry-run (task 34) fails any assertion.
- The grep sweep (task 35) is non-empty.
- Any final-verification agent (F1-F4) rejects.
- The bootstrap agent would need to ask questions not covered by the interview.

**Runtime success (out of scope for this plan, but the plan's success enables it):** an owner types the quickstart prompt from `README.md` into their agent, the agent fetches this repo, follows `bootstrap/AGENTS.md`, and ends with a compilable `hello from <ProjectName>` binary and a working `make dev-up` inside a fresh worktree.
