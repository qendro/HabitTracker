# Production Fix Summary - Account Creation Issue

## Problem Identified ✅

Your "Create Account" button in production is not working due to **database connection pool exhaustion**.

### What's Happening

1. **Gigalixir Free Tier Limit**: Your PostgreSQL database allows only **4 concurrent connections**
2. **Current Configuration**: `POOL_SIZE` is set to 1 (or not set)
3. **The Issue**: The app is trying to use more connections than available
4. **Result**: All database operations fail, including user registration

### Evidence from Logs

```
FATAL 53300 (too_many_connections) too many connections for role "74303881-b1da-4995-9f97-2a0976d19c11-user"
```

This error appears repeatedly in your logs, preventing:
- New user registrations
- Database queries
- Any operation requiring database access

## The Fix 🔧

### Quick Fix (Recommended)

Run this single command:

```bash
make gigalixir-fix-db
```

This will:
1. Set `POOL_SIZE=2` on Gigalixir
2. Restart your application
3. Fix the connection pool exhaustion

### Manual Fix (Alternative)

If you prefer to do it manually:

```bash
# 1. Set the pool size
docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c "
  gigalixir login -e habbits.xyz@gmail.com -p 1250baa7-4cf6-4a8c-9546-ce151a1e061c -y && \
  gigalixir config:set -a habit-tracker-prod POOL_SIZE=2
"

# 2. Restart the app
docker compose -f docker/docker-compose.gigalixir.yml run --rm gigalixir bash -c "
  gigalixir login -e habbits.xyz@gmail.com -p 1250baa7-4cf6-4a8c-9546-ce151a1e061c -y && \
  gigalixir ps:restart -a habit-tracker-prod
"
```

## Why Pool Size = 2?

```
Gigalixir Free Tier: 4 total connections
├── Web App Pool: 2 connections ← Your app uses these
├── Migrations: 1 connection    ← When running migrations
└── Safety Buffer: 1 connection ← Overhead/admin tasks
```

Setting `POOL_SIZE=2` gives your app enough connections while leaving room for other operations.

## Verification Steps

After applying the fix:

### 1. Check Configuration
```bash
make gigalixir-status
```

### 2. Monitor Logs
```bash
make gigalixir-logs
```

Look for:
- ✅ No more "too_many_connections" errors
- ✅ Successful registration attempts
- ✅ Normal database operations

### 3. Test Registration
1. Go to https://habbits.xyz/users/register
2. Enter email and password
3. Click "Create account"
4. Should see: "Account created! Please check your email..."
5. Should redirect to login page

## Files Created/Modified

### New Files
1. **`scripts/fix-production-db.sh`** - Automated fix script
2. **`docs/PRODUCTION_ISSUES.md`** - Comprehensive troubleshooting guide
3. **`PRODUCTION_FIX_SUMMARY.md`** - This file

### Modified Files
1. **`Makefile`** - Added `make gigalixir-fix-db` command

## Next Steps

### Immediate Action Required

```bash
# Run the fix
make gigalixir-fix-db

# Wait 30 seconds for restart

# Check logs
make gigalixir-logs

# Test registration at https://habbits.xyz/users/register
```

### Future Prevention

When deploying new apps to Gigalixir free tier, always set:

```bash
gigalixir config:set -a APP_NAME POOL_SIZE=2
```

## Technical Background

### Why This Happened

Your `config/runtime.exs` has:
```elixir
pool_size: String.to_integer(System.get_env("POOL_SIZE") || "1")
```

Without setting `POOL_SIZE` environment variable on Gigalixir, it defaults to 1, which is insufficient for production workloads.

### Connection Pool Behavior

- **Pool Size 1**: Only 1 connection available → Exhausted immediately under load
- **Pool Size 2**: 2 connections available → Handles concurrent requests properly
- **Pool Size 4**: Would use all available connections → No room for migrations/admin

### Related Configuration

Your app also has Oban (background jobs) disabled in production:

```elixir
# config/releases.exs
config :habit_tracker, Oban, testing: :manual
```

This is correct for free tier since Oban would require additional connections.

## Monitoring Commands

```bash
# View all logs
make gigalixir-logs

# Check app status
make gigalixir-status

# Restart if needed
make gigalixir-restart

# Open deployment shell
make gigalixir-shell

# View all commands
make help
```

## Support Resources

- **Troubleshooting Guide**: `docs/PRODUCTION_ISSUES.md`
- **Development Guide**: `docs/DEVELOPMENT.md`
- **Architecture**: `docs/ARCHITECTURE.md`

## Summary

**Problem**: Database connection pool exhaustion preventing user registration
**Cause**: `POOL_SIZE` not configured for Gigalixir free tier limits
**Solution**: Set `POOL_SIZE=2` and restart
**Command**: `make gigalixir-fix-db`
**Time to Fix**: ~2 minutes
**Downtime**: ~30 seconds during restart

---

**Status**: Ready to apply fix
**Priority**: Critical - Blocking all new user registrations
**Estimated Fix Time**: 2 minutes
**Risk Level**: Low - Simple configuration change

Run `make gigalixir-fix-db` now to fix the issue! 🚀
