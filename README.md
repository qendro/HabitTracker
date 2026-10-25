# Health Journal

A private iPhone-first Phoenix LiveView journal for stool observations, wellbeing
check-ins and timestamped notes. Multiple events per day, optional Bristol/urgency/
rating fields, backdating, private normalized photos, timeline filters, timezone and
preview settings, password management and ZIP exports are implemented. No public
signup, habit scoring, diagnosis, integrations, analytics or notification features.

The OTP namespace/release remains `HabitTracker` / `habit_tracker`. Original history
and applied migrations are preserved. Retired tables are left inert. Use a fresh,
dedicated database for the new production deployment.

Local development (Elixir 1.19, OTP 28, PostgreSQL 17, ImageMagick with HEIC, zip):

```sh
make db
mix setup
mix run -e 'HabitTracker.Release.owner()' # use a local private terminal
mix phx.server
```

Owner commands require a private interactive Linux terminal and disable password echo.
Do not put passwords in command arguments or source files. `make check` runs formatting,
strict compilation and ExUnit. `mix assets.build` copies CSS and bundles local JS.
No development command references production configuration.

[Architecture/baseline](docs/IMPLEMENTATION.md) · [Validation](docs/VALIDATION.md).

Install in iPhone Safari using Share → Add to Home Screen. Sessions can persist for
30 days and rotate after 14 days. All saves require a live server connection. The app
shows a disconnected banner and confirms saving only after a database write. Text,
ratings, retry ID and event time drafts live in **sessionStorage in the current tab**
for 24 hours and are isolated per account/form; logout clears drafts, including other
open tabs where BroadcastChannel is available. Draft storage can be unavailable in
restricted browsing modes. Images are never saved in browser storage; reselect them
after an interrupted upload/reload. No service worker is installed, so there is no
private HTML/photo/export caching or claim of full offline operation.

Photos accept JPEG, PNG and HEIC/HEIF. Original filenames never become storage paths.
The app retains oriented, stripped JPEG display images (max 4096px) and thumbnails,
not untouched originals. It does not infer findings or use EXIF time as event time.
Up to 3 photos per stool event; default input limits are 25 MiB and 60 megapixels.
A saved event survives a failed attachment, which can be retried or removed. Failed
sources remain private until deletion; pending jobs are reconciled every 15 minutes.
Exports contain schema/timezone metadata, JSON, formula-escaped CSV, and normalized
photos identified by stable entry/attachment IDs. Exports are temporary, not backups.

**Scope:** application and local development. At the owner's later request, Oracle,
ARM64 emulation, production deployment validation and provisional server-operation
scripts were removed from this work. No Oracle instance was accessed or changed.
The optional release Dockerfile is unverified; deployment, resource sizing, encrypted
off-host backups and restore rehearsals remain the owner's responsibility. Export
is not a backup. Keep PostgreSQL and the configured private media root together.
Actual iPhone checks require a device and are tracked in the validation checklist.

Owner provision/reset (private interactive terminal; password echo is disabled):

```sh
mix run -e 'HabitTracker.Release.owner()'              # refuses an existing account
OWNER_RESET=YES mix run -e 'HabitTracker.Release.owner()' # explicit password recovery
```

The command reads email and password from stdin; it never resets an owner at boot.
Password recovery revokes existing sessions. In an eventual release, the equivalent
command is `bin/habit_tracker eval 'HabitTracker.Release.owner()'` with the same
explicit `OWNER_RESET=YES` option for recovery. Use `HabitTracker.Release.migrate()`
for additive release migrations; do not reset an existing database.

Release configuration (for whoever hosts the app): `DATABASE_URL`, `PHX_HOST`,
`SECRET_KEY_BASE` (at least 64 bytes), and an absolute persistent `MEDIA_ROOT` are
required. Optional settings are `PORT` (4000), `POOL_SIZE` (5), `MAX_PHOTO_BYTES`
(26214400), and `MAX_PHOTO_PIXELS` (60000000). `PHX_SERVER=true` starts HTTP.
HTTPS/origin configuration expects the chosen hostname and a trusted proxy that
sets X-Forwarded-Proto; `/health` is the HTTP health-check exception. Neither
PostgreSQL nor the media root should be public. No mail or external error-reporting
credentials are required. The optional Dockerfile is source only, not a validated
production artifact.
