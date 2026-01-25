# Production Issues & Solutions

## Issue: "Create Account" Button Not Working

### Symptoms
- Users click "Create account" button
- Form submits but no account is created
- Users are redirected back to login page
- No error message displayed to users

### Root Cause Analysis

Based on production logs from Gigalixir:

```
FATAL 53300 (too_many_connections) too many connections for role "74303881-b1da-4995-9f97-2a0976d19c11-user"
```

**Primary Issue: Database Connection Pool Exhaustion**

1. **Gigalixir Free Tier Limitation**: PostgreSQL has a hard limit of **4 concurrent connections**
2. **Current Configuration**: `POOL_SIZE` environment variable not set or set to 1
3. **Connection Leaks**: The application is attempting to create more database connections than available
4. **Silent Failures**: When database operations fail due to connection exhaustion, user registration fails silently

### Impact
- **User Registration**: Completely broken - no new users can sign up
- **Existing Users**: May experience intermittent login issues
- **Database Operations**: Any operation requiring DB access may fail randomly

### Solution

#### Step 1: Fix Database Connection Pool Size

Run the automated fix script:

```bash
make gigalixir-fix-db
```

Or manually:

```bash
# Set optimal pool size for Gigalixir free tier
docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c "
  gigalixir login -e YOUR_EMAIL -p YOUR_API_KEY -y && \
  gigalixir config:set -a habit-tracker-prod POOL_SIZE=2
"

# Restart the application
docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c "
  gigalixir login -e YOUR_EMAIL -p YOUR_API_KEY -y && \
  gigalixir ps:restart -a habit-tracker-prod
"
```

#### Step 2: Verify the Fix

```bash
# Check configuration
make gigalixir-status

# Monitor logs for connection errors
make gigalixir-logs
```

Look for:
- ✅ No more "too_many_connections" errors
- ✅ Successful user registration attempts
- ✅ Database operations completing normally

#### Step 3: Test User Registration

1. Visit https://habbits.xyz/users/register
2. Fill in email and password
3. Click "Create account"
4. Should see success message: "Account created! Please check your email..."
5. Should be redirected to login page

### Technical Details

#### Database Connection Pool Configuration

**Gigalixir Free Tier Limits:**
- Total connections: 4
- Recommended pool size: 2
- Leaves 2 connections for:
  - Migrations
  - Admin operations
  - Connection overhead

**Configuration Location:**
- File: `config/runtime.exs`
- Setting: `pool_size: String.to_integer(System.get_env("POOL_SIZE") || "1")`
- Environment: Set via `gigalixir config:set`

#### Why Pool Size = 2?

```
Total Available: 4 connections
├── App Pool: 2 connections (for web requests)
├── Migrations: 1 connection (when running)
└── Buffer: 1 connection (safety margin)
```

### Prevention

#### For Future Deployments

1. **Always set POOL_SIZE** during initial setup:
   ```bash
   gigalixir config:set -a APP_NAME POOL_SIZE=2
   ```

2. **Monitor connection usage**:
   ```bash
   make gigalixir-logs | grep -i "connection\|pool"
   ```

3. **Update deployment checklist** in `docs/DEVELOPMENT.md`

#### Configuration Checklist

Add to `.env.gigalixir`:
```bash
# Database Pool Size (CRITICAL for free tier)
POOL_SIZE=2
```

Add to deployment script:
```bash
# In docker/scripts/create-app.sh
gigalixir config:set -a $APP_NAME POOL_SIZE=2
```

### Related Issues

#### Oban Background Jobs

**Status**: Disabled in production (see `config/releases.exs`)

```elixir
# DISABLE Oban completely on free tier - only 2 DB connections available
config :habit_tracker, Oban, testing: :manual
```

**Reason**: Oban requires at least 1 dedicated connection, which would leave only 1 connection for the web app on free tier.

**Impact**: 
- ✅ Email reminders: Still work (sent via Resend API, no DB connection needed during send)
- ❌ Background job scheduling: Disabled
- ✅ Manual operations: All work normally

#### Email Confirmation

**Current Flow**:
1. User registers → Account created in DB
2. Confirmation email sent via Resend
3. User clicks link → Account confirmed
4. User can log in

**Note**: If registration fails due to DB issues, no email is sent (which is correct behavior).

### Monitoring

#### Key Metrics to Watch

```bash
# Connection errors
make gigalixir-logs | grep "too_many_connections"

# Registration attempts
make gigalixir-logs | grep "POST /users/register"

# Successful registrations
make gigalixir-logs | grep "Account created"

# Failed login attempts (may indicate registration issues)
make gigalixir-logs | grep "Failed login attempt"
```

#### Health Checks

```bash
# App status
make gigalixir-status

# Database connectivity
make gigalixir-shell
# Then run:
gigalixir pg:psql -a habit-tracker-prod
# Try: SELECT COUNT(*) FROM users;
```

### Upgrade Path

If you need more connections in the future:

**Gigalixir Standard Tier:**
- PostgreSQL: 20 connections
- Cost: ~$25/month
- Allows: Larger pool size, Oban background jobs, more concurrent users

**Configuration for Standard Tier:**
```bash
gigalixir config:set -a habit-tracker-prod POOL_SIZE=10
```

Then re-enable Oban in `config/releases.exs`:
```elixir
config :habit_tracker, Oban,
  repo: HabitTracker.Repo,
  queues: [default: 10, mailers: 20],
  plugins: [Oban.Plugins.Pruner]
```

### Additional Resources

- [Gigalixir Database Docs](https://gigalixir.readthedocs.io/en/latest/database.html)
- [Ecto Connection Pool](https://hexdocs.pm/ecto/Ecto.Repo.html#module-connection-pools)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)

### Quick Reference

```bash
# Fix database issues
make gigalixir-fix-db

# Check current config
make gigalixir-shell
gigalixir config -a habit-tracker-prod

# View logs
make gigalixir-logs

# Restart app
make gigalixir-restart

# Check status
make gigalixir-status
```

---

**Last Updated**: January 24, 2026
**Status**: Issue identified and fix script created
**Action Required**: Run `make gigalixir-fix-db` to apply fix
