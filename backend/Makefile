SHELL := /bin/bash

# Load .env if present so DATABASE_URL etc. flow into sub-commands.
ifneq (,$(wildcard .env))
include .env
export
endif

DATABASE_URL ?= postgres://fit:fit@localhost:5432/fit_backend?sslmode=disable

# Integration tests read TEST_DATABASE_URL (NOT DATABASE_URL) so a shell pointing
# at production can never trip the suite into running TRUNCATE. Defaults to the
# docker-compose connection.
TEST_DATABASE_URL ?= postgres://fit:fit@localhost:5432/fit_backend?sslmode=disable

.PHONY: run test build lint vet sqlc seed \
        migrate-up migrate-down migrate-new \
        docker-up docker-down docker-logs

run:
	go run ./cmd/server

build:
	go build -o ./bin/server ./cmd/server
	go build -o ./bin/seed ./cmd/seed

test:
	TEST_DATABASE_URL=$(TEST_DATABASE_URL) go test ./... -count=1

vet:
	go vet ./...

lint: vet
	gofmt -l . | tee /tmp/fit-backend-gofmt.out
	@test ! -s /tmp/fit-backend-gofmt.out

sqlc:
	sqlc generate

seed:
	DATABASE_URL=$(DATABASE_URL) go run ./cmd/seed

migrate-up:
	migrate -database "$(DATABASE_URL)" -path ./migrations up

migrate-down:
	migrate -database "$(DATABASE_URL)" -path ./migrations down 1

# usage: make migrate-new NAME=add_widgets_table
migrate-new:
	@if [ -z "$(NAME)" ]; then echo "NAME is required, e.g. make migrate-new NAME=add_widgets"; exit 1; fi
	migrate create -ext sql -dir ./migrations -seq $(NAME)

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-logs:
	docker compose logs -f postgres
