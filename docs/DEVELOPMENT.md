# Development Guide

A complete guide to developing, testing, and running the Habit Tracker application.
This project is **Docker-first** with an optional local (non-Docker) path.

## Table of Contents

1. [Quick Start (Docker)](#quick-start-docker)
2. [Local Development (Optional)](#local-development-optional)
3. [Common Commands](#common-commands)
4. [Testing](#testing)
5. [Database](#database)
6. [Troubleshooting](#troubleshooting)
7. [Related Docs](#related-docs)

## Quick Start (Docker)

No local Elixir/Node.js installation required.

```bash
# First-time setup (starts services, creates DB, runs migrations, seeds data)
make setup

# Daily use
make up             # Start dev server at http://localhost:4000
make create-admin   # Create admin account (interactive)
```

### Docker Notes

- Development services are defined in `docker/docker-compose.yml`.
- Environment variables are set in the compose file for local dev defaults.
- To customize settings, edit the compose file or create a `docker/docker-compose.override.yml`.

## Local Development (Optional)

If you prefer local development, you need **Elixir 1.19+**, **PostgreSQL 15+**, and the mix tooling for Tailwind/esbuild.

```bash
mix setup            # deps + DB setup + assets
mix phx.server       # Start dev server
mix test             # Run tests
```

You can copy `.env.dev` to `.env` for local environment configuration.

## Common Commands

```bash
make help            # See all available commands
make logs            # View logs
make shell           # Open bash shell in web container
make iex             # Open Elixir console
make precommit       # Compile, format, test
```

## Testing

```bash
make test            # Run all tests (Docker)
mix test             # Run tests locally
```

### Test Structure

- **Unit tests**: Test individual functions and modules
- **Integration tests**: Test context interactions
- **LiveView tests**: Test user interactions

Test helpers are located in `test/support/`.

## Database

**Generate migration:**
```bash
make shell
mix ecto.gen.migration add_some_field
exit
```

**Run migration:**
```bash
make migrate
```

**Rollback migration:**
```bash
make rollback
```

## Troubleshooting

**Port already in use:**
```bash
make down
make up
```

**Database issues:**
```bash
make reset
```

**Container won't start:**
```bash
make logs
```

## Related Docs

- [Deployment](DEPLOYMENT.md)
- [Architecture](ARCHITECTURE.md)
- [Docker README](../docker/README.md)
