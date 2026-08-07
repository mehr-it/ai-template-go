# bootstrap/AGENTS.md — Bootstrap Protocol

## When to read this

You're an AI agent executing the one-time bootstrap that turns this template into a real
project. Read this file in full before touching anything. The steps are ordered; skipping
or reordering them breaks the result.

Bootstrap runs on the **owner's host**, not inside any container. The outer Docker
container only comes up after bootstrap completes.

---

## Modes

### Interactive (default)

Ask each question in order. Wait for the owner's answer before proceeding. Never batch
questions. Confirm auto-derived values before accepting them.

### Non-interactive

Set `BOOTSTRAP_ANSWERS_FILE=<path>` to a file containing `KEY=VALUE` pairs (one per
line, shell-style, no export keyword). The agent reads each key instead of asking.

Required keys for non-interactive mode:

| Key | Description |
|---|---|
| `TARGET_DIR` | Absolute or relative path for the bootstrapped project |
| `PROJECT_NAME` | Human-readable project name (e.g. "Acme Billing") |
| `PROJECT_PREFIX` | UPPERCASE alphanumeric prefix (e.g. "ACME") |
| `project_prefix` | lowercase alphanumeric prefix (e.g. "acme") |
| `PROJECT_MODULE` | Go module path (e.g. "github.com/acme/billing") |
| `SERVICES` | Comma-separated service names, or empty string for none |
| `GO_SKELETON` | `yes` or `no` |
| `BINARY` | Binary name (default: same as `project_prefix`) |
| `FRESH_GIT` | `yes` or `no` |
| `COMMIT` | `yes` or `no` |
| `KEEP_BOOTSTRAP` | `yes` or `no` |
| `BOOTSTRAP_TEMPLATE_SHA` | Git SHA of the template at bootstrap time (captured in step 0) |

---

## Protocol

### 0. Preflight

Assert the sentinel file exists:

```bash
test -f TEMPLATE_UNINITIALIZED || { echo "Bootstrap already completed — aborting."; exit 1; }
```

Capture the template SHA **before** any `.git/` reset. This SHA goes into the commit
message so the bootstrapped repo records which template version it came from:

```bash
BOOTSTRAP_TEMPLATE_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
```

Check required tools on PATH:

```bash
command -v git  >/dev/null || { echo "git not found"; exit 1; }
command -v sed  >/dev/null || { echo "sed not found"; exit 1; }
command -v bash >/dev/null || { echo "bash not found"; exit 1; }
```

If `GO_SKELETON=yes` (determined in step 4), also check:

```bash
command -v go >/dev/null || { echo "go not found — required for GO_SKELETON=yes"; exit 1; }
```

---

### 1. Target-directory interview

Ask the owner where the bootstrapped project should live. Present three options:

- **(a) Current directory** — bootstrap in place (`.`)
- **(b) Sibling directory** — `../PROJECT_NAME` (auto-suggested once name is known)
- **(c) Custom path** — owner types an absolute or relative path

Rules:
- If the target directory is non-empty and not the current repo, ask for explicit
  confirmation before proceeding.
- If the target is a different directory, copy the repo there first, then continue all
  remaining steps inside the copy.
- Never delete or overwrite files the owner didn't put there.

Set `TARGET_DIR` to the resolved absolute path.

---

### 2. Project identity interview

Collect four values. For each auto-derived value, show the derivation and ask the owner
to confirm or override before moving on.

**PROJECT_NAME** — human-readable name, spaces allowed (e.g. "Acme Billing").

**PROJECT_PREFIX** — UPPERCASE alphanumeric, no spaces or punctuation. Auto-derive from
`PROJECT_NAME` by uppercasing and stripping non-alnum characters. Example: "Acme
Billing" → `ACMEBILLING`. Owner may shorten it.

**project_prefix** — same as `PROJECT_PREFIX` but lowercased. Auto-derive; owner may
override independently.

**PROJECT_MODULE** — Go module path (e.g. `github.com/acme/billing`). No auto-derive;
ask directly.

Store all four. They drive every `sed -i` substitution in step 8.

---

### 3. Service selection

List available services:

```bash
ls bootstrap/services/*.yml 2>/dev/null | grep -v README | sed 's|bootstrap/services/||; s|\.yml||'
```

Show the list to the owner. They pick zero or more by name, comma-separated. Store the
result as `SERVICES` (empty string = no services).

---

### 4. Go skeleton

Ask: "Include Go skeleton? [Y/n]" (default Y).

If yes, ask: "Binary name? [${project_prefix}]" (default = `project_prefix`). Store as
`BINARY`.

If no, set `GO_SKELETON=no` and `BINARY=""`.

---

### 5. Fresh git

Ask: "Reset git history? [Y/n]" (default Y).

