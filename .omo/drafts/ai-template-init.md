---
slug: ai-template-init
status: approved
approval-received: 2026-07-31 (user replied "approve" to Option 1 revised brief)
intent: clear
review_required: false
distribution-model: docs-in-repo (Option 1)
pending-action: plan file written; awaiting user decision on start-work vs high-accuracy review
approach: |
  Turn this repo into a self-bootstrapping template for AI-driven Go projects that ANY agent (opencode, claude code, cursor, etc.) with `git`/`gh` + shell access can use. The owner, in an arbitrary working directory, tells their agent: "use github.com/mehr-it/ai-template to start a new Go AI project (into <target dir>)". The agent fetches the repo (via `gh repo clone` / `git clone` / a release tarball), reads root `AGENTS.md`, interviews the owner (target directory decision, project name, prefix, Go module path, optional services from `bootstrap/services/`, optional Go skeleton from `bootstrap/go-skeleton/`, fresh git yes/no), sed-rewrites `__PROJECT_NAME__` / `__PROJECT_PREFIX__` / `__project_prefix__` / `__PROJECT_MODULE__` placeholders across `docker/` (outer sysbox container) and `docker_inner/` (generic per-worktree scaffold), copies chosen service snippets into `docker_inner/` and wires them into the includes + port discovery + `.env.testing.template`, optionally scaffolds a Go module + `cmd/` + `Makefile`, replaces root `AGENTS.md` from `bootstrap/AGENTS.md.tpl` with placeholders filled in, deletes the `TEMPLATE_UNINITIALIZED` marker, optionally re-inits `.git/` for a fresh history and commits "Bootstrap from ai-template". From then on all dev happens inside the sysbox docker container as before. This plan ALSO fixes the pre-existing bugs in `docker/` (typo `entyrpoint.sh`, missing `opencode/config/` mount source, no `PROJECT_NAME` default, dead `op` user, undocumented sysbox prereq). No opencode plugin, no npm package, no `SKILL.md` — the repo is fully self-describing via `README.md` + `AGENTS.md` + `bootstrap/AGENTS.md` for any agent that visits it.
---

# Draft: ai-template-init

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->

| id | outcome (one line) | status | evidence path |
|---|---|---|---|
| C1 | `docker/` outer container is bug-free and ships with `PROJECT_NAME`/`UID`/`GID` env defaults | active | `docker/Dockerfile`, `docker/docker-compose.yml`, `docker/entyrpoint.sh` (typo) |
| C2 | `docker_inner/` is a project-agnostic per-worktree scaffold with `__PROJECT_PREFIX__`/`__project_prefix__` placeholders and an empty compose `include:` block | active | `example/docker_inner/*` (template source) |
| C3 | Root `README.md` + `AGENTS.md` are the entry point for ANY visiting agent — describe the repo, detect the un-bootstrapped state via `TEMPLATE_UNINITIALIZED`, delegate the workflow to `bootstrap/AGENTS.md` | active | none yet (new files) |
| C4 | `bootstrap/AGENTS.md` contains the authoritative agent-executable bootstrap protocol (target-dir decision, interview, sed rewrite, service wiring, optional Go skeleton, fresh git, commit); `bootstrap/AGENTS.md.tpl` is the post-bootstrap replacement for root `AGENTS.md` with placeholders | active | none yet (new files) |
| C5 | `bootstrap/services/` contains at least a `postgres.yml` reference snippet + README explaining the "how to add a service" pattern; `bootstrap/go-skeleton/` holds optional Go module scaffolding | active | `example/docker_inner/postgres.yml`, `example/docker_inner/AGENTS.md` (add-a-service pattern) |
| C6 | Cleanup: `example/` deleted, root `.gitignore` created, `TEMPLATE_UNINITIALIZED` marker created | active | `example/` (to delete), no root docs yet |
| C7 | Final verification: `docker compose config` on outer + a sample-bootstrapped inner, `bash -n` on all scripts, one non-interactive end-to-end bootstrap dry-run on `/tmp/` copy exercising the full agent workflow | active | plan-generated evidence under `.omo/evidence/` |

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->

