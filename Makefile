.PHONY: help up down restart logs shell iex test migrate rollback reset setup clean build deps precommit create-admin gigalixir-setup gigalixir-create gigalixir-deploy gigalixir-migrate gigalixir-admin gigalixir-logs gigalixir-status gigalixir-shell

# Docker Compose commands
DC = docker compose -f docker/docker-compose.yml
DC_GIGALIXIR = docker compose -f docker/docker-compose.gigalixir.yml

# Default target
help:
	@echo "=========================================="
	@echo "Habit Tracker - Docker Commands"
	@echo "=========================================="
	@echo ""
	@echo "Development (Local):"
	@echo "  make setup          - Initial setup (start services, create DB, run migrations)"
	@echo "  make up             - Start all services"
	@echo "  make down           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make build          - Rebuild containers"
	@echo "  make clean          - Stop services and remove volumes (deletes data!)"
	@echo "  make logs           - View logs (follow mode)"
	@echo "  make shell          - Open bash shell in web container"
	@echo "  make iex            - Open IEx shell"
	@echo "  make deps           - Install/update dependencies"
	@echo "  make precommit      - Run precommit checks (compile, format, test)"
	@echo "  make test           - Run all tests"
	@echo "  make migrate        - Run database migrations"
	@echo "  make rollback       - Rollback last migration"
	@echo "  make reset          - Reset database (drop, create, migrate, seed)"
	@echo "  make create-admin   - Create admin account (interactive)"
	@echo ""
	@echo "Gigalixir Deployment (Production):"
	@echo "  make gigalixir-setup    - Test Gigalixir credentials"
	@echo "  make gigalixir-create   - Create app and database on Gigalixir"
	@echo "  make gigalixir-deploy   - Deploy to Gigalixir"
	@echo "  make gigalixir-migrate  - Run migrations on Gigalixir"
	@echo "  make gigalixir-admin    - Create admin account on Gigalixir"
	@echo "  make gigalixir-logs     - View Gigalixir app logs"
	@echo "  make gigalixir-status   - Check Gigalixir app status"
	@echo "  make gigalixir-domain   - Setup custom domain"
	@echo "  make gigalixir-domains  - List configured domains"
	@echo "  make gigalixir-restart  - Restart app"
	@echo "  make gigalixir-shell    - Open Gigalixir deployment shell"
	@echo ""
	@echo "Note: Gigalixir commands require .env.gigalixir file with credentials"
	@echo ""

# Development - Setup & Control
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

# Development - Tools
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

# Development - Database
migrate:
	$(DC) exec web mix ecto.migrate

rollback:
	$(DC) exec web mix ecto.rollback

reset:
	$(DC) exec web mix ecto.reset

# Development - Testing
test:
	$(DC) run --rm test

# Development - Admin
create-admin:
	@./scripts/create_admin.sh

# Gigalixir Deployment
gigalixir-setup:
	@echo "Testing Gigalixir connection..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		echo "Copy .env.gigalixir.example and fill in your credentials"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/gigalixir-setup.sh

gigalixir-create:
	@echo "Creating Gigalixir app and database..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/create-app.sh

gigalixir-deploy:
	@echo "Deploying to Gigalixir..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/deploy.sh

gigalixir-migrate:
	@echo "Running migrations on Gigalixir..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/migrate.sh

gigalixir-admin:
	@echo "Creating admin account on Gigalixir..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/create-admin.sh

gigalixir-logs:
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/logs.sh

gigalixir-status:
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/status.sh

gigalixir-shell:
	@echo "Opening Gigalixir deployment shell..."
	@echo "Run deployment scripts from /app/docker/scripts/"
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash

gigalixir-domain:
	@echo "Setting up custom domain..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/setup-domain.sh

gigalixir-domains:
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/list-domains.sh

gigalixir-restart:
	@echo "Restarting app..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $$(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/restart.sh

gigalixir-config:
	@echo "Configuring environment variables..."
	@if [ ! -f .env.gigalixir ]; then \
		echo "Error: .env.gigalixir file not found"; \
		exit 1; \
	fi
	@export $(grep -v '^#' .env.gigalixir | xargs) && $(DC_GIGALIXIR) run --rm gigalixir bash /app/docker/scripts/configure-env.sh