If yes, set `FRESH_GIT=yes`. The template's commit history will be discarded in step 14.

---

### 6. Commit on completion

Ask: "Commit bootstrapped result? [Y/n]" (default Y).

Set `COMMIT=yes` or `COMMIT=no`.

---

### 7. Keep bootstrap dir

Ask: "Keep bootstrap/ directory for reference? [Y/n]" (default Y).

Set `KEEP_BOOTSTRAP=yes` or `KEEP_BOOTSTRAP=no`.

---

### 8. Sed rewrite protocol

Run `sed -i` on every file under `TARGET_DIR` **except** files under `bootstrap/`,
`.git/`, `.omo/`, and `example/`. Process substitutions in this exact order — order
matters because some placeholders are substrings of others:

```bash
find "${TARGET_DIR}" \
  -not \( -path '*/bootstrap/*' -o -path '*/.git/*' -o -path '*/.omo/*' -o -path '*/example/*' \) \
  -type f \
  | while read -r file; do
      sed -i \
        "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g; \
         s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g; \
         s|__project_prefix__|${project_prefix}|g; \
         s|__PROJECT_SLUG__|${BINARY}|g; \
         s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
        "$file"
    done
```

**Substitution order rationale:**

1. `__PROJECT_MODULE__` first — it contains `/` characters; the `|` delimiter keeps sed
   safe.
2. `__PROJECT_PREFIX__` (UPPERCASE) before `__project_prefix__` (lowercase) — the
   uppercase form must not accidentally match the lowercase pattern.
3. `__PROJECT_SLUG__` before `__PROJECT_NAME__` — slug is the binary name, name is the
   human label; they may share a prefix.
4. `__PROJECT_NAME__` last.

**Triple-underscore convention:** Template files use forms like
`__PROJECT_PREFIX___STACK_SLUG` (three underscores). The substitution
`s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g` correctly reduces this to
`${PROJECT_PREFIX}_STACK_SLUG` (single underscore between prefix and suffix). Verify
post-rewrite:

```bash
grep -q "${PROJECT_PREFIX}_STACK_SLUG" dev-container-inner/lib/slug.sh \
  || echo "WARNING: slug.sh may not have been rewritten correctly"
```

**Directory renames** — do these AFTER all file-content rewrites:

```bash
if [[ "${GO_SKELETON}" == "yes" && -d "bootstrap/go-skeleton/cmd/__PROJECT_SLUG__" ]]; then
  mv "bootstrap/go-skeleton/cmd/__PROJECT_SLUG__" "bootstrap/go-skeleton/cmd/${BINARY}"
fi
```

**Initialize `dev-container/.env`** — the sed sweep above rewrote
`dev-container/.env.example`'s `__project_prefix__` placeholder to the resolved
slug. Materialize it as the actual env file that `docker compose` reads:

```bash
cp dev-container/.env.example dev-container/.env
```

Rationale: `dev-container/docker-compose.yml` declares
`container_name: ${PROJECT_NAME:-ai-template-go}-dev`. Without a
`dev-container/.env`, every bootstrapped project falls back to the literal
default `ai-template-go-dev`, so two clones of the template collide globally
on the Docker daemon with `Error response from daemon: Conflict. The
container name "/ai-template-go-dev" is already in use`. Writing the
project-specific slug into `.env` eliminates the collision by default.

`dev-container/.env` is already listed in the root `.gitignore`, so this file
is created locally and never committed. Verify the resolved value (this check
reads `.env` directly and does not require Docker to be installed):

```bash
if [[ ! -f dev-container/.env ]]; then
  echo "FAIL: dev-container/.env was not created"
elif grep -q '^PROJECT_NAME=__project_prefix__$' dev-container/.env; then
  echo "FAIL: dev-container/.env still contains __project_prefix__ placeholder"
elif grep -q "^PROJECT_NAME=${project_prefix}\$" dev-container/.env; then
  echo "OK: dev-container/.env → PROJECT_NAME=${project_prefix} (container_name will be ${project_prefix}-dev)"
else
  echo "FAIL: dev-container/.env PROJECT_NAME does not equal '${project_prefix}':"
  grep '^PROJECT_NAME=' dev-container/.env || echo "  (no PROJECT_NAME line found)"
fi
```

If the check reports FAIL, either `.env.example` still contains the
`__project_prefix__` placeholder (step 8's sed sweep did not process it — verify
the `find` filters) or the `cp` above did not run.

---

### 9. Wire selected services

For each service name in `SERVICES` (skip this step entirely if `SERVICES` is empty):

**(a) Copy service compose file and rewrite it:**

