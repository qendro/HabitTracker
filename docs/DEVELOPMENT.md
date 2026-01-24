# Development Guide

Complete guide for developing, testing, and deploying the Habit Tracker application.

## Table of Contents

1. [Local Setup](#local-setup)
2. [Development Workflow](#development-workflow)
3. [Testing](#testing)
4. [Deployment](#deployment)
5. [Admin Setup](#admin-setup)
6. [Troubleshooting](#troubleshooting)

## Local Setup

### Prerequisites

- **Docker**: 20.10+ and Docker Compose 2.0+ (recommended)
- **OR Native**: Elixir 1.15+, PostgreSQL 15+, Node.js 18+

### Option 1: Docker Setup (Recommended)

**Start the application:**
```bash
docker compose -f docker/docker-compose.yml up
```

This will:
- Start PostgreSQL database
- Install dependencies
- Run database migrations
- Start the Phoenix server at http://localhost:4000

**Common Docker commands:**
```bash
# Stop services
docker compose -f docker/docker-compose.yml down

# View logs
docker compose -f docker/docker-compose.yml logs -f web

# Run tests
docker compose -f docker/docker-compose.yml run --rm test

# Access IEx console
docker compose -f docker/docker-compose.yml exec web iex -S mix

# Run migrations
docker compose -f docker/docker-compose.yml exec web mix ecto.migrate

# Reset database
docker compose -f docker/docker-compose.yml exec web mix ecto.reset

# Access database console
docker compose -f docker/docker-compose.yml exec db psql -U postgres -d habit_tracker_dev
```

### Option 2: Native Setup

**Install dependencies:**
```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies
cd assets && npm install && cd ..

# Setup database
mix ecto.setup
```

**Start the server:**
```bash
# Start Phoenix server
mix phx.server

# Or start with IEx console
iex -S mix phx.server
```

Visit http://localhost:4000

### Environment Variables

**Development** (copy `.env.dev` to `.env`):
```bash
# Copy the template
cp .env.dev .env

# Edit .env with your local settings
# For Docker, change DATABASE_HOST to 'db'
```

**Production** (see `.env.production` for template):
```bash
# Set via Gigalixir CLI (never commit actual values)
gigalixir config:set -a <app-name> SECRET_KEY_BASE="$(mix phx.gen.secret)"
gigalixir config:set -a <app-name> PHX_HOST="yourdomain.com"
gigalixir config:set -a <app-name> APP_URL="https://yourdomain.com"
gigalixir config:set -a <app-name> RESEND_API_KEY="your-key"
gigalixir config:set -a <app-name> SENDER_EMAIL="noreply@yourdomain.com"
gigalixir config:set -a <app-name> SENTRY_DSN="your-dsn"
gigalixir config:set -a <app-name> SENTRY_ENVIRONMENT="production"
gigalixir config:set -a <app-name> POOL_SIZE="10"
```

See `.env.dev` and `.env.production` for complete variable lists and descriptions.

## Development Workflow

### Project Structure

```
habit-tracker/
├── assets/              # Frontend assets (JS, CSS)
├── bin/                 # Deployment scripts
├── config/              # Application configuration
├── docker/              # Docker configuration
│   ├── docker-compose.yml
│   ├── Dockerfile (production)
│   └── Dockerfile.dev
├── docs/                # Documentation
│   ├── ARCHITECTURE.md
│   └── DEVELOPMENT.md
├── lib/
│   ├── habit_tracker/           # Business logic contexts
│   │   ├── accounts/            # User authentication
│   │   ├── admin/               # Admin functionality
│   │   ├── reminders/           # Email reminders
│   │   ├── tracker/             # Habit tracking
│   │   └── workers/             # Background jobs
│   └── habit_tracker_web/       # Web interface
│       ├── components/          # Reusable UI components
│       ├── controllers/         # HTTP controllers
│       └── live/                # LiveView modules
├── priv/
│   ├── repo/migrations/         # Database migrations
│   └── static/                  # Static assets
├── scripts/             # Helper scripts
└── test/                # Test files
```

### Making Changes

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make your changes:**
   - Write code
   - Add tests
   - Update documentation

3. **Run precommit checks:**
   ```bash
   mix precommit
   ```
   This runs: compile, format, and test

4. **Commit and push:**
   ```bash
   git add .
   git commit -m "Add my feature"
   git push origin feature/my-feature
   ```

### Code Style

- Follow Elixir style guide
- Run `mix format` before committing
- Use descriptive variable and function names
- Add documentation for public functions
- Keep functions small and focused

### Database Migrations

**Generate migration:**
```bash
mix ecto.gen.migration add_some_field
```

**Edit migration** in `priv/repo/migrations/`

**Run migration:**
```bash
mix ecto.migrate
```

**Rollback migration:**
```bash
mix ecto.rollback
```

### Adding Dependencies

1. Add to `mix.exs`
2. Run `mix deps.get`
3. Restart server if needed

## Testing

### Running Tests

**All tests:**
```bash
# With Docker
docker compose -f docker/docker-compose.yml run --rm test

# Without Docker
mix test
```

**Specific test file:**
```bash
mix test test/habit_tracker/tracker_test.exs
```

**Specific test:**
```bash
mix test test/habit_tracker/tracker_test.exs:42
```

**With coverage:**
```bash
mix test --cover
```

**Failed tests only:**
```bash
mix test --failed
```

### Test Structure

- **Unit tests**: Test individual functions and modules
- **Integration tests**: Test context interactions
- **LiveView tests**: Test user interactions
- **Property-based tests**: Test invariants (optional)

### Writing Tests

**Example unit test:**
```elixir
defmodule HabitTracker.TrackerTest do
  use HabitTracker.DataCase

  alias HabitTracker.Tracker

  describe "create_habit/2" do
    test "creates habit with valid attributes" do
      user = user_fixture()
      attrs = %{name: "Exercise", type: "binary", icon: "💪", color: "#FF0000"}
      
      assert {:ok, habit} = Tracker.create_habit(user, attrs)
      assert habit.name == "Exercise"
    end
  end
end
```

**Example LiveView test:**
```elixir
defmodule HabitTrackerWeb.TodayLiveTest do
  use HabitTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  test "displays habits for today", %{conn: conn} do
    user = user_fixture()
    habit = habit_fixture(user)
    
    {:ok, view, _html} = live(conn, ~p"/app/today")
    
    assert has_element?(view, "#habit-#{habit.id}")
  end
end
```

### Test Helpers

Located in `test/support/`:
- `DataCase`: Database test setup
- `ConnCase`: Controller/LiveView test setup
- `Fixtures`: Test data creation

## Deployment

### Deployment Overview

The application deploys to Gigalixir with separate staging and production environments.

**Deployment Flow:**
1. Test locally
2. Deploy to staging
3. Test staging
4. Deploy to production

### Prerequisites

**Install Gigalixir CLI:**
```bash
pip3 install gigalixir --user
gigalixir version
```

**Login:**
```bash
gigalixir login
```

### Staging Deployment

**Automated deployment:**
```bash
./bin/deploy_staging.sh
```

**Manual deployment:**
```bash
# Create staging app (first time only)
gigalixir create habit-tracker-staging

# Provision database (first time only)
gigalixir pg:create --free -a habit-tracker-staging

# Configure environment variables (first time only)
gigalixir config:set -a habit-tracker-staging SECRET_KEY_BASE="$(mix phx.gen.secret)"
gigalixir config:set -a habit-tracker-staging PHX_HOST="habit-tracker-staging.gigalixirapp.com"
gigalixir config:set -a habit-tracker-staging APP_URL="https://habit-tracker-staging.gigalixirapp.com"
# ... (see .env.production.example for complete list)

# Deploy
git push gigalixir-staging main

# Monitor logs
gigalixir logs -a habit-tracker-staging

# Run smoke tests
./bin/smoke_test_staging.sh
```

**Staging checklist:**
- [ ] All tests passing locally
- [ ] Code formatted and compiled without warnings
- [ ] Environment variables configured
- [ ] Database provisioned
- [ ] Deployment successful
- [ ] Health endpoint responding
- [ ] Smoke tests passing
- [ ] Manual testing complete

### Production Deployment

**Automated deployment (with safety checks):**
```bash
./bin/deploy_production.sh
```

This script includes:
- Staging verification requirement
- Multiple confirmation prompts
- Test execution
- Clean compilation check
- Health check verification
- Post-deployment smoke tests

**Manual deployment:**
```bash
# Create production app (first time only)
gigalixir create habit-tracker-prod

# Provision database (first time only)
gigalixir pg:create --size=0.6 -a habit-tracker-prod

# Configure environment variables (first time only)
gigalixir config:set -a habit-tracker-prod SECRET_KEY_BASE="$(mix phx.gen.secret)"
gigalixir config:set -a habit-tracker-prod PHX_HOST="habit-tracker-prod.gigalixirapp.com"
gigalixir config:set -a habit-tracker-prod APP_URL="https://habit-tracker-prod.gigalixirapp.com"
gigalixir config:set -a habit-tracker-prod RESEND_API_KEY="your-key"
gigalixir config:set -a habit-tracker-prod SENDER_EMAIL="noreply@yourdomain.com"
gigalixir config:set -a habit-tracker-prod SENTRY_DSN="your-dsn"
gigalixir config:set -a habit-tracker-prod SENTRY_ENVIRONMENT="production"
gigalixir config:set -a habit-tracker-prod POOL_SIZE="10"

# Deploy
git push gigalixir main

# Monitor logs
gigalixir logs -a habit-tracker-prod

# Run smoke tests
./bin/smoke_test_production.sh
```

**Production checklist:**
- [ ] Staging tested and stable
- [ ] All tests passing
- [ ] Team notified
- [ ] Environment variables configured
- [ ] Database provisioned (appropriate tier)
- [ ] Deployment successful
- [ ] Health endpoint responding
- [ ] Smoke tests passing
- [ ] Critical user flows tested
- [ ] Admin account created
- [ ] Monitoring configured
- [ ] Team notified of completion

### Rollback

If deployment fails:
```bash
# List releases
gigalixir releases -a <app-name>

# Rollback to previous release
gigalixir releases:rollback -a <app-name>
```

### Custom Domain Setup

**Add domain:**
```bash
gigalixir domains:add <app-name> yourdomain.com
gigalixir domains:add <app-name> www.yourdomain.com
```

**Configure DNS:**
```
Type: CNAME
Name: @ (or www)
Value: <app-name>.gigalixirapp.com
```

**Update environment variables:**
```bash
gigalixir config:set -a <app-name> PHX_HOST="yourdomain.com"
gigalixir config:set -a <app-name> APP_URL="https://yourdomain.com"
gigalixir ps:restart -a <app-name>
```

### Monitoring

**View logs:**
```bash
gigalixir logs -a <app-name>
gigalixir logs -a <app-name> --num=100
```

**Check application status:**
```bash
gigalixir ps -a <app-name>
```

**Health check:**
```bash
curl https://<app-name>.gigalixirapp.com/health
```

**Database status:**
```bash
gigalixir pg -a <app-name>
```

**Sentry:** Monitor errors at https://sentry.io

### Scaling

**Scale application:**
```bash
gigalixir ps:scale --replicas=2 -a <app-name>
```

**Scale database:**
```bash
gigalixir pg:scale --size=4 -a <app-name>
```

## Admin Setup

### Creating Admin Accounts

**Method 1: Using mix task (recommended):**
```bash
# With Docker
docker compose -f docker/docker-compose.yml exec web mix create_admin admin@example.com SecurePassword123

# Without Docker
mix create_admin admin@example.com SecurePassword123

# Or use the script
./scripts/create_admin.sh admin@example.com SecurePassword123
```

**Method 2: Using seeds.exs with environment variables:**
```bash
# With Docker
docker compose -f docker/docker-compose.yml exec web sh -c "ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=SecurePassword123 mix run priv/repo/seeds.exs"

# Without Docker
ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=SecurePassword123 mix run priv/repo/seeds.exs
```

**Method 3: Production (via Gigalixir):**
```bash
# Using the mix task
gigalixir run -a <app-name> -- bin/habit_tracker eval "HabitTracker.Admin.register_admin(%{email: \"admin@example.com\", password: \"SecurePassword123\"})"

# Or using seeds.exs with environment variables
gigalixir config:set -a <app-name> ADMIN_EMAIL="admin@example.com" ADMIN_PASSWORD="SecurePassword123"
gigalixir run -a <app-name> -- bin/habit_tracker eval "HabitTracker.Release.seed()"
gigalixir config:unset -a <app-name> ADMIN_EMAIL ADMIN_PASSWORD
```

### Admin Features

**Access admin panel:** http://localhost:4000/admin/login

**Capabilities:**
- View system metrics (DAU, WAU, MAU)
- Search and manage users
- View user details and activity
- Deactivate/reactivate accounts
- Force password resets
- Delete accounts (soft delete)
- Impersonate users (read-only mode)
- View audit log of admin actions

### Security Best Practices

1. **Use strong passwords** (minimum 12 characters)
2. **Limit admin access** to trusted personnel only
3. **Monitor admin actions** via activity log
4. **Rotate passwords** regularly
5. **Never commit** admin credentials to version control
6. **Use environment variables** for production credentials

## Troubleshooting

### Common Issues

#### Port Already in Use

```bash
# Find process using port 4000
lsof -i :4000

# Kill the process
kill -9 <PID>

# Or change port in docker-compose.yml
```

#### Database Connection Issues

```bash
# With Docker
docker compose -f docker/docker-compose.yml restart db
docker compose -f docker/docker-compose.yml exec db pg_isready -U postgres

# Check DATABASE_URL
echo $DATABASE_URL

# Test connection
mix ecto.migrate
```

#### Asset Compilation Issues

```bash
# Rebuild assets
mix assets.build

# Or with Docker
docker compose -f docker/docker-compose.yml exec web mix assets.build
```

#### Container Won't Start

```bash
# View logs
docker compose -f docker/docker-compose.yml logs web

# Rebuild from scratch
docker compose -f docker/docker-compose.yml down -v
docker compose -f docker/docker-compose.yml build --no-cache
docker compose -f docker/docker-compose.yml up
```

#### Migration Failures

```bash
# Check migration status
mix ecto.migrations

# Rollback last migration
mix ecto.rollback

# Reset database (WARNING: deletes all data)
mix ecto.reset
```

#### Test Failures

```bash
# Run specific failing test
mix test test/path/to/test.exs:42

# Check test database
MIX_ENV=test mix ecto.reset

# View detailed output
mix test --trace
```

### Deployment Issues

#### Application Won't Start

1. Check logs: `gigalixir logs -a <app-name>`
2. Verify environment variables: `gigalixir config -a <app-name>`
3. Check database: `gigalixir pg -a <app-name>`
4. Verify migrations ran: Check logs for migration output

#### SSL Certificate Issues

1. Verify DNS: `dig yourdomain.com`
2. Wait for DNS propagation (up to 48 hours)
3. Check certificate status: `gigalixir domains -a <app-name>`

#### Performance Issues

1. Check metrics: `gigalixir ps -a <app-name>`
2. Review Sentry for errors
3. Scale up: `gigalixir ps:scale --replicas=2 -a <app-name>`
4. Upgrade database: `gigalixir pg:scale --size=4 -a <app-name>`

### Getting Help

1. Check application logs
2. Review error messages in Sentry
3. Search existing issues
4. Check Phoenix and Elixir documentation
5. Ask in Elixir Forum or Phoenix Discord

### Useful Commands

**Development:**
```bash
mix precommit          # Run all checks
mix format             # Format code
mix compile            # Compile code
mix dialyzer           # Type checking (if configured)
```

**Database:**
```bash
mix ecto.create        # Create database
mix ecto.drop          # Drop database
mix ecto.migrate       # Run migrations
mix ecto.rollback      # Rollback migration
mix ecto.reset         # Drop, create, migrate, seed
mix ecto.setup         # Create, migrate, seed
```

**Testing:**
```bash
mix test               # Run all tests
mix test --failed      # Run failed tests
mix test --cover       # Run with coverage
mix test.watch         # Watch mode (if configured)
```

**Production:**
```bash
gigalixir logs -a <app-name>                    # View logs
gigalixir ps -a <app-name>                      # Check status
gigalixir config -a <app-name>                  # View config
gigalixir pg -a <app-name>                      # Database info
gigalixir releases -a <app-name>                # List releases
gigalixir releases:rollback -a <app-name>       # Rollback
gigalixir ps:restart -a <app-name>              # Restart app
gigalixir run -a <app-name> -- bin/habit_tracker eval "code"  # Run code
```

## Additional Resources

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Ecto](https://hexdocs.pm/ecto/)
- [Oban](https://hexdocs.pm/oban/)
- [Gigalixir Docs](https://gigalixir.readthedocs.io/)
- [Elixir Forum](https://elixirforum.com/)
- [Tailwind CSS](https://tailwindcss.com/)
