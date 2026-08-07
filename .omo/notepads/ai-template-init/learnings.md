# Learnings — ai-template-init

## [2026-07-31] Session Start
- Repo currently has: `docker/`, `example/`, `opencode.jsonc` at root
- No `docker_inner/`, `bootstrap/`, `AGENTS.md`, `README.md`, `TEMPLATE_UNINITIALIZED` yet
- `example/docker_inner/` is the source for Wave 2 copy
- Triple-underscore convention: `WASI_STACK_SLUG` → `__PROJECT_PREFIX___STACK_SLUG` (3 underscores = marker `__PROJECT_PREFIX__` + original `_STACK_SLUG`)
- Bootstrap sed order: `__PROJECT_MODULE__` first, then `__PROJECT_PREFIX__` (upper), then `__project_prefix__` (lower), then `__PROJECT_SLUG__`, then `__PROJECT_NAME__`
- `include: []` is valid YAML for empty list in docker-compose v2.20+
- Marker names: `BOOTSTRAP_SERVICE_PORTS` and `BOOTSTRAP_SUMMARY_LINES` in up.sh; `BOOTSTRAP_STATUS_ROWS` in status.sh; `BOOTSTRAP_ENV_LINES` in .env.testing.template; `BOOTSTRAP_SERVICE_INCLUDES` in docker-compose.yml
- Evidence path: `.omo/evidence/task-<N>-<slug>.txt`
- Commits: one per todo where `Commit: Y`; validation-only todos do NOT commit

## [2026-07-31] Task 34 — E2E dry-run gate
- Docker CLI present but `docker compose` plugin not installed on host — used `python3 -c 'import yaml; yaml.safe_load(...)'` fallback for A7/A8 (validates YAML syntax + verifies include list references postgres.yml + verifies postgres service block exists)
- Placeholder-rewrite fallout: `bootstrap/services/postgres.env.snippet` gets copied verbatim into `docker_inner/.env.testing.template` at splice time (Step 9d), and it still contains `__PROJECT_PREFIX__` / `__project_prefix__`. Must re-run the standard 5-substitution sed pass on `.env.testing.template` AFTER the splice, otherwise A2 (placeholder sweep) fails and A4 (`TESTPROJ_POSTGRES_DSN`) also fails
- `find ... -type f ! -path './bootstrap/*'` (relative paths from cwd) is easier than the `-not \( -path '*/bootstrap/*' -o ... \)` form and gives identical results
- Assertion log format: keep `A<N>: PASS` on its own line with strict `^A[0-9]*: PASS$` shape; put qualifiers on separate `  note: ...` lines so gate `grep -c '^A[0-9]*: PASS$' >= 12` counts correctly
- Full E2E completes in a few seconds — Step 8 sed pass rewrote 26 files, all 12 assertions passed
- Evidence: `.omo/evidence/task-34-e2e-dryrun.log` (ends with `E2E: PASS`)
