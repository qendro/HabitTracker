# Deployment Guide (Docker-First)

This project is ready to deploy using the production Docker image at
`docker/Dockerfile`.

This guide focuses on **Northflank (free sandbox tier)** with notes for
Gigalixir where relevant.

## Production Image

Build locally:

```bash
docker build -f docker/Dockerfile -t habit-tracker:prod .
```

Key runtime behavior:
- The container listens on port `4000` by default.
- `PHX_SERVER=true` is baked into the image.
- Migrations can be run with:
  `/app/bin/habit_tracker eval "HabitTracker.Release.migrate()"`

## Required Environment Variables

Set these in your platform's environment/secret settings:

- `DATABASE_URL` (required)
- `SECRET_KEY_BASE` (required)
- `PHX_HOST` (required)
- `APP_URL` (recommended; defaults to `https://PHX_HOST`)

Common optional variables:
- `POOL_SIZE` (defaults to `1`)
- `PORT` (defaults to `4000`)
- `RESEND_API_KEY`
- `SENDER_EMAIL`
- `SENTRY_DSN`
- `SENTRY_ENVIRONMENT`

Generate a secret:

```bash
mix phx.gen.secret
```

## Northflank Deployment (Recommended)

### Prerequisites

- Add a default payment method in Northflank (the API will reject service/addon creation otherwise).
- Link a Git provider (GitHub/GitLab/Bitbucket) to Northflank and push this repo there.
- Create a Northflank API token and keep it out of the repo.
- Be ready to add DNS records for domain verification and routing.

### Automated Deployment Script (API-Driven)

You can automate most of the setup using `scripts/northflank_deploy.sh`.

Example:

```bash
# Required
export NF_TOKEN=your_northflank_api_token
export NF_REPO_URL=https://github.com/<you>/<repo>

# Optional overrides
export NF_REPO_BRANCH=main
export NF_DOMAIN=habbits.xyz
export NF_SUBDOMAIN=@

./scripts/northflank_deploy.sh
```

What the script does:
- Ensures the project exists (defaults to `habbits` in `europe-west`).
- Registers your domain and prints the TXT record required for verification.
- Creates a PostgreSQL addon.
- Creates a combined service that builds from `docker/Dockerfile`.
- Configures port `4000` and a `/health` readiness probe.
- Assigns the custom domain once the domain is verified. citeturn3search5

If it fails, check `/tmp/northflank_last_error.json` for the latest API error payload.

### Manual Northflank Steps (UI-Driven)

### 1. Create a database

In Northflank:
1. Create a PostgreSQL addon.
2. Expose its connection string to your service as `DATABASE_URL`.

Northflank provides connection details via secret groups. The important
requirement for this app is that the final variable name is exactly
`DATABASE_URL`. citeturn3search4

### 2. Create a service from the Dockerfile

In Northflank:
1. Create a new service.
2. Choose to deploy from your Git repository.
3. Select the Dockerfile at `docker/Dockerfile`.
4. Set the service port to `4000`.

### 3. Configure environment variables

Add the required variables listed above:
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_HOST`
- `APP_URL`

Suggested values:
- `PHX_HOST`: your Northflank domain (or custom domain)
- `APP_URL`: `https://<your-domain>`
- `POOL_SIZE`: start with `1` on free tiers

### 4. Configure health checks

Use:
- Path: `/health`
- Port: `4000`

This app explicitly excludes `/health` from SSL redirects to allow
internal platform health checks over HTTP. citeturn3search3

### 5. Run migrations

Run migrations using a one-off job or command override:

```bash
/app/bin/habit_tracker eval "HabitTracker.Release.migrate()"
```

Then deploy/redeploy the web service normally. citeturn3search2

## Gigalixir Notes

Gigalixir-specific helper scripts live in `docker/scripts/` and are
orchestrated via the `Makefile` targets beginning with `gigalixir-`.
