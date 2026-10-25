# Baseline and implementation record

The clean checkout and preserved baseline are commit 6fbf779. No AGENTS.md was present.
Branch: feature/health-journal. Applied migrations are unchanged. Legacy tables are
retained inert; a new dedicated production database is preferred. No reset or destructive
cleanup is part of deployment. Namespace and release remain habit_tracker.

Baseline ran in local AMD64 Debian/Elixir 1.19.5/OTP 28 with PostgreSQL 17.6:
261 tests, 19 properties, 3 pre-existing failures: confirmation flash representation,
Today toggle payload, Journal delete test payload. These old feature tests were removed
with their features; new auth, context, media and LiveView tests cover the journal.

Removed: habit contexts/screens/components/fixtures, daily journal upserts, admin
accounts/auth/impersonation/metrics UI, reminders/jobs/email, Sentry, Sortable, old
hosting scripts/buildpacks and specifications. No public signup or email recovery.
Authentication retains bcrypt, persistent expiring sessions, CSRF and login rate limits.
Password management uses current-password verification or explicit release reset.

Phoenix/LiveView remain on 1.8/1.1; compatible security updates were selected after
Hex reported advisories in the baseline lock. See mix.lock for exact versions.

Architecture: typed JSON details validated with embedded schemas; per-user retry UUIDs;
optimistic entry locks; UTC times and one timezone module. Media inputs are staged on
persistent disk; one Oban media queue processes and reconciles jobs; failed inputs can
be retried. Ready photos are normalized JPEGs with stripped metadata, never public
static assets. Durable tombstones survive entry deletion. Export copies photos singly
and writes JSON/CSV/ZIP to private disk, with one-hour abandoned-export cleanup.

No Oracle access, hardware verification or deployment was performed.

Scope update: owner requested stopping Oracle/ARM64/emulator validation and focusing
on the application. Temporary ARM64 builder/emulator and provisional deployment,
backup and restore scripts were removed. No production image/restore verification
or resource measurement is claimed. Optional Dockerfile remains unverified.
