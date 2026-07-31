TASK 29: Create bootstrap/go-skeleton/README.md

FILE: bootstrap/go-skeleton/README.md
WORD COUNT: 58 (< 150 ✓)

CONTENT:
# Go Skeleton

Optional Go module skeleton copied into project root during bootstrap when owner selects Go skeleton. Contains template files with placeholders (`__PROJECT_MODULE__`, `__project_prefix__`, `__PROJECT_NAME__`, `__PROJECT_SLUG__`) that are sed-rewritten during bootstrap.

## Files

- `go.mod.tpl` → `go.mod` (project root)
- `cmd/__PROJECT_SLUG__/main.go.tpl` → `cmd/<binary>/main.go`
- `Makefile.tpl` → `Makefile` (project root; targets: build, test, dev-up, dev-down, dev-reset, dev-status, dev-prune)

VERIFICATION:
✓ File exists and is non-empty
✓ Word count: 58 < 150
✓ Contains 'go.mod.tpl'
✓ Contains 'Makefile.tpl'
✓ Contains 'main.go.tpl'
✓ All required template files referenced
