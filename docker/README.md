# Docker Setup for Habit Tracker

This project is Docker-first. All development and Gigalixir deployment workflows run in containers.

## Quick Start (Development)

```bash
make up
make create-admin
```

Visit http://localhost:4000

## Northflank Deployment

Northflank can build directly from `docker/Dockerfile`.

See `docs/DEPLOYMENT.md` for the full Docker-first deployment flow,
including required environment variables and migrations.

## Gigalixir Deployment

All Gigalixir operations run inside a Docker container. No local Gigalixir CLI required.

### Credentials

Create a local `.env.gigalixir` file from the template:

```bash
cp .env.gigalixir.example .env.gigalixir
```

Fill in:

```bash
GIGALIXIR_EMAIL=your-email@example.com
GIGALIXIR_API_KEY=your-api-key
APP_NAME=your-app-name
```

### Common Deployment Commands

```bash
make gigalixir-setup
make gigalixir-create
make gigalixir-deploy
make gigalixir-migrate
make gigalixir-admin
make gigalixir-configure-env
make gigalixir-check-email
```

For the full workflow and production notes, see `docs/DEPLOYMENT.md`.

## File Structure

```
docker/
├── Dockerfile              # Production build
├── Dockerfile.dev          # Development build
├── Dockerfile.gigalixir    # Gigalixir deployment tools
├── docker-compose.yml      # Development services
├── docker-compose.gigalixir.yml  # Deployment service
├── scripts/                # Gigalixir helper scripts (used inside container)
└── README.md               # This file
```

## Resources

- Gigalixir Docs: https://gigalixir.readthedocs.io/
- Docker Docs: https://docs.docker.com/
