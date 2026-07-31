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
