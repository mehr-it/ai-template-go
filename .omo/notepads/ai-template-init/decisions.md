# Decisions — ai-template-init

## [2026-07-31] Session Start
- No opencode plugin, no npm package, no SKILL.md — docs-in-repo distribution only
- Postgres is the sole worked-example service in bootstrap/services/
- Fresh git repo by default when bootstrapping (template's git history discarded)
- bootstrap/ directory kept as reference by default (KEEP_BOOTSTRAP=yes default)
- No CI/CD, no release engineering
- No git operations by the plan itself — plan writes files and runs read-only validation only
- bash -n + docker compose config + grep sweep + e2e dry-run = verification strategy (no unit test framework)
