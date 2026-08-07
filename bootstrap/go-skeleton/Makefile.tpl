# __PROJECT_NAME__ — Makefile

.PHONY: build test dev-up dev-down dev-reset dev-status dev-prune

build:
	go build -o ./bin/__project_prefix__ ./cmd/...

test:
	go test -race ./...

dev-up:
	@bash dev-container-inner/up.sh

dev-down:
	@bash dev-container-inner/down.sh

dev-reset:
	@bash dev-container-inner/reset.sh

dev-status:
	@bash dev-container-inner/status.sh

dev-prune:
	@bash dev-container-inner/prune.sh