| assumption | adopted default | rationale | reversible? |
|---|---|---|---|
| Distribution model | **Docs-in-repo only (Option 1)** — no opencode plugin, no npm package, no separate `SKILL.md`. Repo is published to a git host (assumed GitHub-shaped: `git clone <url>` and `gh repo clone <slug>` both work). | Confirmed by user answer. Any agent with `git` + shell + `webfetch` can consume the template with zero pre-install. | Yes — a future plan can wrap this same repo in a plugin/skill without changing the template itself |
| Invocation trigger | Owner tells agent explicitly: "use `github.com/mehr-it/ai-template` to start a new Go AI project (into `<target>`)" or equivalent. The agent recognizes the intent from the URL + verb, fetches the repo, reads `AGENTS.md`, follows the protocol. | With Option 1 there is no automatic trigger phrase — the owner names the repo URL. This is the only mechanism that works without pre-install. | N/A |
| Target directory decision | The bootstrap agent asks the owner in the interview: (a) clone into current working directory (only if cwd is empty or the intended project dir), (b) clone into a subdirectory of cwd (`./<slug>/`, recommended default), or (c) clone into an absolute path. Agent detects and warns if the target already contains files. | Owner controls filesystem layout. Auto-choosing would surprise. | Yes |
| Placeholder markers | `__PROJECT_NAME__` (human-readable, e.g. `MyAwesomeService`), `__PROJECT_PREFIX__` (UPPERCASE env var / compose prefix, e.g. `MYAWESOMESERVICE`), `__project_prefix__` (lowercase shell function + compose project name prefix, e.g. `myawesomeservice`), `__PROJECT_MODULE__` (Go module path, e.g. `github.com/user/myawesomeservice`) | Case-preserving sed replacement works with these four; matches the existing `__PLACEHOLDER__` convention already in `example/docker_inner/.env.testing.template` | Yes |
| Marker file name | `TEMPLATE_UNINITIALIZED` at repo root (empty, one-line-comment header). Bootstrap deletes it. Root `.gitignore` lists it so it doesn't reappear if a future template update adds it back. | Loud, obvious, no naming conflict; agent detects via file existence — reliable across every agent framework. Doubles as an idempotency guard: bootstrap agent aborts if marker is absent. | Yes |
| Compose stack prefix after bootstrap | `${__PROJECT_PREFIX__}` uppercase for env vars (`MYAWESOMESERVICE_STACK_SLUG`), `${__project_prefix__}` lowercase for compose project name (`myawesomeservice-<slug>`) | Matches WASI convention (`WASI_STACK_SLUG` + `wasi-<slug>`); consistent, greppable | Yes |
| Postgres snippet stays as reference | `bootstrap/services/postgres.yml` + a `bootstrap/services/README.md` documenting the 3-step "add a service" pattern | User asked for docs, not default-included. Postgres is the clearest worked example (from the WASI reference) | Yes |
| Root `AGENTS.md` uses the same "When to read this" preamble format as `example/docker_inner/AGENTS.md` | Yes | Consistent format across the template | Yes |
| Root `AGENTS.md` post-bootstrap replacement | `bootstrap/AGENTS.md.tpl` is a placeholder-filled template that bootstrap moves into place as the new root `AGENTS.md` at the end of bootstrap. The pre-bootstrap root `AGENTS.md` is *only* the "template-uninitialized" bootstrap protocol; after bootstrap, the root `AGENTS.md` describes the concrete project. | Cleaner than a conditional single file; keeps the pre-/post-bootstrap docs decoupled | Yes |
| `docker/` gets `docker/opencode/config/` created as an empty dir with a `.gitkeep` (instead of removing the mount) | Fits the existing compose intent — that's where per-project opencode config would live | Yes |
| `docker/.env.example` ships with `PROJECT_NAME=ai-template`, `UID=1000`, `GID=1000` documented. Bootstrap rewrites the `PROJECT_NAME` line to the owner's project. | Compose already reads `${PROJECT_NAME}` with no default, so a `.env` is required for the container name to be meaningful | Yes |
| Dockerfile keeps Ubuntu 24.04 + Go 1.26.2 + Node 26 + Docker + opencode + claude + codegraph exactly as-is (only the `op` user block and `entrypoint.sh` filename change) | Not the scope of this plan to reevaluate the base image toolchain | Yes (separate plan can bump versions) |
| Bootstrap fresh-git behavior | Bootstrap asks the owner: "initialize as a fresh git repo? (Y/n, default Y — removes template's git history and runs `git init` in the target)". Default Y because owners want their own history, not the template's. | Owners almost never want to inherit a template's git log. | Yes |
| Bootstrap commit behavior | Bootstrap asks: "commit after bootstrap? (Y/n, default Y — commits with message `Bootstrap from mehr-it/ai-template@<sha>`)". Records the template SHA for traceability. | Standard convention; the SHA lets owners see which template version they bootstrapped from. | Yes |
| Bootstrap cleanup of `bootstrap/` | Bootstrap asks: "keep `bootstrap/` directory as reference? (Y/n, default Y)". Keeping it lets the owner add more services later using the same snippet library and re-run individual sub-workflows. | Reversible; owner can `rm -rf bootstrap/` any time. | Yes |

