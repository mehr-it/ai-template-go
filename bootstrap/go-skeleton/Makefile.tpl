# __PROJECT_NAME__ — Makefile

.PHONY: build test dev-up dev-down dev-reset dev-status dev-prune

build:
	go build -o ./bin/__project_prefix__ ./cmd/...

test:
	go test -race ./...

dev-up:
	@bash docker_inner/up.sh

dev-down:
	@bash docker_inner/down.sh

dev-reset:
	@bash docker_inner/reset.sh

dev-status:
	@bash docker_inner/status.sh

dev-prune:
	@bash docker_inner/prune.sh
