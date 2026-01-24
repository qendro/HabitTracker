# Docker Setup for Habit Tracker

This project uses Docker for both local development and Gigalixir deployment. Everything runs in containers - no local Elixir/Node.js installation required.

## Quick Start

### Local Development

```bash
# Start development server
make up

# Run tests
make test

# Create admin account
make create-admin
```

Visit http://localhost:4000

### Gigalixir Deployment

All Gigalixir operations run inside Docker containers. No need to install Gigalixir CLI on your local machine.

## Setup

### 1. Configure Gigalixir Credentials

The `.env.gigalixir` file contains your Gigalixir credentials:

```bash
GIGALIXIR_EMAIL=habbits.xyz@gmail.com
GIGALIXIR_API_KEY=your-api-key-here
APP_NAME=habit-tracker-prod
```

**Important:** This file is gitignored. Never commit credentials to version control.

### 2. Test Connection

```bash
make gigalixir-setup
```

This will test your Gigalixir credentials inside a Docker container.

## Deployment Workflow

### First Time Setup

```bash
# 1. Create app and database on Gigalixir
make gigalixir-create

# 2. Deploy your code
make gigalixir-deploy

# 3. Run migrations
make gigalixir-migrate

# 4. Create admin account
make gigalixir-admin
```

### Subsequent Deployments

```bash
# Deploy changes
make gigalixir-deploy

# Run migrations (if needed)
make gigalixir-migrate
```

## Available Commands

### Development Commands

- `make setup` - Initial project setup
- `make up` - Start development server
- `make down` - Stop development server
- `make test` - Run tests
- `make shell` - Open bash shell in container
- `make iex` - Open Elixir IEx console
- `make logs` - View logs
- `make migrate` - Run migrations (local)
- `make create-admin` - Create admin account (local)

### Gigalixir Commands

- `make gigalixir-setup` - Test Gigalixir credentials
- `make gigalixir-create` - Create app and database
- `make gigalixir-deploy` - Deploy to Gigalixir
- `make gigalixir-migrate` - Run migrations on Gigalixir
- `make gigalixir-admin` - Create admin account on Gigalixir
- `make gigalixir-logs` - View app logs
- `make gigalixir-status` - Check app status
- `make gigalixir-shell` - Open deployment shell

## Docker Containers

### Development Containers

- **web** - Phoenix application (dev mode)
- **db** - PostgreSQL database
- **test** - Test runner

Defined in: `docker/docker-compose.yml`

### Deployment Container

- **gigalixir** - Gigalixir CLI and deployment tools

Defined in: `docker/docker-compose.gigalixir.yml`

## File Structure

```
docker/
├── Dockerfile              # Production build
├── Dockerfile.dev          # Development build
├── Dockerfile.gigalixir    # Gigalixir deployment tools
├── docker-compose.yml      # Development services
├── docker-compose.gigalixir.yml  # Deployment service
├── scripts/
│   ├── gigalixir-setup.sh  # Setup credentials
│   ├── create-app.sh       # Create Gigalixir app
│   ├── deploy.sh           # Deploy to Gigalixir
│   ├── migrate.sh          # Run migrations
│   ├── create-admin.sh     # Create admin account
│   ├── logs.sh             # View logs
│   └── status.sh           # Check status
└── README.md               # This file
```

## Troubleshooting

### Gigalixir credentials not working

```bash
# Test your credentials
make gigalixir-setup

# Check .env.gigalixir file exists and has correct values
cat .env.gigalixir
```

### App not deploying

```bash
# Check app status
make gigalixir-status

# View logs
make gigalixir-logs

# Try redeploying
make gigalixir-deploy
```

### Database issues

```bash
# Check database status
make gigalixir-status

# Run migrations
make gigalixir-migrate
```

### Need to run custom commands

```bash
# Open deployment shell
make gigalixir-shell

# Then run any Gigalixir command
gigalixir ps -a habit-tracker-prod
gigalixir config -a habit-tracker-prod
```

## Security Notes

1. **Never commit `.env.gigalixir`** - It contains sensitive credentials
2. **Keep API keys secure** - Don't share them in chat, email, or screenshots
3. **Rotate credentials** - If credentials are exposed, regenerate them immediately
4. **Use strong passwords** - For admin accounts and databases

## Multiple Projects

This Docker setup is completely self-contained. Each project has its own:

- Docker containers
- Gigalixir credentials (`.env.gigalixir`)
- Deployment scripts (`docker/scripts/`)

No conflicts between projects. Each project's Gigalixir CLI runs in its own container.

## Getting Help

- Check logs: `make gigalixir-logs`
- Check status: `make gigalixir-status`
- Open shell: `make gigalixir-shell`
- View all commands: `make help`

## Resources

- [Gigalixir Documentation](https://gigalixir.readthedocs.io/)
- [Phoenix Framework](https://www.phoenixframework.org/)
- [Docker Documentation](https://docs.docker.com/)