## Findings (cited - path:lines)

**Repo structure** (`/home/chris/go/src/mehr-it.info/ai-template/`):
- Only top-level entries are `docker/`, `example/docker_inner/`, `opencode.jsonc`, `.codegraph/`, `.idea/`, `.git/`. No root `AGENTS.md`, `README.md`, `Makefile`, `.env`, `.env.example`, `.gitignore`.

**`docker/` — the outer sysbox dev container:**
- `docker/Dockerfile:1` — `FROM ubuntu:24.04`, `DEBIAN_FRONTEND=noninteractive`.
- `docker/Dockerfile:13-15` — creates user `op` with sudoers `/etc/sudoers.d/op`, then never switches to it. Line 35 uses `USER ubuntu` (the Ubuntu 24 default UID 1000 user). Dead code.
- `docker/Dockerfile:18-21` — installs Go 1.26.2 from tarball to `/usr/local/go`.
- `docker/Dockerfile:23-25` — installs Node.js 26 from NodeSource.
- `docker/Dockerfile:31-33` — grants passwordless sudo to the `ubuntu` group.
- `docker/Dockerfile:40-43` — installs opencode + claude CLI as `ubuntu`.
- `docker/Dockerfile:46` — sets `PATH=/home/ubuntu/.opencode/bin:/home/ubuntu/go/bin:/usr/local/go/bin:/home/ubuntu/.local/bin:$PATH`.
- `docker/Dockerfile:49-53` — installs `gopls`, `dlv`, `goimports`, `staticcheck`, `golangci-lint v2.12.2`.
- `docker/Dockerfile:63-65` — installs Docker inside the container (this is the sysbox nested-docker precondition).
- `docker/Dockerfile:68-69` — installs codegraph and registers it with opencode.
- `docker/Dockerfile:71-72` — `COPY entrypoint.sh /usr/local/bin/entrypoint.sh` + `ENTRYPOINT`. **BUG: the file on disk is `docker/entyrpoint.sh` (typo). Build fails.**
- `docker/docker-compose.yml:4` — `container_name: ${PROJECT_NAME}-dev` with **no default and no `.env` file** — compose renders `-dev` (bug).
- `docker/docker-compose.yml:5` — `runtime: sysbox-runc` (requires sysbox installed on host; nowhere documented).
- `docker/docker-compose.yml:12` — mounts `./opencode/config/:/home/ubuntu/.config/opencode`, but `docker/opencode/config/` does not exist (bug — compose will create an empty bind, or fail on strict mounts).
- `docker/docker-compose.yml:16` — mounts parent `../:/home/ubuntu/workspace` (the whole repo is the workspace).
- `docker/docker-compose.yml:26` — memory limit 25G (matches example AGENTS.md concurrency note).
- `docker/entyrpoint.sh:4` — `sudo service docker start`.
- `docker/entyrpoint.sh:6-24` — lazily installs MCP packages (`@upstash/context7-mcp`, `@modelcontextprotocol/server-filesystem`, `@playwright/mcp@latest`) via `npm install --prefix "$HOME/.opencode"`.
- `docker/entyrpoint.sh:28-34` — writes a `opencode-ohno` wrapper that launches opencode with an alt config `opencode-no-open-agent.jsonc`.
- `docker/entyrpoint.sh:36-38` — `cd /home/ubuntu/workspace && codegraph init && exec opencode "$@"`.

