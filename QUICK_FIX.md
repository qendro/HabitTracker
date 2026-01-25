# 🚨 QUICK FIX - Account Creation Not Working

## The Problem
Users cannot create accounts on https://habbits.xyz/users/register

## The Cause
Database connection pool exhausted (Gigalixir free tier has only 4 connections)

## The Solution

### Run This Command:
```bash
make gigalixir-fix-db
```

### What It Does:
1. Sets `POOL_SIZE=2` on Gigalixir
2. Restarts your application
3. Fixes connection pool exhaustion

### Time Required:
⏱️ 2 minutes total (30 seconds downtime during restart)

---

## Verification

### 1. Check Configuration
```bash
make gigalixir-config
```
Look for: `POOL_SIZE=2`

### 2. Monitor Logs
```bash
make gigalixir-logs
```
Should NOT see: `too_many_connections` errors

### 3. Test Registration
Visit: https://habbits.xyz/users/register
- Enter email and password
- Click "Create account"
- Should see success message

---

## If You Need More Help

- **Full Details**: See `PRODUCTION_FIX_SUMMARY.md`
- **Troubleshooting**: See `docs/PRODUCTION_ISSUES.md`
- **All Commands**: Run `make help`

---

## Quick Commands Reference

```bash
# Fix the issue
make gigalixir-fix-db

# Check current config
make gigalixir-config

# View logs
make gigalixir-logs

# Check status
make gigalixir-status

# Restart app
make gigalixir-restart
```

---

**Ready?** Run `make gigalixir-fix-db` now! 🚀
