# Architecture Documentation

This document provides technical architecture details for the Habit Tracker application.

## Table of Contents

1. [Technology Stack](#technology-stack)
2. [System Architecture](#system-architecture)
3. [Database Schema](#database-schema)
4. [Context Boundaries](#context-boundaries)
5. [Security Implementation](#security-implementation)
6. [Design Decisions](#design-decisions)
7. [Performance Considerations](#performance-considerations)
8. [Deployment Architecture](#deployment-architecture)
9. [Future Considerations](#future-considerations)
10. [References](#references)

## Technology Stack

### Backend
- **Elixir**: ~> 1.19
- **Phoenix**: 1.8.x
- **Phoenix LiveView**: 1.1.x (real-time UI updates)
- **Ecto / EctoSQL**: 3.13
- **Oban**: 2.18 (background jobs)
- **Hammer**: 6.x (rate limiting)
- **Bcrypt**: 3.x (password hashing)
- **Bandit**: 1.5 (HTTP server adapter)

### Database
- **PostgreSQL**: 15
- **CITEXT extension** for case-insensitive email columns
- **JSONB / map columns** for flexible structures

### Frontend
- **Phoenix LiveView**: server-rendered real-time UI
- **Tailwind CSS**: via `mix tailwind` (version managed by the build tool)
- **esbuild**: via `mix esbuild` (version managed by the build tool)
- **Minimal JavaScript hooks** (timezone detection, swipe navigation, sortable lists)

### Infrastructure
- **Swoosh** for email delivery
- **Resend adapter** in production (fallback to Test if missing key)
- **Sentry** for error tracking
- **Gigalixir** for deployment

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
│  (Browser: Desktop Safari/Chrome, Mobile iOS Safari)        │
│              LiveView WebSocket Connection                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Phoenix Application                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Router     │  │  LiveViews   │  │   Contexts   │       │
│  │              │  │              │  │              │       │
│  │ - Public     │  │ - Today      │  │ - Accounts   │       │
│  │ - Auth       │  │ - Habits     │  │ - Tracker    │       │
│  │ - App        │  │ - Settings   │  │ - Admin      │       │
│  │ - Admin      │  │ - Admin      │  │ - Reminders  │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Background Jobs (Oban)                    │
│  - Email reminders  - Metrics rollups  - Account purge       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       PostgreSQL                             │
│  - Users / Tokens  - Habits / Logs  - Admin / Metrics        │
└─────────────────────────────────────────────────────────────┘
```

## Database Schema

> **Note:** Enum-like fields are stored as strings in Postgres and are enforced by `Ecto.Enum` in the application layer.

### Core Tables

#### users
```sql
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  email CITEXT NOT NULL,
  hashed_password VARCHAR(255),
  confirmed_at TIMESTAMP,
  timezone VARCHAR(255) NOT NULL DEFAULT 'UTC',
  theme VARCHAR(50) DEFAULT 'system',
  deleted_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX users_email_index ON users(email);
CREATE INDEX users_deleted_at_index ON users(deleted_at) WHERE deleted_at IS NOT NULL;
```

#### users_tokens
```sql
CREATE TABLE users_tokens (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token BYTEA NOT NULL,
  context VARCHAR(255) NOT NULL,
  sent_to VARCHAR(255),
  authenticated_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL
);

CREATE INDEX users_tokens_user_id_index ON users_tokens(user_id);
CREATE UNIQUE INDEX users_tokens_context_token_index ON users_tokens(context, token);
```

#### admins
```sql
CREATE TABLE admins (
  id BIGSERIAL PRIMARY KEY,
  email CITEXT NOT NULL,
  hashed_password VARCHAR(255) NOT NULL,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX admins_email_index ON admins(email);
```

#### admins_tokens
```sql
CREATE TABLE admins_tokens (
  id BIGSERIAL PRIMARY KEY,
  admin_id BIGINT NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  token BYTEA NOT NULL,
  context VARCHAR(255) NOT NULL,
  inserted_at TIMESTAMP NOT NULL
);

CREATE INDEX admins_tokens_admin_id_index ON admins_tokens(admin_id);
CREATE UNIQUE INDEX admins_tokens_context_token_index ON admins_tokens(context, token);
```

#### habits
```sql
CREATE TABLE habits (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  icon VARCHAR(50),
  color VARCHAR(50),
  type VARCHAR(20) NOT NULL,        -- :binary | :numeric | :duration
  target_value INTEGER,
  unit_label VARCHAR(50),
  goal_horizon VARCHAR(20) NOT NULL, -- :daily | :weekly | :monthly | :yearly
  frequency_goal INTEGER,
  occurrence_schedule JSONB NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  deleted_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX habits_user_id_index ON habits(user_id);
CREATE INDEX habits_position_index ON habits(position);
```

#### habit_logs
```sql
CREATE TABLE habit_logs (
  id BIGSERIAL PRIMARY KEY,
  habit_id BIGINT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL,       -- :not_complete | :planned | :complete
  numeric_value INTEGER,
  duration_minutes INTEGER,
  notes TEXT,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(habit_id, local_date)
);

CREATE INDEX habit_logs_habit_id_index ON habit_logs(habit_id);
CREATE INDEX habit_logs_user_id_index ON habit_logs(user_id);
CREATE INDEX habit_logs_local_date_index ON habit_logs(local_date);
```

### Supporting Tables

#### reminder_settings
```sql
CREATE TABLE reminder_settings (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  time_of_day TIME NOT NULL DEFAULT '08:00:00',
  habit_selection VARCHAR(20) NOT NULL DEFAULT 'all',
  selected_habit_ids BIGINT[] DEFAULT '{}',
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX reminder_settings_enabled_index ON reminder_settings(enabled);
```

#### admin_actions
```sql
CREATE TABLE admin_actions (
  id BIGSERIAL PRIMARY KEY,
  admin_id BIGINT NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  action VARCHAR(50) NOT NULL,
  target_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  success BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB,
  inserted_at TIMESTAMP NOT NULL
);

CREATE INDEX admin_actions_admin_id_index ON admin_actions(admin_id);
CREATE INDEX admin_actions_target_user_id_index ON admin_actions(target_user_id);
CREATE INDEX admin_actions_inserted_at_index ON admin_actions(inserted_at);
CREATE INDEX admin_actions_action_index ON admin_actions(action);
```

#### daily_metrics
```sql
CREATE TABLE daily_metrics (
  id BIGSERIAL PRIMARY KEY,
  metric_date DATE NOT NULL UNIQUE,
  total_users INTEGER NOT NULL,
  new_users_today INTEGER NOT NULL,
  dau INTEGER NOT NULL,
  wau INTEGER NOT NULL,
  mau INTEGER NOT NULL,
  total_habits INTEGER NOT NULL,
  completions_today INTEGER NOT NULL,
  avg_completion_rate FLOAT NOT NULL,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

#### oban_jobs
```sql
-- Managed by Oban migration (job state, attempts, queue, args, timestamps).
-- See Oban migration for exact schema.
```

## Context Boundaries

The application is organized into Phoenix contexts following domain-driven design:

### Accounts Context (`HabitTracker.Accounts`)
**Responsibility**: User authentication and account management

**Key Functions**:
- User registration with email confirmation (tokens in `users_tokens`)
- Authentication and session management (remember-me cookie + session tokens)
- Password reset flow
- Timezone preferences
- Account deletion (soft delete)
- `Scope` struct used to represent the current authenticated user in LiveView

### Tracker Context (`HabitTracker.Tracker`)
**Responsibility**: Core habit tracking functionality

**Key Functions**:
- Habit CRUD operations (soft delete)
- Habit log creation and updates (sparse storage)
- Streak calculations
- Completion rate analytics
- Frequency goal progress
- Timezone-aware date logic
- Occurrence schedule handling
- Read-only enforcement when admin impersonation is active

### Admin Context (`HabitTracker.Admin`)
**Responsibility**: System administration and monitoring

**Key Functions**:
- Admin authentication (separate `admins` + `admins_tokens`)
- System metrics calculation (DAU/WAU/MAU)
- User search and management
- Account deactivation/reactivation
- Admin action audit logging (`admin_actions`)
- Daily metric rollups (`daily_metrics`)
- Admin impersonation (read-only) with audit logging

### Reminders Context (`HabitTracker.Reminders`)
**Responsibility**: Email reminder system

**Key Functions**:
- Reminder settings management
- Email composition
- Timezone-aware reminder scheduling
- Oban workers: `ScheduleRemindersJob` and `ReminderEmailJob`

## Security Implementation

### Password Security
- **Bcrypt Hashing**:
  - Cost factor: 12 (production), 1 (test)
  - Configuration: `config :bcrypt_elixir, log_rounds: 12`
  - Timing attack protection via `Bcrypt.no_user_verify/0`
  - Passwords marked with `redact: true` in schemas

**Password Validation**:
- Minimum: 8 characters
- Maximum: 72 characters (bcrypt limit)
- No complexity requirements (NIST guidelines)

### CSRF Protection
- `:protect_from_forgery` plug enabled in browser pipelines
- Automatic token generation and validation
- Covers all state-changing operations (POST, PUT, DELETE)

### Input Validation & Sanitization

**Email Validation**:
- Format: `~r/^[^@,;\s]+@[^@,;\s]+$/`
- Max length: 160 characters
- Stored in CITEXT for case-insensitive uniqueness

**Security Module** (`HabitTracker.Security`):
- `sanitize_input/1`: HTML escapes user input
- `sanitize_email/1`: Removes control characters
- `safe_string?/1`: Validates safe characters

### SQL Injection Prevention
- 100% Ecto parameterized queries
- No raw SQL queries (except safe fragments for metrics)

### Security Event Logging
- Centralized logging via `HabitTracker.Security`
- Structured metadata for security-relevant events

### Session Security
- Session tokens stored in `users_tokens` and `admins_tokens`
- 30-day inactivity expiration
- Session reissue after 14 days of age
- Signed remember-me cookie (30 days)
- Sessions invalidated on password change

### Rate Limiting
- **Implementation**: Hammer with ETS backend
- **Limits**:
  - Registration: 5 per IP per hour
  - Login: 10 per IP per 15 minutes
  - Password reset: 3 per email per hour
- **Response**: HTTP 429 with user-friendly message
- **Note**: ETS is single-node; multi-node requires Redis/Postgres backend

### Impersonation Safety
- Admin impersonation sets `readonly_mode` in session
- Tracker mutations check `readonly_mode` and return `:readonly_mode` errors
- UI banner indicates read-only state and allows stopping impersonation

## Design Decisions

### Timezone Handling
- **Storage**: UTC timestamps + derived `local_date`
- **Display**: User's configured IANA timezone
- **Calculation**: All date logic respects user timezone

### Sparse Storage
- **Principle**: Only store explicit user actions
- **Implementation**: Missing habit_log row implies `not_complete`
- **Benefit**: Reduced database size and faster queries

### Streak Calculation
- **Definition**: Consecutive scheduled occurrences where habit was completed
- **Exclusions**: Future dates (even if marked complete/planned)
- **Timezone**: Calculated in user's timezone

### Occurrence Schedules
- **Format**: JSONB map for flexibility
- **Types**:
  - Daily: `{"type": "daily"}`
  - Weekdays: `{"type": "weekdays", "days": [1,2,3,4,5]}`
  - Day flags: `{"monday": true, "wednesday": true, ...}`

### Admin Separation
- **Principle**: Admins and users are separate account types
- **Implementation**: Separate tables, auth flows, and permissions

### Soft Deletes
- **Users and Habits**: `deleted_at` timestamp field
- **Purge**: Background job removes data after 30 days

### Background Jobs
- **Library**: Oban
- **Queues**: default, emails, metrics, cleanup
- **Retry Policy**: 3 attempts with exponential backoff
- **Idempotency**: Jobs designed to be safely retried
- **Production Note**: Oban is set to manual mode in `runtime.exs` to reduce
  DB connections on the Gigalixir free tier. Enable if background jobs are required.

### Email Delivery
- **Library**: Swoosh
- **Adapter**: Resend in production (configured via `RESEND_API_KEY`)
- **Non-prod**: Local/Test adapter

### Error Tracking
- **Provider**: Sentry
- **Filter**: Sensitive data scrubbed (passwords, tokens)
- **Integration**: Automatic error reporting

## Performance Considerations

### Database Indexing
- Indexes on foreign keys (users, habits, logs)
- Unique constraints for tokens and daily metrics
- Partial index on deleted users

### Query Optimization
- Preload associations to avoid N+1
- Use `select` to limit returned fields
- Aggregate queries for metrics
- Efficient streak calculation with early termination

### Caching Strategy
- LiveView assigns for UI state
- No external cache layer

### Asset Optimization
- Tailwind CSS minification for production
- JavaScript minification via esbuild
- Asset fingerprinting for cache busting

## Deployment Architecture

### Gigalixir Platform
- Managed Elixir hosting
- Automatic SSL via Let's Encrypt
- Managed PostgreSQL
- Git-based deployment
- Release builds

### Environment Separation
- **Development**: Docker-first workflow (optional native dev)
- **Staging**: Gigalixir staging app
- **Production**: Gigalixir production app

### Monitoring
- Health check endpoint: `/health`
- Sentry error tracking
- Gigalixir metrics
- Database monitoring

## Future Considerations

### Scalability
- Redis-backed rate limiting for multi-node
- Scale Oban queues and pool sizes as needed

### Feature Extensions
- Advanced RRULE occurrence patterns
- Habit templates and categories
- Theme preference persistence (DB column exists; UI wiring pending)
- API for third-party integrations

### Technical Debt
- Additional unit/property tests (admin actions, impersonation, metrics)
- Accessibility audit improvements

## References

- [Phoenix Framework Documentation](https://hexdocs.pm/phoenix/)
- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view/)
- [Ecto Documentation](https://hexdocs.pm/ecto/)
- [Oban Documentation](https://hexdocs.pm/oban/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