**`example/docker_inner/` — the reference stack (to be templated into `docker_inner/`):**
- `example/docker_inner/AGENTS.md:1-136` — comprehensive per-worktree stack docs. WASI-specific. Contains the "add a service" 3-step recipe (lines 103-113) and the troubleshooting matrix (lines 128-136).
- `example/docker_inner/docker-compose.yml:3` — `name: wasi-${WASI_STACK_SLUG:?WASI_STACK_SLUG is required}` — required env var, no default.
- `example/docker_inner/docker-compose.yml:5-7` — `include: - signal-cli.yml - postgres.yml`.
- `example/docker_inner/up.sh:1-88` — flock-serialized start; `docker compose up -d --wait --wait-timeout 180`; polls dynamic ports; sed-renders `.env.testing` from template; idempotent (skips rewrite if ports match).
- `example/docker_inner/down.sh:18-21` — `down -v --remove-orphans` (wipes volumes = wipes signal-cli credentials).
- `example/docker_inner/down.sh:26-28` — deletes generated `.env.testing` if header matches.
- `example/docker_inner/prune.sh:1-102` — reaps `wasi-*` stacks whose worktree no longer exists; iterates `docker compose ls` + inspects container labels.
- `example/docker_inner/lib/slug.sh:1-50` — provides `wasi_resolve_worktree_root` (git rev-parse), `wasi_assert_not_main_checkout` (exit 64 if on main), `wasi_derive_slug` (sanitize + sha1[:8] hash of worktree path for uniqueness).
- `example/docker_inner/.env.testing.template:1-20` — WASI-specific env vars with `__SIGNAL_HTTP_PORT__` and `__POSTGRES_PORT__` placeholders.
- `example/docker_inner/postgres.yml` — postgres:17-alpine, `runtime: runc` (NOT sysbox-runc — only the outer container uses sysbox), `127.0.0.1::5432` ephemeral binding, healthcheck via `pg_isready`.
- `example/docker_inner/signal-cli.yml` — signal-cli daemon config (project-specific, will not be templated; the pattern is documented in AGENTS.md).
- `example/docker_inner/.gitignore` — only `/lock/`.

**`opencode.jsonc`:**
- Lines 4-14 — read allowlist already includes `.env.example`, `.env.local.testing`, `.env.testing`, `docker/.env`, `/docker_inner/*`.
- Lines 22-30 — write allowlist includes `.env.example`, `.env.testing`, `.env.local.testing`, `/docker_inner/*`. Does NOT explicitly include root new files (`AGENTS.md`, `README.md`, `bootstrap/**`, `TEMPLATE_UNINITIALIZED`) but the `**` in `external_directory` covers reads and the workspace is under the working directory. **No opencode.jsonc changes needed for this plan** — the bootstrap agent runs outside the container anyway.

## Decisions (with rationale)

