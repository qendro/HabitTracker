# Registration Issue - Gigalixir Free Tier

## Problem
With only 2 database connections available on Gigalixir free tier, the app cannot function properly during deployments or with any background processes.

## Current Status
- Oban has been removed from the application
- Pool size is set to 2
- But during rolling deployments, 2 pods run simultaneously, each trying to use 2 connections = 4 total needed

## The Real Issue
**Gigalixir free tier is incompatible with zero-downtime deployments** because:
1. Rolling deployment keeps old pod alive while new pod starts
2. Each pod needs 2 connections minimum
3. Free tier only has 2 connections total
4. Result: Neither pod can function properly

## Solutions

### Option 1: Reduce to 1 connection per pod (RISKY)
Set POOL_SIZE=1, but this means:
- Only 1 concurrent database operation at a time
- High risk of timeouts and failures
- Poor user experience

### Option 2: Upgrade to Standard Tier (RECOMMENDED)
- Standard tier databases start at $25/month
- Get 4+ connections minimum
- Proper connection pooling
- Background jobs can work
- Zero-downtime deployments work

### Option 3: Use External Database
- Use a different PostgreSQL provider (Supabase, Neon, etc.)
- Keep Gigalixir for hosting
- Get more connections

### Option 4: Accept Downtime
- Manually stop old pod before deploying new one
- Brief downtime during deployments
- Free tier remains free

## Immediate Fix
The app needs POOL_SIZE=1 to work on free tier, but this will cause other issues.
