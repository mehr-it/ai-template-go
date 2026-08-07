# bootstrap/services/

Snippet library for services that can be added to `dev-container-inner/` during bootstrap or later.

---

## Snippet convention (per service)

Each service ships as a triplet of files. Bootstrap splices them into the inner stack automatically when the owner picks that service. You can also splice them by hand after bootstrap without re-running the full protocol.

| File | Purpose | Splice target |
|------|---------|---------------|
| `<svc>.yml` | Docker Compose service definition | `dev-container-inner/docker-compose.yml` `include:` block (`BOOTSTRAP_SERVICE_INCLUDES`) |
| `<svc>.env.snippet` | `.env.testing` DSN/port fragment | `dev-container-inner/.env.testing.template` at `BOOTSTRAP_ENV_LINES` |
| `<svc>.up-snippet.sh` | Port-discovery + sed stanza | `dev-container-inner/up.sh` at `BOOTSTRAP_SERVICE_PORTS` |

Placeholders used across all three files:

| Placeholder | Meaning |
|-------------|---------|
| `__PROJECT_PREFIX__` | UPPERCASE project prefix (e.g. `ACME`) |
| `__project_prefix__` | lowercase project prefix (e.g. `acme`) |
| `__<SVC>_PORT__` | Dynamic port token replaced by `up.sh` at runtime (e.g. `__POSTGRES_PORT__`) |

Bootstrap's `sed -i` pass rewrites the first two. The third is rewritten at `dev-up` time by the port-discovery stanza in `up.sh`.

---

## Current catalog

| Service | Image | Port | Healthcheck | User/DB |
|---------|-------|------|-------------|---------|
| `postgres` | `postgres:17-alpine` | dynamic `127.0.0.1::5432` | `pg_isready` | `__project_prefix__` |

---

## Add a service (post-bootstrap, without re-running bootstrap)

If bootstrap has already run and you want to wire in a new service by hand, follow these three steps.

### Step 1 — Drop the file triplet

Copy or create `<svc>.yml`, `<svc>.env.snippet`, and `<svc>.up-snippet.sh` into `bootstrap/services/`. Use the `postgres.*` files as a starting point (see [Contribute a new snippet](#contribute-a-new-snippet) below).

Run the placeholder rewrite on the yml file so it matches your project:

```bash
sed -i \
  "s|__PROJECT_MODULE__|${PROJECT_MODULE}|g; \
   s|__PROJECT_PREFIX__|${PROJECT_PREFIX}|g; \
   s|__project_prefix__|${project_prefix}|g; \
   s|__PROJECT_SLUG__|${BINARY}|g; \
   s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
  "bootstrap/services/<svc>.yml"
```

Then copy the rewritten file into `dev-container-inner/`:

```bash
cp "bootstrap/services/<svc>.yml" "dev-container-inner/<svc>.yml"
```

### Step 2 — Splice into dev-container-inner/

Five splice points, one per marker:

**`BOOTSTRAP_SERVICE_INCLUDES`** in `dev-container-inner/docker-compose.yml` — add the include line:

```bash
# If include: [] is still the placeholder form:
sed -i "s|include: \[\]|include:\n  - <svc>.yml|" dev-container-inner/docker-compose.yml
# If other services are already listed, append manually.
```

**`BOOTSTRAP_SERVICE_PORTS`** in `dev-container-inner/up.sh` — insert the port-discovery stanza:

```bash
sed -i "/# BOOTSTRAP_SERVICE_PORTS/r bootstrap/services/<svc>.up-snippet.sh" dev-container-inner/up.sh
```

**`BOOTSTRAP_SUMMARY_LINES`** in `dev-container-inner/up.sh` — add a human-readable summary echo:

```bash
SVC_UPPER="$(echo "<svc>" | tr '[:lower:]' '[:upper:]')"
sed -i "/# BOOTSTRAP_SUMMARY_LINES/a\\  echo \"[dev-container-inner] <svc>  127.0.0.1:\${${SVC_UPPER}_PORT}\"" \
  dev-container-inner/up.sh
```

**`BOOTSTRAP_ENV_LINES`** in `dev-container-inner/.env.testing.template` — append the DSN fragment:

```bash
sed -i "/# BOOTSTRAP_ENV_LINES/r bootstrap/services/<svc>.env.snippet" \
  dev-container-inner/.env.testing.template
```

**`BOOTSTRAP_STATUS_ROWS`** in `dev-container-inner/status.sh` — add a port-lookup and table row:

```bash
SVC_UPPER="$(echo "<svc>" | tr '[:lower:]' '[:upper:]')"
sed -i "/# BOOTSTRAP_STATUS_ROWS/a\\
${SVC_UPPER}_PORT=\"\$(docker compose port <svc> <container_port> 2>/dev/null | cut -d: -f2)\"\\
printf \"%-20s %s\\\\n\" \"<svc>\" \"127.0.0.1:\${${SVC_UPPER}_PORT}\"" \
  dev-container-inner/status.sh
```

### Step 3 — Verify healthy startup

Inside a worktree (or the main checkout), reset and bring up the inner stack:

```bash
make dev-reset
```

Check that the new service appears in the status table and that its port is non-empty. If the healthcheck fails, inspect logs with `docker compose logs <svc>`.

---

## Contribute a new snippet

Copy the `postgres.*` triplet as a starting point:

```bash
cp bootstrap/services/postgres.yml         bootstrap/services/<svc>.yml
cp bootstrap/services/postgres.env.snippet bootstrap/services/<svc>.env.snippet
cp bootstrap/services/postgres.up-snippet.sh bootstrap/services/<svc>.up-snippet.sh
```

Then edit each file:

- **`<svc>.yml`** — replace the image, environment variables, port mapping, and healthcheck. Keep `runtime: runc` (inner containers run plain runc, not sysbox).
- **`<svc>.env.snippet`** — replace the DSN line with whatever env vars the service needs. Use `__<SVC>_PORT__` as the port token (e.g. `__REDIS_PORT__`).
- **`<svc>.up-snippet.sh`** — replace the `_get_port` call with the correct container port and update the `sed` token to match `__<SVC>_PORT__`.

Keep placeholders consistent across all three files:

- `__PROJECT_PREFIX__` and `__project_prefix__` for project identity
- `__<SVC>_PORT__` (uppercase service name) for the dynamic port token

Once the triplet is in place, follow the [Add a service](#add-a-service-post-bootstrap-without-re-running-bootstrap) steps above to wire it in, then open a PR.
