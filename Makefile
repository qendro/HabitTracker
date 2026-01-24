.PHONY: help up down restart logs shell iex test migrate rollback reset setup clean build deps precommit create-admin

# Docker Compose command with proper file path
DC = docker compose -f docker/docker-compose.yml

# Default target
help:
	@echo "Habit Tracker - Docker Commands"
	@echo ""
	@echo "Setup & Control:"
	@echo "  make setup      - Initial setup (start services, create DB, run migrations)"
	@echo "  make up         - Start all services"
	@echo "  make down       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make build      - Rebuild containers"
	@echo "  make clean      - Stop services and remove volumes (deletes data!)"
	@echo ""
	@echo "Development:"
	@echo "  make logs       - View logs (follow mode)"
	@echo "  make shell      - Open bash shell in web container"
	@echo "  make iex        - Open IEx shell"
	@echo "  make deps       - Install/update dependencies"
	@echo "  make precommit  - Run precommit checks (compile, format, test)"
	@echo ""
	@echo "Database:"
	@echo "  make migrate    - Run database migrations"
	@echo "  make rollback   - Rollback last migration"
	@echo "  make reset      - Reset database (drop, create, migrate, seed)"
	@echo ""
	@echo "Testing:"
	@echo "  make test       - Run all tests"
	@echo ""
	@echo "Admin:"
	@echo "  make create-admin - Create admin account (interactive)"

# Setup & Control
setup:
	@echo "Starting services..."
	$(DC) up -d
	@echo "Waiting for database..."
	sleep 5
	@echo "Setting up database..."
	$(DC) exec web mix ecto.setup
	@echo "Setup complete! Access app at http://localhost:4000"

up:
	$(DC) up

down:
	$(DC) down

restart:
	$(DC) restart

build:
	$(DC) build

clean:
	@echo "WARNING: This will delete all data!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DC) down -v; \
		echo "Cleaned!"; \
	fi

# Development
logs:
	$(DC) logs -f

shell:
	$(DC) exec web bash

iex:
	$(DC) exec web iex -S mix

deps:
	$(DC) exec web mix deps.get
	$(DC) restart web

precommit:
	$(DC) exec web mix precommit

# Database
migrate:
	$(DC) exec web mix ecto.migrate

rollback:
	$(DC) exec web mix ecto.rollback

reset:
	$(DC) exec web mix ecto.reset

# Testing
test:
	$(DC) run --rm test

# Admin
create-admin:
	@./scripts/create_admin.sh
