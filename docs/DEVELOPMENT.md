# Development Guide

Complete guide for developing, testing, and deploying the Habit Tracker application using Docker.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Development Workflow](#development-workflow)
3. [Testing](#testing)
4. [Deployment](#deployment)
5. [Troubleshooting](#troubleshooting)

## Quick Start

This project uses **Docker exclusively**. No local Elixir, Node.js, or Gigalixir CLI installation required.

### Start Development

```bash
make up              # Start dev server at http://localhost:4000
make test            # Run tests
make create-admin    # Create admin account
```

### Common Commands

```bash
make help            # See all available commands
make logs            # View logs
make shell           # Open bash shell
make iex             # Open Elixir console
```

## Development Workflow

### Project Structure

```
habit-tracker/
├── docker/                      # Docker configuration
│   ├── Dockerfile              # Production build
│   ├── Dockerfile.dev          # Development build
│   ├── Dockerfile.gigalixir    # Deployment tools
│   ├── docker-compose.yml      # Dev services
│   ├── docker-compose.gigalixir.yml  # Deployment service
│   ├── scripts/                # Deployment scripts
│   └── README.md               # Docker documentation
├── lib/
│   ├── habit_tracker/          # Business logic contexts
│   │   ├── accounts/           # User authentication
│   │   ├── admin/              # Admin functionality
│   │   ├── reminders/          # Email reminders
│   │   ├── tracker/            # Habit tracking
│   │   └── workers/            # Background jobs
│   └── habit_tracker_web/      # Web interface
│       ├── components/         # Reusable UI components
│       ├── controllers/        # HTTP controllers
│       └── live/               # LiveView modules
├── priv/repo/migrations/       # Database migrations
├── test/                       # Test files
├── .env.gigalixir              # Gigalixir credentials (gitignored)
└── Makefile                    # All commands
```

### Making Changes

1. **Start development server:**
   ```bash
   make up
   ```

2. **Make your changes** in `lib/`

3. **Run tests:**
   ```bash
   make test
   ```

4. **Commit:**
   ```bash
   git add .
   git commit -m "Your changes"
   ```

5. **Deploy:**
   ```bash
   make gigalixir-deploy
   ```

### Database Migrations

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

## Testing

### Running Tests

```bash
make test            # Run all tests
```

### Test Structure

- **Unit tests**: Test individual functions and modules
- **Integration tests**: Test context interactions
- **LiveView tests**: Test user interactions

### Test Helpers

Located in `test/support/`:
- `DataCase`: Database test setup
- `ConnCase`: Controller/LiveView test setup
- `Fixtures`: Test data creation

## Deployment

### Docker-Based Deployment

All deployment operations run inside Docker containers. No local Gigalixir CLI needed.

### First Time Setup

```bash
# 1. Verify credentials in .env.gigalixir
cat .env.gigalixir

# 2. Test connection
make gigalixir-setup

# 3. Create app and database
make gigalixir-create

# 4. Deploy
make gigalixir-deploy

# 5. Run migrations
make gigalixir-migrate

# 6. Create admin account
make gigalixir-admin
```

### Subsequent Deployments

```bash
# Deploy changes
make gigalixir-deploy

# Run migrations (if needed)
make gigalixir-migrate

# Check status
make gigalixir-status

# View logs
make gigalixir-logs
```

### Custom Domain Setup

```bash
# Add custom domain
make gigalixir-domain

# Follow the prompts to add your domain
# Then configure DNS at your registrar
```

**DNS Configuration:**
- Type: `CNAME`
- Name: `@` (or your subdomain)
- Value: `yourdomain.gigalixirdns.com`

### Monitoring

```bash
make gigalixir-status    # Check app status
make gigalixir-logs      # View logs
make gigalixir-domains   # List configured domains
make gigalixir-restart   # Restart app
```

### Admin Setup

**Local (development):**
```bash
make create-admin
# Follow prompts
```

**Production:**
```bash
make gigalixir-admin
# Follow prompts
```

### Rollback

```bash
make gigalixir-shell
gigalixir releases -a habit-tracker-prod
gigalixir releases:rollback -a habit-tracker-prod
```

## Troubleshooting

### Common Issues

**Port already in use:**
```bash
make down
make up
```

**Database issues:**
```bash
make down
make up
# Or reset database
make reset
```

**Container won't start:**
```bash
make logs
# Check for errors
```

**Deployment failed:**
```bash
make gigalixir-logs
make gigalixir-status
```

### Useful Commands

**Development:**
```bash
make help            # See all commands
make up              # Start services
make down            # Stop services
make restart         # Restart services
make logs            # View logs
make shell           # Open bash shell
make iex             # Open Elixir console
make test            # Run tests
make migrate         # Run migrations
make reset           # Reset database
```

**Deployment:**
```bash
make gigalixir-setup     # Test credentials
make gigalixir-create    # Create app & database
make gigalixir-deploy    # Deploy
make gigalixir-migrate   # Run migrations
make gigalixir-admin     # Create admin
make gigalixir-logs      # View logs
make gigalixir-status    # Check status
make gigalixir-domain    # Setup custom domain
make gigalixir-restart   # Restart app
make gigalixir-shell     # Open deployment shell
```

### Getting Help

1. Check logs: `make logs` or `make gigalixir-logs`
2. Check status: `make gigalixir-status`
3. Open shell: `make shell` or `make gigalixir-shell`
4. View all commands: `make help`
5. Read Docker docs: `docker/README.md`

## Additional Resources

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Ecto](https://hexdocs.pm/ecto/)
- [Gigalixir Docs](https://gigalixir.readthedocs.io/)
- [Docker Documentation](https://docs.docker.com/)
