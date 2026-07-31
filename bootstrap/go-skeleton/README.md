# Go Skeleton

Optional Go module skeleton copied into project root during bootstrap when owner selects Go skeleton. Contains template files with placeholders (`__PROJECT_MODULE__`, `__project_prefix__`, `__PROJECT_NAME__`, `__PROJECT_SLUG__`) that are sed-rewritten during bootstrap.

## Files

- `go.mod.tpl` → `go.mod` (project root)
- `cmd/__PROJECT_SLUG__/main.go.tpl` → `cmd/<binary>/main.go`
- `Makefile.tpl` → `Makefile` (project root; targets: build, test, dev-up, dev-down, dev-reset, dev-status, dev-prune)