```bash
cp "bootstrap/services/${svc}.yml" "dev-container-inner/${svc}.yml"
sed -i \
  "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g; \
   s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g; \
   s|__project_prefix__|${project_prefix}|g; \
   s|__PROJECT_SLUG__|${BINARY}|g; \
   s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
  "dev-container-inner/${svc}.yml"
```

**(b) Add compose include** — change `include: []` in `dev-container-inner/docker-compose.yml`
to include the new file. The marker comment is `# BOOTSTRAP_SERVICE_INCLUDES`:

```bash
sed -i "s|include: \[\]|include:\n  - ${svc}.yml|" dev-container-inner/docker-compose.yml
```

For multiple services, append additional `  - <svc>.yml` lines rather than replacing the
block again.

**(c) Splice port-discovery** — insert the content of
`bootstrap/services/${svc}.up-snippet.sh` immediately after the
`# BOOTSTRAP_SERVICE_PORTS` marker in `dev-container-inner/up.sh`:

```bash
sed -i "/# BOOTSTRAP_SERVICE_PORTS/r bootstrap/services/${svc}.up-snippet.sh" dev-container-inner/up.sh
```

**(d) Splice env line** — append the content of `bootstrap/services/${svc}.env.snippet`
after the `# BOOTSTRAP_ENV_LINES` marker in `dev-container-inner/.env.testing.template`:

```bash
sed -i "/# BOOTSTRAP_ENV_LINES/r bootstrap/services/${svc}.env.snippet" dev-container-inner/.env.testing.template
```

**(e) Auto-generate summary line** — insert a summary echo after the
`# BOOTSTRAP_SUMMARY_LINES` marker in `dev-container-inner/up.sh`. Use the uppercase service
name for the port variable:

```bash
SVC_UPPER="$(echo "${svc}" | tr '[:lower:]' '[:upper:]')"
sed -i "/# BOOTSTRAP_SUMMARY_LINES/a\\  echo \"[dev-container-inner] ${svc}  127.0.0.1:\${${SVC_UPPER}_PORT}\"" \
  dev-container-inner/up.sh
```

**(f) Auto-generate status row** — insert a port lookup and printf pair after the
`# BOOTSTRAP_STATUS_ROWS` marker in `dev-container-inner/status.sh`:

```bash
SVC_UPPER="$(echo "${svc}" | tr '[:lower:]' '[:upper:]')"
sed -i "/# BOOTSTRAP_STATUS_ROWS/a\\
${SVC_UPPER}_PORT=\"\$(docker compose -p \"__project_prefix__-\${__PROJECT_PREFIX___STACK_SLUG}\" -f dev-container-inner/docker-compose.yml port ${svc} 5432 2>/dev/null | cut -d: -f2)\"\\
printf \"%-20s %s\\\\n\" \"${svc}\" \"127.0.0.1:\${${SVC_UPPER}_PORT}\"" \
  dev-container-inner/status.sh
```

**Marker summary** (three distinct names across three files):

| Marker | File | Purpose |
|---|---|---|
| `BOOTSTRAP_SERVICE_INCLUDES` | `dev-container-inner/docker-compose.yml` | compose include list |
| `BOOTSTRAP_SERVICE_PORTS` | `dev-container-inner/up.sh` | port-discovery stanzas |
| `BOOTSTRAP_SUMMARY_LINES` | `dev-container-inner/up.sh` | human-readable summary echoes |
| `BOOTSTRAP_ENV_LINES` | `dev-container-inner/.env.testing.template` | env var placeholders |
| `BOOTSTRAP_STATUS_ROWS` | `dev-container-inner/status.sh` | port table rows |

---

### 10. Go skeleton (if selected)

Skip this step if `GO_SKELETON=no`.

```bash
# go.mod
cp bootstrap/go-skeleton/go.mod.tpl go.mod
sed -i "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g" go.mod

# cmd binary directory
cp -r "bootstrap/go-skeleton/cmd/${BINARY}/" "cmd/${BINARY}/"
mv "cmd/${BINARY}/main.go.tpl" "cmd/${BINARY}/main.go"
sed -i \
  "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g; \
   s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g; \
   s|__project_prefix__|${project_prefix}|g; \
   s|__PROJECT_SLUG__|${BINARY}|g; \
   s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
  "cmd/${BINARY}/main.go"

# Makefile — preserve tab indentation (sed -i is safe here; do not use spaces)
cp bootstrap/go-skeleton/Makefile.tpl Makefile
sed -i \
  "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g; \
   s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g; \
   s|__project_prefix__|${project_prefix}|g; \
   s|__PROJECT_SLUG__|${BINARY}|g; \
   s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
  Makefile

# Tidy (best-effort — may fail if module proxy is unreachable)
go mod tidy 2>/dev/null || echo "WARNING: go mod tidy failed — run manually after bootstrap"
```

---

### 11. Replace root AGENTS.md