| # | Decision | Rationale |
|---|---|---|
| D1 | Distribution model = **docs-in-repo only (Option 1)**. No opencode plugin, no npm package, no `SKILL.md`. Repo is published to a git host and consumed by ANY agent (opencode / claude code / cursor / plain shell) told the repo URL. | Explicit user choice ("1"). Widest reach, zero pre-install, no distribution infrastructure. Trade-off accepted: no automatic trigger phrase; owner must name the repo URL. |
| D2 | Invocation shape = **owner tells agent the repo URL + intent**. Example: "use `github.com/mehr-it/ai-template` to start a new Go AI project into `~/projects/foo/`". Agent fetches the repo (any of `git clone`, `gh repo clone`, `curl` + `tar` for a release tarball), reads root `AGENTS.md`, follows the protocol. | Only mechanism that works cross-agent with zero pre-install. Root `AGENTS.md` is the single-source-of-truth entry point. |
| D3 | `docker_inner/` ships **empty** of services. Agent interviews owner during bootstrap for which services they need, then copies snippets from `bootstrap/services/` into `docker_inner/`. | User answer to Q2 — "docker_inner should be empty; agent interviews owner". |
| D4 | Placeholder markers: `__PROJECT_NAME__` (human), `__PROJECT_PREFIX__` (upper), `__project_prefix__` (lower), `__PROJECT_MODULE__` (Go module path). | Case-preserving sed. Matches existing `__PLACEHOLDER__` convention. Bootstrap rewrites all four to concrete values. |
| D5 | Fix all pre-existing `docker/` bugs in this plan | User answer to Q4. |
| D6 | Bootstrap interview question: "scaffold a Go module skeleton?" (Y/N + module path). If Y: agent copies `bootstrap/go-skeleton/{go.mod.tpl,cmd/__PROJECT_SLUG__/main.go.tpl,Makefile.tpl}`, rewrites placeholders (the go.mod already contains `module __PROJECT_MODULE__` post-rewrite, so `go mod tidy` — NOT `go mod init` — is the right command; init would fail on an already-declared module). | User answer to Q5 — agent asks owner. |
| D7 | Postgres is the worked-example snippet under `bootstrap/services/postgres.yml` + `bootstrap/services/README.md` | User answer to Q2 — postgres is the reference example, not default-included. |
| D8 | `example/` directory is **deleted** at end of plan | User answer to Q2 — "The example directory will be removed and not part of the repo anymore." |
| D9 | Root `AGENTS.md` is the entry point for ANY visiting agent. Contains: what the repo is, `TEMPLATE_UNINITIALIZED` state detection, one-paragraph invocation of `bootstrap/AGENTS.md` for the actual workflow. After bootstrap, root `AGENTS.md` is replaced by the placeholder-filled `bootstrap/AGENTS.md.tpl`, which describes the concrete project. | Cleanest split between "how to bootstrap the template" (root, pre-bootstrap) and "how to develop the project" (root, post-bootstrap). Any agent that pulls the fresh repo reads `AGENTS.md` first — that's the universal convention. |
| D10 | Root `README.md` is human-facing (what the repo is, prerequisites, quickstart for the owner). `AGENTS.md` is agent-facing (bootstrap protocol). | Standard convention. |
| D11 | Verification strategy is **tests-after** — validation via `bash -n`, `docker compose config`, and one non-interactive end-to-end bootstrap dry-run on a temp copy. | Docs + shell + YAML deliverable, not application code. Every change is validated by a concrete command with an evidence path. |
| D12 | Generated compose stack after bootstrap: `${__project_prefix__}-${__PROJECT_PREFIX___STACK_SLUG}` (mirrors WASI's `wasi-${WASI_STACK_SLUG}`). | Familiar shape, no invention. |
| D13 | Bootstrap **also** creates `docker/opencode/config/.gitkeep` (fixes the missing-mount-source bug without dropping the compose mount). | Keeps the mount intent — per-project opencode config can live there — while making it work out of the box. |
| D14 | `docker/.env.example` is committed; actual `docker/.env` is gitignored (bootstrap generates it). Compose gets `${PROJECT_NAME:-ai-template}` fallback so `compose config` renders without `.env`. | Standard convention. |
| D15 | Bootstrap is idempotency-gated by `TEMPLATE_UNINITIALIZED` — agent aborts with a clear message if marker is absent. | Prevents re-runs from clobbering owner's edits. |
| D16 | Bootstrap interview asks: "target directory decision" — (a) clone into current directory (only if empty or intentional), (b) clone into `./<slug>/` (recommended default), (c) absolute path. Agent detects and warns if target is non-empty. | Owner controls filesystem layout; agent doesn't guess. |
| D17 | Bootstrap interview asks: "initialize as fresh git repo? (Y/n, default Y)". If Y: agent removes template's `.git/` and runs `git init`. | Owners almost never want to inherit a template's git log. |
| D18 | Bootstrap interview asks: "commit after bootstrap? (Y/n, default Y)" with message `Bootstrap from mehr-it/ai-template@<sha>` — records the template SHA the owner bootstrapped from. | Traceability of which template version produced the project. |
| D19 | Bootstrap interview asks: "keep `bootstrap/` directory as reference? (Y/n, default Y)". Keeping it lets the owner add more services later using the same snippet library. | Reversible; owner can `rm -rf bootstrap/` any time. |
| D20 | Bootstrap agent's workflow **must** be reproducible non-interactively — every interview question has a "test defaults" mode using env vars or a fixture file (e.g. `BOOTSTRAP_ANSWERS_FILE=/tmp/answers.env`). This is what the final-verification dry-run uses. | Enables the automated end-to-end dry-run in the plan's final verification wave without a human loop. |

## Scope IN

**C1 — `docker/` fixes and defaults:**
- Rename `docker/entyrpoint.sh` → `docker/entrypoint.sh`.
- Create `docker/opencode/config/.gitkeep` so the compose mount source exists.
- Delete the unused `op` user block from `docker/Dockerfile` (lines 13-15).
- Create `docker/.env.example` with `PROJECT_NAME=__PROJECT_NAME__` (bootstrap-rewritten), `UID=1000`, `GID=1000` documented.
- Update `docker/docker-compose.yml` to give `PROJECT_NAME` a fallback (`${PROJECT_NAME:-ai-template}`) so `compose config` works even without `.env`.
- Optionally add `env_file: .env` to compose so the `.env` is loaded explicitly.
- Sysbox prerequisite is documented in root `README.md` (with install pointer to https://github.com/nestybox/sysbox).

**C2 — `docker_inner/` generic template:**
- Copy every file from `example/docker_inner/` to `docker_inner/`.
- Rewrite all `WASI_*` env references to `__PROJECT_PREFIX___*` (double-underscore case-preserving sed).
- Rewrite all `wasi_*` shell function references to `__project_prefix___*`.
- Rewrite `wasi-${WASI_STACK_SLUG}` compose project name to `__project_prefix__-${__PROJECT_PREFIX___STACK_SLUG}`.
- Replace `WASI_MAIN_CHECKOUT="${WASI_MAIN_CHECKOUT:-/home/ubuntu/workspace}"` in `lib/slug.sh` with placeholder equivalent (keep `/home/ubuntu/workspace` default — matches outer container).
- Empty the compose `include:` block; add a header comment showing the 3-step "add a service" recipe (import from `example/docker_inner/AGENTS.md:103-113`).
- Rewrite `docker_inner/AGENTS.md` — strip all signal-cli / WhatsApp specifics, replace with generic per-worktree stack docs. Keep: rationale (why per-worktree exists), main-vs-worktree table, generated `.env.testing` warning, stack identity + hash8, add-a-service recipe, concurrency notes, lifecycle scripts table, troubleshooting matrix (generalized).
- Delete `signal-cli.yml` and `postgres.yml` from `docker_inner/` (they belong in `bootstrap/services/` — see C5).
- Rewrite `.env.testing.template` to a bare-bones commented header showing the placeholder pattern (with a comment-only example line, no real services wired in the empty template).
- Keep `.gitignore` (`/lock/`).

**C3 — Root entry point for any visiting agent:**
- Create root `AGENTS.md` — "When to read this" preamble matching the format used elsewhere in the repo. Body: (a) one-paragraph identification ("This is `ai-template`, an AI-driven Go project starter…"), (b) state detection block ("If `TEMPLATE_UNINITIALIZED` exists at repo root, the template has NOT been bootstrapped yet — see `bootstrap/AGENTS.md` for the interview + rewrite protocol"), (c) hard requirement: bootstrap runs on the owner's host (not inside a container), the container only comes up after bootstrap finishes, (d) a link to `README.md` for humans. Kept short; the actual protocol lives in `bootstrap/AGENTS.md`.
- Create root `README.md` — human-facing intro: what this repo is, prerequisites (Linux host with docker + sysbox installed; opencode/claude/cursor on the host; `git`/`gh` for the agent to fetch the repo), quickstart (`"tell your agent: use github.com/mehr-it/ai-template to start a new Go AI project into <target>"`), sysbox install pointer, post-bootstrap dev flow overview (`cd <target> && cd docker && docker compose up -d && docker exec …`), pointer to `AGENTS.md` for agents.
- Create `TEMPLATE_UNINITIALIZED` marker file at root — empty file with one comment line: `# Bootstrap has not been run yet. See AGENTS.md.` (comment kept because some FS tools ignore truly empty files).

**C4 — `bootstrap/` protocol and post-bootstrap replacement:**
- Create `bootstrap/AGENTS.md` — the authoritative agent-executable bootstrap protocol. Sections: (0) pre-flight (verify `TEMPLATE_UNINITIALIZED` present; abort with clear message if absent — idempotency guard), (1) target-directory interview (cwd / `./<slug>/` / absolute path; detect and refuse non-empty target unless owner confirms), (2) project identity interview (name, uppercase prefix, lowercase prefix, Go module path — with auto-derivation from name and confirm/override), (3) service selection interview (list snippets from `bootstrap/services/`, owner picks 0..N), (4) Go skeleton interview (Y/N; if Y, ask binary name), (5) fresh-git interview (Y/n default Y), (6) commit interview (Y/n default Y), (7) keep-bootstrap-dir interview (Y/n default Y), (8) sed-rewrite protocol (exact file list, exact placeholders, atomic per-file), (9) service wiring (copy `bootstrap/services/<svc>.yml` → `docker_inner/<svc>.yml`, append to `include:`, add `_get_port` stanza to `up.sh`, add env line to `.env.testing.template`, add row to `status.sh`), (10) optional Go skeleton scaffold (copy + rewrite + `go mod init`), (11) replace root `AGENTS.md` from `bootstrap/AGENTS.md.tpl`, (12) delete `TEMPLATE_UNINITIALIZED`, (13) optionally delete `bootstrap/`, (14) optionally `rm -rf .git && git init && git add . && git commit`, (15) post-bootstrap validation (`docker compose config` on both, `bash -n` on scripts), (16) success summary printed to owner. **Also documents a "non-interactive mode"**: if `BOOTSTRAP_ANSWERS_FILE=<path>` env var is set, agent reads answers from that file instead of asking — used by the plan's final verification dry-run.
- Create `bootstrap/AGENTS.md.tpl` — the post-bootstrap replacement for root `AGENTS.md`. Contains `__PROJECT_NAME__` placeholders; describes the concrete project (name, module path, dev flow: cd into `docker/`, `docker compose up -d`, `docker exec`, worktree stack via `make dev-up`). Bootstrap moves this file to `AGENTS.md` at the end of the flow with all placeholders rewritten.
- Create `bootstrap/README.md` — one-paragraph explainer: "This directory drives the one-time initialization of the template. Agents follow `AGENTS.md` here. Humans do not run anything from this directory directly; the owner just tells their agent to use the parent repo URL."

**C5 — `bootstrap/services/` snippet library + optional Go skeleton:**
- Create `bootstrap/services/postgres.yml` — copied from `example/docker_inner/postgres.yml`, generalized (drop WASI-specific `POSTGRES_USER=wasi`, `POSTGRES_DB=wasi_test` etc., use `__project_prefix__` for user/db name to match). Contains a top-of-file comment: `# This snippet is copied into docker_inner/ during bootstrap when the owner picks postgres. Placeholders below are sed-rewritten.`
- Create `bootstrap/services/postgres.env.snippet` — the `.env.testing` fragment for postgres (`__PROJECT_PREFIX___POSTGRES_DSN=postgres://__project_prefix__:__project_prefix__@127.0.0.1:__POSTGRES_PORT__/__project_prefix___test?sslmode=disable`) — appended to the project's `.env.testing.template` when postgres is selected.
- Create `bootstrap/services/postgres.up-snippet.sh` — the shell fragment for `up.sh` port-discovery block (`POSTGRES_PORT="$(_get_port postgres 5432)"` + the matching `-e "s/__POSTGRES_PORT__/${POSTGRES_PORT}/g"` sed stanza). Bootstrap agent splices this into `up.sh` at a marker line.
- Create `bootstrap/services/README.md` — explains: (a) the 3-step "add a service" recipe (from the WASI AGENTS.md, generalized), (b) the snippet-set convention (`<svc>.yml`, `<svc>.env.snippet`, `<svc>.up-snippet.sh`), (c) the current snippet catalog (just `postgres` initially), (d) how a future contributor adds a new service snippet.
- Create `bootstrap/go-skeleton/go.mod.tpl` — `module __PROJECT_MODULE__` + a `go 1.26` line.
- Create `bootstrap/go-skeleton/cmd/__PROJECT_SLUG__/main.go.tpl` — minimal `package main; func main() { fmt.Println("hello from __PROJECT_NAME__") }`.
- Create `bootstrap/go-skeleton/Makefile.tpl` — targets: `build` (`go build ./cmd/...`), `test` (`go test -race ./...`), `dev-up` (`docker_inner/up.sh`), `dev-down` (`docker_inner/down.sh`), `dev-reset`, `dev-status`, `dev-prune`. Reject `dev-up` from main checkout (mirrors example's exit-64 behavior).
- Create `bootstrap/go-skeleton/README.md` — one line: what these files scaffold.

**C6 — Cleanup and root housekeeping:**
- Delete `example/` directory entirely.
- Create root `.gitignore` — `.env`, `.env.testing`, `.env.local.testing`, `.env.local`, `docker/.env`, `.worktrees/`, `*.db`, plus a commented section for common Go build outputs (`/bin/`, `/dist/`, `*.test`, `*.out`, `coverage.*`).

**C7 — Verification harness (part of the plan's Final verification wave, not a shipped artifact):**
- `bash -n` on every shell script under `docker/`, `docker_inner/`, `bootstrap/**`.
- `docker compose -f docker/docker-compose.yml config` (both with an empty env and with `.env.example` values) — must render without errors.
- End-to-end bootstrap dry-run: copy the whole repo to `/tmp/ai-template-e2e-<timestamp>/`, invoke the bootstrap protocol in **non-interactive mode** via `BOOTSTRAP_ANSWERS_FILE=/tmp/answers.env` with fixed test inputs (`PROJECT_NAME=TestProj`, `PROJECT_PREFIX=TESTPROJ`, `project_prefix=testproj`, `PROJECT_MODULE=example.com/testproj`, `SERVICES=postgres`, `GO_SKELETON=yes`, `BINARY=testproj`, `FRESH_GIT=no` (keep git for the dry-run), `COMMIT=no`, `KEEP_BOOTSTRAP=yes`, `TARGET_DIR=.`). Then run `docker compose -f docker/docker-compose.yml config` and `docker compose -f docker_inner/docker-compose.yml config` in a fake worktree — must render without errors. Verify: zero `__PROJECT_*__` / `__project_prefix__` / `__PROJECT_MODULE__` placeholders remain anywhere outside `bootstrap/` (which is kept), `TEMPLATE_UNINITIALIZED` gone, `docker_inner/postgres.yml` exists, `.env.testing.template` contains the postgres DSN line, `up.sh` contains the postgres port-discovery stanza, `go.mod` exists at target root with the expected module path.
- Grep sweep: no `WASI_` / `wasi_` / `wasi-bridge` / `signal-cli` / `whatsmeow` string survives outside `.git/` and outside the plan's own `.omo/` artifacts.
- Cross-agent smoke sketch (manual, documented but not automated): the plan records the exact prompt an owner would give to opencode/claude-code/cursor to trigger bootstrap ("use github.com/mehr-it/ai-template to start a new Go AI project called foo into ./foo/"), so post-merge someone can run it against a live agent as a smoke check. Not gate-blocking.

## Scope OUT (Must NOT have)

- **No opencode plugin, no npm package, no `SKILL.md`** — Option 1 explicitly forbids distribution-layer artifacts. If the owner later wants automatic trigger recognition, a follow-up plan can wrap this repo in a plugin *without* changing anything shipped here. This plan is docs-in-repo only.
- **No changes to `opencode.jsonc`** — the bootstrap agent runs on the owner's host (not inside the container), where `opencode.jsonc` sandbox rules don't gate a fresh clone. Existing allowlist happens to cover the inside-container dev flow already.
- **No auto-trigger phrases in the repo** — the owner names the repo URL explicitly. The repo does not attempt to squat generic phrases like "new Go project" (that would require a skill/plugin, which is out of scope).
- **No application code** — this is a template. Zero Go source beyond the optional `bootstrap/go-skeleton/main.go.tpl` stub (which is itself opt-in in the interview).
- **No opinions on frameworks** — no gin, echo, cobra, zap, sqlc, gorm, etc. pre-chosen. Agent scaffolds a bare `package main`.
- **No pre-baked services in `docker_inner/`** — no postgres, no redis, no anything. Fresh `docker_inner/` has an empty `include:` block.
- **No changes to `docker/Dockerfile` toolchain** beyond removing the dead `op` user and matching the entrypoint rename. Go 1.26.2, Node 26, opencode, claude, docker, codegraph versions all unchanged.
- **No CI/CD** — no `.github/workflows/`, no `.gitlab-ci.yml`, no automated test harness beyond the one-shot end-to-end validation the plan itself runs.
- **No release engineering** — no tag, no changelog, no version bump. The repo is consumed directly from `main` (or a branch the owner names).
- **No git operations by the plan** — the plan does not `git init`, `git add`, or `git commit`. The bootstrap agent may commit once at the end of *runtime* interactive bootstrap (owner-approved), but that's the runtime agent's decision, not something this plan performs.
- **No changes to `.codegraph/` or `.idea/`**.
- **No renaming of `PROJECT_NAME`** — the `docker/` compose already uses that name; keep it.
- **No unit-test framework for the template infrastructure itself** — validation is via `bash -n` + `docker compose config` + end-to-end dry-run only.
- **No Windows / macOS-specific bootstrap paths** — the outer container is Linux (Ubuntu 24.04), sysbox is Linux-only; owner runs bootstrap on a Linux host with docker installed. macOS via Docker Desktop is a note in README, not a supported first-class path.
- **No renaming of `docker/` or `docker_inner/` directory names** — user's structure decision.
- **No handling of the outer container's own opencode config bootstrap** — that config already exists under `~/.config/opencode` on the host and is mounted in via compose.
- **No auto-detection of "what services does the code need"** — bootstrap is a human-in-the-loop interview.
- **No conditional-single-file for root `AGENTS.md`** — pre- and post-bootstrap versions are physically separate files (`AGENTS.md` at root pre-bootstrap; replaced from `bootstrap/AGENTS.md.tpl` post-bootstrap). Keeps each file simple.
- **No self-updating for owners who bootstrapped from an older SHA** — the commit records `Bootstrap from mehr-it/ai-template@<sha>` for traceability, but there is no `re-bootstrap` command. Owners who want template updates cherry-pick manually. This is a future feature, not this plan.

## Open questions

None — all owner-decisions resolved by the interview answers.

## Approval gate
status: awaiting-approval
pending-action: write `.omo/plans/ai-template-init.md`
approach summary: see the `approach:` field in the front matter above.

<!-- On resume: read this file, note status: awaiting-approval, present the brief to the user, and WAIT for explicit okay. Do NOT re-explore. Do NOT rewrite decisions. -->
