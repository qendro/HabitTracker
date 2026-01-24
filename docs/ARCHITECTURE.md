# Architecture Documentation

This document provides technical architecture details for the Habit Tracker application.

## Table of Contents

1. [Technology Stack](#technology-stack)
2. [System Architecture](#system-architecture)
3. [Database Schema](#database-schema)
4. [Context Boundaries](#context-boundaries)
5. [Security Implementation](#security-implementation)
6. [Design Decisions](#design-decisions)

## Technology Stack

### Backend
- **Elixir**: 1.15+
- **Phoenix**: 1.8+
- **Phoenix LiveView**: Real-time UI updates
- **Ecto**: Database ORM and query builder

### Database
- **PostgreSQL**: 15+
- Timezone support via `tzdata`
- JSONB for flexible data structures

### Frontend
- **Phoenix LiveView**: Server-rendered real-time UI
- **Tailwind CSS**: 4.x with custom design tokens
- **JavaScript**: Minimal, for hooks and interactivity

### Infrastructure
- **Oban**: Background job processing
- **Swoosh + Resend**: Email delivery
- **Sentry**: Error tracking
- **Gigalixir**: PaaS deployment platform

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
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Router     │  │  LiveViews   │  │   Contexts   │     │
│  │              │  │              │  │              │     │
│  │ - Public     │  │ - Today      │  │ - Accounts   │     │
│  │ - Auth       │  │ - Habits     │  │ - Tracker    │     │
│  │ - App        │  │ - Settings   │  │ - Admin      │     │
│  │ - Admin      │  │ - Admin      │  │ - Reminders  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Background Jobs (Oban)                    │
│  - Email reminders  - Metric rollups  - Account purge       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   External Services                          │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │  PostgreSQL  │  │    Resend    │                        │
│  │   Database   │  │  Email API   │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Timezone-aware**: All date calculations respect user timezone; store UTC, display local
2. **Sparse storage**: Only store explicit logs; no row = not_complete
3. **Immutable logs**: Historical habit_log records never modified by habit definition changes
4. **Mobile-first**: Touch-optimized UI with swipe gestures and responsive design
5. **Performance**: Efficient queries with proper indexing; minimize N+1 queries
6. **Security**: Defense in depth with rate limiting, CSRF protection, and secure sessions

## Database Schema

### Core Tables

#### users
```sql
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  hashed_password VARCHAR(255) NOT NULL,
  confirmed_at TIMESTAMP,
  timezone VARCHAR(255) NOT NULL DEFAULT 'UTC',
  theme VARCHAR(20) DEFAULT 'system',
  deleted_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX users_email_idx ON users(email);
CREATE INDEX users_deleted_at_idx ON users(deleted_at) WHERE deleted_at IS NOT NULL;
```

#### admins
```sql
CREATE TABLE admins (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  hashed_password VARCHAR(255) NOT NULL,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX admins_email_idx ON admins(email);
```

#### habits
```sql
CREATE TYPE habit_type AS ENUM ('binary', 'numeric', 'duration');
CREATE TYPE goal_horizon AS ENUM ('daily', 'weekly', 'monthly', 'yearly');

CREATE TABLE habits (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  icon VARCHAR(10) NOT NULL,
  color VARCHAR(7) NOT NULL,
  type habit_type NOT NULL,
  target_value DECIMAL(10,2),
  unit_label VARCHAR(50),
  goal_horizon goal_horizon NOT NULL DEFAULT 'daily',
  frequency_goal INTEGER,
  occurrence_schedule JSONB NOT NULL DEFAULT '{"type": "daily"}',
  position INTEGER NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT true,
  deleted_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX habits_user_id_idx ON habits(user_id);
CREATE INDEX habits_user_id_active_idx ON habits(user_id, active) WHERE deleted_at IS NULL;
CREATE INDEX habits_user_id_position_idx ON habits(user_id, position) WHERE active = true AND deleted_at IS NULL;
```

#### habit_logs
```sql
CREATE TYPE completion_status AS ENUM ('not_complete', 'planned', 'complete');

CREATE TABLE habit_logs (
  id BIGSERIAL PRIMARY KEY,
  habit_id BIGINT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_date DATE NOT NULL,
  status completion_status NOT NULL DEFAULT 'not_complete',
  numeric_value DECIMAL(10,2),
  duration_minutes INTEGER,
  notes TEXT,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(habit_id, local_date)
);

CREATE INDEX habit_logs_habit_id_idx ON habit_logs(habit_id);
CREATE INDEX habit_logs_user_id_local_date_idx ON habit_logs(user_id, local_date);
CREATE INDEX habit_logs_habit_id_local_date_idx ON habit_logs(habit_id, local_date);
CREATE INDEX habit_logs_inserted_at_idx ON habit_logs(inserted_at);
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
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX reminder_settings_user_id_idx ON reminder_settings(user_id);
CREATE INDEX reminder_settings_enabled_idx ON reminder_settings(enabled) WHERE enabled = true;
```

#### admin_actions
```sql
CREATE TABLE admin_actions (
  id BIGSERIAL PRIMARY KEY,
  admin_id BIGINT NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  action VARCHAR(50) NOT NULL,
  target_user_id BIGINT,
  success BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX admin_actions_admin_id_idx ON admin_actions(admin_id);
CREATE INDEX admin_actions_target_user_id_idx ON admin_actions(target_user_id);
CREATE INDEX admin_actions_inserted_at_idx ON admin_actions(inserted_at);
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
  active_habits INTEGER NOT NULL,
  completions_today INTEGER NOT NULL,
  avg_completion_rate DECIMAL(5,2) NOT NULL,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX daily_metrics_metric_date_idx ON daily_metrics(metric_date DESC);
```

## Context Boundaries

The application is organized into Phoenix contexts following domain-driven design:

### Accounts Context (`HabitTracker.Accounts`)
**Responsibility**: User authentication and account management

**Key Functions**:
- User registration with email confirmation
- Authentication and session management
- Password reset flow
- Timezone and theme preferences
- Account deletion (soft delete)
- Admin user management (separate from regular users)

### Tracker Context (`HabitTracker.Tracker`)
**Responsibility**: Core habit tracking functionality

**Key Functions**:
- Habit CRUD operations
- Habit log creation and updates
- Streak calculations
- Completion rate analytics
- Frequency goal progress
- Timezone-aware date logic
- Occurrence schedule handling

### Admin Context (`HabitTracker.Admin`)
**Responsibility**: System administration and monitoring

**Key Functions**:
- System metrics calculation (DAU, WAU, MAU)
- User search and management
- Account deactivation/reactivation
- User impersonation (read-only)
- Admin action audit logging
- Daily metric rollups

### Reminders Context (`HabitTracker.Reminders`)
**Responsibility**: Email reminder system

**Key Functions**:
- Reminder settings management
- Email composition and scheduling
- Integration with Resend API
- Timezone-aware reminder delivery

## Security Implementation

### Password Security

**Bcrypt Hashing**:
- Cost factor: 12 (production), 1 (test)
- Configuration: `config :bcrypt_elixir, log_rounds: 12`
- Timing attack protection via `Bcrypt.no_user_verify/0`
- Passwords marked with `redact: true` in schemas

**Password Validation**:
- Minimum: 8 characters
- Maximum: 72 characters (bcrypt limit)
- No complexity requirements (NIST guidelines)

### CSRF Protection

- `:protect_from_forgery` plug enabled in all browser pipelines
- Automatic token generation and validation
- Covers all state-changing operations (POST, PUT, DELETE)

### Input Validation & Sanitization

**Email Validation**:
- Format: `~r/^[^@,;\s]+@[^@,;\s]+$/`
- Max length: 160 characters
- Prevents injection attacks

**Security Module** (`HabitTracker.Security`):
- `sanitize_input/1`: HTML escapes user input
- `sanitize_email/1`: Removes control characters
- `safe_string?/1`: Validates safe characters

### SQL Injection Prevention

- 100% Ecto parameterized queries
- Automatic escaping and parameter binding
- No raw SQL queries

### Security Event Logging

**Logged Events**:
- Failed login attempts (email, IP, user agent)
- Successful logins
- Password reset requests
- Password changes
- Account deletions
- Privilege escalation attempts
- Rate limit violations
- Admin actions

**Log Format**:
- Structured metadata
- Contextual information (IP, user ID, timestamps)
- Appropriate log levels (info, warning, error)

### Session Security

**Cookie Configuration**:
- httpOnly flag (automatic)
- Secure flag (production via `force_ssl`)
- SameSite protection

**HTTPS Enforcement**:
- Forced SSL in production
- HSTS header automatically set
- Health check exception for localhost

**Session Management**:
- 30-day inactivity expiration
- Signed cookies
- Invalidation on password change

### Rate Limiting

**Implementation**:
- Library: Hammer 6.x
- Backend: ETS (single-node), Postgres/Redis (multi-node)

**Limits**:
- Registration: 5 per IP per hour
- Login: 10 per IP per 15 minutes
- Password reset: 3 per email per hour

**Response**: HTTP 429 with user-friendly message

## Design Decisions

### Timezone Handling

**Storage**: UTC timestamps with derived local_date
**Display**: User's configured IANA timezone
**Calculation**: All date logic respects user timezone

### Sparse Storage

**Principle**: Only store explicit user actions
**Implementation**: No habit_log row = implicit not_complete
**Benefit**: Reduced database size, faster queries

### Streak Calculation

**Definition**: Consecutive scheduled occurrences where habit was completed
**Exclusions**: Future dates (even if marked complete/planned)
**Timezone**: Calculated in user's timezone
**Performance**: Efficient backward iteration with early termination

### Occurrence Schedules

**Format**: JSONB for flexibility
**Types**:
- Daily: `{"type": "daily"}`
- Weekdays: `{"type": "weekdays", "days": [1,2,3,4,5]}`

**Future**: Can extend to support RRULE patterns

### Admin Separation

**Principle**: Admins and users are separate account types
**Implementation**: Separate tables, authentication flows, and permissions
**Benefit**: Clear separation of concerns, no privilege escalation risk

### Soft Deletes

**Implementation**: `deleted_at` timestamp field
**Purge**: Background job after 30 days
**Benefit**: Data recovery window, audit trail

### Background Jobs

**Library**: Oban
**Queues**: default, emails, metrics, cleanup
**Retry Policy**: 3 attempts with exponential backoff
**Idempotency**: All jobs designed to be safely retried

### Email Delivery

**Provider**: Resend API
**Library**: Swoosh
**Templates**: Server-rendered with HEEx
**Scheduling**: Timezone-aware via Oban

### Error Tracking

**Provider**: Sentry
**Filter**: Sensitive data scrubbed (passwords, tokens)
**Integration**: Automatic error reporting
**Monitoring**: Real-time alerts

## Performance Considerations

### Database Indexing

- Composite indexes for common query patterns
- Partial indexes for filtered queries
- Index on foreign keys for joins

### Query Optimization

- Preload associations to avoid N+1
- Use `select` to limit returned fields
- Aggregate queries for metrics
- Efficient streak calculation with early termination

### Caching Strategy

- LiveView assigns for UI state
- Database query results cached in assigns
- No external cache layer (YAGNI)

### Asset Optimization

- Tailwind CSS purging for production
- JavaScript minification
- Asset fingerprinting for cache busting

## Deployment Architecture

### Gigalixir Platform

- Managed Elixir hosting
- Automatic SSL via Let's Encrypt
- Managed PostgreSQL
- Git-based deployment
- Release builds

### Environment Separation

- **Development**: Local Docker or native
- **Staging**: Gigalixir staging app
- **Production**: Gigalixir production app

### Monitoring

- Health check endpoint: `/health`
- Sentry error tracking
- Gigalixir metrics
- Database monitoring

## Future Considerations

### Scalability

- Current: Single-node ETS rate limiting
- Future: Redis-backed rate limiting for multi-node
- Database: Connection pooling configured
- Background jobs: Oban scales horizontally

### Feature Extensions

- Advanced RRULE occurrence patterns
- Habit templates and categories
- Social features (sharing, challenges)
- Mobile native apps
- API for third-party integrations

### Technical Debt

- Property-based tests (optional tasks remaining)
- Additional unit test coverage
- Performance profiling and optimization
- Accessibility audit and improvements

## References

- [Phoenix Framework Documentation](https://hexdocs.pm/phoenix/)
- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view/)
- [Ecto Documentation](https://hexdocs.pm/ecto/)
- [Oban Documentation](https://hexdocs.pm/oban/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
