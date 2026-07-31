Task 17: Create root README.md

File created: README.md at repo root

Verification checks:
- test -s README.md: PASS (file exists and non-empty)
- grep -qi 'sysbox' README.md: PASS (sysbox referenced in intro, prerequisites, macOS note)
- grep -q 'github.com/mehr-it/ai-template' README.md: PASS (in Quickstart section)
- grep -q 'bootstrap' README.md: PASS (bootstrap/ listed in "What this repo gives you" and referenced in Quickstart)
- grep -qi 'macOS' README.md: PASS (dedicated "## macOS note" section)
- grep -q '## Quickstart' README.md: PASS (section heading "## Quickstart (owner)")

Sections included:
1. # ai-template — one-paragraph description
2. ## What this repo gives you — docker/, docker_inner/, bootstrap/ bullets
3. ## Prerequisites (Linux host) — Docker Engine + sysbox, git/gh, AI agent
4. ## Quickstart (owner) — verbatim copyable prompt with backtick formatting
5. ## After bootstrap — docker compose up + docker exec + make dev-up sequence
6. ## macOS note — sysbox Linux-only caveat with workaround options

Quickstart prompt (verbatim):
Use `github.com/mehr-it/ai-template` to start a new Go AI project called `<name>` into `./<name>/`.
