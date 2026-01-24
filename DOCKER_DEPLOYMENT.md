# Docker-Based Deployment Guide

This project uses **Docker exclusively** for all operations. No local Elixir, Node.js, or Gigalixir CLI installation required.

## Quick Reference

### Local Development

```bash
make up              # Start dev server (http://localhost:4000)
make test            # Run tests
make create-admin    # Create admin account
```

### Deploy to Gigalixir

```bash
# First time only
make gigalixir-create    # Create app & database

# Every deployment
make gigalixir-deploy    # Deploy code
make gigalixir-migrate   # Run migrations
make gigalixir-admin     # Create admin account
```

### Monitor Production

```bash
make gigalixir-status    # Check app status
make gigalixir-logs      # View logs
```

## Setup Instructions

### 1. Verify Credentials

Check that `.env.gigalixir` exists with your credentials:

```bash
cat .env.gigalixir
```

Should contain:
```
GIGALIXIR_EMAIL=habbits.xyz@gmail.com
GIGALIXIR_API_KEY=1250baa7-4cf6-4a8c-9546-ce151a1e061c
APP_NAME=habit-tracker-prod
```

### 2. Test Connection

```bash
make gigalixir-setup
```

You should see your account info.

### 3. Deploy

```bash
# Create app (first time only)
make gigalixir-create

# Deploy
make gigalixir-deploy

# Run migrations
make gigalixir-migrate

# Create admin
make gigalixir-admin
```

## All Commands

Run `make help` to see all available commands.

## How It Works

All Gigalixir operations run inside Docker containers:

1. **Dockerfile.gigalixir** - Contains Gigalixir CLI and tools
2. **docker-compose.gigalixir.yml** - Deployment service definition
3. **docker/scripts/** - Deployment scripts
4. **.env.gigalixir** - Your credentials (gitignored)

Everything is self-contained. No conflicts with other projects.

## Troubleshooting

**Problem:** Credentials not working
```bash
make gigalixir-setup  # Test credentials
```

**Problem:** Deployment failed
```bash
make gigalixir-logs   # Check logs
make gigalixir-status # Check status
```

**Problem:** Need to run custom command
```bash
make gigalixir-shell  # Open deployment shell
```

## Your App

**Production URL:** https://habit-tracker-prod.gigalixirapp.com

**Admin Login:** https://habit-tracker-prod.gigalixirapp.com/admin/login

## More Info

See `docker/README.md` for detailed documentation.