The root `AGENTS.md` currently contains the state-detection logic for unbootstrapped
repos. Replace it with the project-specific template:

```bash
cp bootstrap/AGENTS.md.tpl AGENTS.md
sed -i \
  "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g; \
   s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g; \
   s|__project_prefix__|${project_prefix}|g; \
   s|__PROJECT_SLUG__|${BINARY}|g; \
   s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
  AGENTS.md
```

---

### 12. Delete TEMPLATE_UNINITIALIZED

Remove the sentinel file. This is the point of no return — after this, the root
`AGENTS.md` state-detection logic will no longer treat the repo as unbootstrapped:

```bash
rm TEMPLATE_UNINITIALIZED
```

---

### 13. Optionally delete bootstrap/

If `KEEP_BOOTSTRAP=no`:

```bash
rm -rf bootstrap/
```

If `KEEP_BOOTSTRAP=yes` (default), leave `bootstrap/` in place. Owners often keep it as
a reference for adding services later.

---

### 14. Optionally reset git and commit

If `FRESH_GIT=yes`:

```bash
rm -rf .git
git init
```

If `COMMIT=yes` (regardless of whether git was reset):

```bash
git add .
git commit -m "Bootstrap from mehr-it/ai-template-go@${BOOTSTRAP_TEMPLATE_SHA}"
```

The `BOOTSTRAP_TEMPLATE_SHA` captured in step 0 records which template version was used.

---

### 15. Post-bootstrap validation

Run these checks. None require Docker to be running — `compose config` is a pure render.

**Outer compose config:**

```bash
docker compose -f dev-container/docker-compose.yml config >/dev/null \
  && echo "OK: dev-container/docker-compose.yml" \
  || echo "FAIL: dev-container/docker-compose.yml"
```

**Outer container `.env` sanity** — verifies step 8's `.env` init ran. Without
this file, `container_name` silently falls back to `ai-template-go-dev` and
collides with other clones on the same Docker daemon. This check reads `.env`
directly and does not require Docker to be installed:

```bash
if [[ ! -f dev-container/.env ]]; then
  echo "FAIL: dev-container/.env missing — re-run step 8 'Initialize dev-container/.env'"
elif grep -q '^PROJECT_NAME=__project_prefix__$' dev-container/.env; then
  echo "FAIL: dev-container/.env still contains __project_prefix__ placeholder — step 8 sed did not process .env.example"
elif grep -q "^PROJECT_NAME=${project_prefix}\$" dev-container/.env; then
  echo "OK: dev-container/.env → PROJECT_NAME=${project_prefix}"
else
  echo "FAIL: dev-container/.env PROJECT_NAME does not equal '${project_prefix}':"
  grep '^PROJECT_NAME=' dev-container/.env || echo "  (no PROJECT_NAME line found)"
fi
```

**Inner compose config** (requires `PROJECT_PREFIX` exported so the variable reference
resolves):

```bash
export "${PROJECT_PREFIX}_STACK_SLUG=validation-slug"
docker compose -f dev-container-inner/docker-compose.yml config >/dev/null \
  && echo "OK: dev-container-inner/docker-compose.yml" \
  || echo "FAIL: dev-container-inner/docker-compose.yml"
```

**Bash syntax sweep:**

```bash
find . -name '*.sh' \
  -not \( -path '*/.git/*' -o -path '*/bootstrap/*' \) \
  | xargs -I{} bash -n {} \
  && echo "OK: bash -n sweep" \
  || echo "FAIL: bash -n sweep"
```

**Placeholder sweep** — must return empty:

```bash
REMAINING="$(grep -Rn '__PROJECT_' . \
  --exclude-dir=bootstrap \
  --exclude-dir=.git \
  --exclude-dir=.omo \
  2>/dev/null)"
if [[ -z "${REMAINING}" ]]; then
  echo "OK: no __PROJECT_ placeholders remain"
else
  echo "FAIL: placeholders still present:"
  echo "${REMAINING}"
fi
```

If any check fails, report the failure and stop. Do not proceed to step 16.

---

### 16. Success summary

Print a completion block:

```
✓ Bootstrap complete: <PROJECT_NAME> in <TARGET_DIR>

  Module:    <PROJECT_MODULE>
  Prefix:    <PROJECT_PREFIX> / <project_prefix>
  Binary:    <BINARY>
  Services:  <SERVICES or "(none)">
  Go skeleton: <yes/no>
  Git:       <"reset + committed" / "committed" / "no commit">
  Bootstrap dir: <"kept" / "removed">
  Template SHA: <BOOTSTRAP_TEMPLATE_SHA>

Next steps:
  cd <TARGET_DIR>/dev-container
  docker compose up -d
  docker exec -it <project_prefix>-dev bash
  # Inside the container:
  make dev-up
```
