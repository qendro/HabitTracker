# Design Document: Habit Tracker Web Application

## Overview

This design document specifies the technical architecture for a habit tracking web application built with Elixir Phoenix LiveView. The system enables users to create habits with flexible scheduling, log completions across time, and track progress through an intuitive dashboard. The application follows a single-tenant model with separate user and admin roles, deployed on Gigalixir with Postgres and Resend for email delivery.

### Technology Stack

- **Backend**: Elixir 1.15+ with Phoenix 1.7+ and Phoenix LiveView
- **Database**: PostgreSQL 15+
- **Styling**: Tailwind CSS 3.x with custom design tokens
- **Email**: Resend API
- **Background Jobs**: Oban 2.x
- **Deployment**: Gigalixir with managed Postgres
- **Authentication**: phx.gen.auth with custom extensions

### Key Design Principles

1. **Timezone-aware**: All date calculations respect user timezone; store UTC, display local
2. **Sparse storage**: Only store explicit logs; no row = not_complete
3. **Immutable logs**: Historical habit_log records never modified by habit definition changes
4. **Mobile-first**: Touch-optimized UI with swipe gestures and responsive design
5. **Performance**: Efficient queries with proper indexing; minimize N+1 queries
6. **Security**: Defense in depth with rate limiting, CSRF protection, and secure sessions

## Architecture

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

### Context Boundaries

The application is organized into Phoenix contexts:


**Accounts Context** (`HabitTracker.Accounts`)
- User registration, authentication, session management
- Password reset and email confirmation
- User settings (timezone, theme, email preferences)
- Separate admin user management

**Tracker Context** (`HabitTracker.Tracker`)
- Habit CRUD operations
- Habit log creation and updates
- Streak calculations
- Analytics and progress queries
- Timezone-aware date logic

**Admin Context** (`HabitTracker.Admin`)
- System metrics and analytics
- User management (search, deactivate, delete)
- Admin action logging
- "View as user" functionality

**Reminders Context** (`HabitTracker.Reminders`)
- Reminder settings management
- Email composition and scheduling
- Integration with Resend API

## Components and Interfaces

### Phoenix Contexts API

#### Accounts Context

```elixir
defmodule HabitTracker.Accounts do
  # User registration and authentication
  def register_user(attrs) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def authenticate_user(email, password) :: {:ok, User.t()} | {:error, :invalid_credentials}
  def get_user!(id) :: User.t()
  def update_user_timezone(user, timezone) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  
  # Password management
  def reset_password_request(email) :: :ok
  def reset_password(token, new_password) :: {:ok, User.t()} | {:error, :invalid_token}
  
  # Email confirmation
  def send_confirmation_email(user) :: :ok
  def confirm_email(token) :: {:ok, User.t()} | {:error, :invalid_token}
  
  # Account deletion
  def soft_delete_user(user) :: {:ok, User.t()}
  def schedule_user_purge(user) :: :ok
  
  # Admin users
  def create_admin(attrs) :: {:ok, Admin.t()} | {:error, Ecto.Changeset.t()}
  def authenticate_admin(email, password) :: {:ok, Admin.t()} | {:error, :invalid_credentials}
end
```

#### Tracker Context

```elixir
defmodule HabitTracker.Tracker do
  # Habit management
  def create_habit(user, attrs) :: {:ok, Habit.t()} | {:error, Ecto.Changeset.t()}
  def update_habit(habit, attrs) :: {:ok, Habit.t()} | {:error, Ecto.Changeset.t()}
  def delete_habit(habit) :: {:ok, Habit.t()}
  def list_active_habits(user) :: [Habit.t()]
  def reorder_habits(user, habit_ids) :: :ok
  
  # Habit logs
  def log_habit(habit, local_date, attrs) :: {:ok, HabitLog.t()} | {:error, Ecto.Changeset.t()}
  def update_habit_log(log, attrs) :: {:ok, HabitLog.t()} | {:error, Ecto.Changeset.t()}
  def get_logs_for_date(user, local_date) :: [HabitLog.t()]
  def get_log(habit, local_date) :: HabitLog.t() | nil
  
  # Scheduled dates
  def is_scheduled?(habit, local_date) :: boolean()
  def scheduled_dates(habit, date_range) :: [Date.t()]
  
  # Streaks and analytics
  def calculate_streak(habit, as_of_date) :: non_neg_integer()
  def completion_rate(habit, period) :: float()
  def frequency_progress(habit, period) :: {completed :: integer(), target :: integer()}
  
  # Dashboard queries
  def today_dashboard(user, local_date) :: [HabitWithProgress.t()]
end
```


#### Admin Context

```elixir
defmodule HabitTracker.Admin do
  # Metrics
  def system_metrics() :: %{
    total_users: integer(),
    new_users_today: integer(),
    new_users_this_week: integer(),
    dau: integer(),
    wau: integer(),
    mau: integer(),
    total_habits: integer(),
    active_habits: integer(),
    completions_today: integer(),
    avg_completion_rate: float()
  }
  
  # User management
  def search_users(query) :: [User.t()]
  def get_user_summary(user_id) :: UserSummary.t()
  def deactivate_user(user) :: {:ok, User.t()}
  def reactivate_user(user) :: {:ok, User.t()}
  def admin_delete_user(admin, user) :: {:ok, User.t()}
  def force_password_reset(user) :: :ok
  
  # Admin actions
  def log_admin_action(admin, action, target_user_id, metadata) :: :ok
  def list_admin_actions(filters) :: [AdminAction.t()]
  
  # View as user
  def impersonate_user(admin, user_id) :: {:ok, User.t()} | {:error, :not_found}
end
```

#### Reminders Context

```elixir
defmodule HabitTracker.Reminders do
  # Settings
  def get_reminder_settings(user) :: ReminderSettings.t()
  def update_reminder_settings(user, attrs) :: {:ok, ReminderSettings.t()} | {:error, Ecto.Changeset.t()}
  
  # Email scheduling
  def schedule_daily_reminders() :: :ok
  def send_reminder_email(user) :: {:ok, :sent} | {:error, term()}
  
  # Email templates
  def compose_reminder_email(user, habits) :: Email.t()
  def compose_confirmation_email(user, token) :: Email.t()
  def compose_password_reset_email(user, token) :: Email.t()
end
```

### LiveView Components

#### TodayLive (Primary Dashboard)

**Route**: `/app/today` or `/app/day/:date`

**Assigns**:
```elixir
%{
  current_user: User.t(),
  selected_date: Date.t(),
  habits_with_progress: [HabitWithProgress.t()],
  completion_summary: %{completed: integer(), total: integer()},
  is_today: boolean(),
  timezone: String.t()
}
```

**Events**:
- `toggle_habit` - Quick complete/uncomplete for binary habits
- `log_value` - Log numeric or duration value
- `swipe_left` - Navigate to next day
- `swipe_right` - Navigate to previous day
- `select_date` - Jump to specific date from calendar picker
- `back_to_today` - Return to current date

**State Transitions**:
1. Mount → Load habits for selected_date → Render
2. User toggles habit → Optimistic UI update → Server persist → Confirm or rollback
3. User swipes → Update selected_date → Reload habits → Render
4. User selects date → Update selected_date → Reload habits → Render

**Mobile Interactions**:
- Touch event listeners for swipe detection (50px threshold)
- Optimistic UI for instant feedback
- Pull-to-refresh for manual sync


#### HabitsLive (Habit Management)

**Route**: `/app/habits`

**Assigns**:
```elixir
%{
  current_user: User.t(),
  habits: [Habit.t()],
  filter: :all | :active | :inactive
}
```

**Events**:
- `new_habit` - Navigate to habit creation
- `edit_habit` - Navigate to habit edit
- `toggle_active` - Activate/deactivate habit
- `reorder` - Drag-and-drop reordering
- `delete_habit` - Soft delete habit

#### HabitFormLive (Create/Edit Habit)

**Routes**: `/app/habits/new`, `/app/habits/:id/edit`

**Assigns**:
```elixir
%{
  current_user: User.t(),
  habit: Habit.t() | %Habit{},
  changeset: Ecto.Changeset.t(),
  mode: :new | :edit
}
```

**Events**:
- `validate` - Real-time form validation
- `save` - Create or update habit
- `cancel` - Return to habits list

**Form Fields**:
- Name (text, required)
- Description (textarea, optional)
- Icon (emoji picker)
- Color (color palette selector)
- Type (radio: binary/numeric/duration)
- Target value (number, conditional on type)
- Unit label (text, conditional on numeric/duration)
- Goal horizon (select: daily/weekly/monthly/yearly)
- Frequency goal (number, conditional on non-daily)
- Occurrence schedule (weekday toggles)

#### SettingsLive

**Route**: `/app/settings`

**Assigns**:
```elixir
%{
  current_user: User.t(),
  user_changeset: Ecto.Changeset.t(),
  reminder_settings: ReminderSettings.t(),
  reminder_changeset: Ecto.Changeset.t(),
  theme: :light | :dark | :system
}
```

**Events**:
- `update_timezone` - Change user timezone
- `update_theme` - Change theme preference
- `update_reminders` - Update reminder settings
- `request_deletion` - Initiate account deletion

#### AdminDashboardLive

**Route**: `/admin`

**Assigns**:
```elixir
%{
  current_admin: Admin.t(),
  metrics: SystemMetrics.t(),
  refresh_interval: integer()
}
```

**Events**:
- `refresh_metrics` - Manual metrics refresh

#### AdminUsersLive

**Route**: `/admin/users`

**Assigns**:
```elixir
%{
  current_admin: Admin.t(),
  users: [User.t()],
  search_query: String.t(),
  page: integer(),
  total_pages: integer()
}
```

**Events**:
- `search` - Search users by email/ID
- `view_user` - Navigate to user detail
- `deactivate_user` - Deactivate account
- `delete_user` - Soft delete account

#### AdminUserDetailLive

**Route**: `/admin/users/:id`

**Assigns**:
```elixir
%{
  current_admin: Admin.t(),
  user: User.t(),
  user_summary: UserSummary.t(),
  impersonation_active: boolean()
}
```

**Events**:
- `force_password_reset` - Trigger password reset
- `impersonate` - View as user (read-only)
- `stop_impersonation` - Exit impersonation mode
- `deactivate` - Deactivate user
- `delete` - Soft delete user


## Data Models

### Database Schema

#### users table

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

#### admins table

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

#### habits table

```sql
CREATE TYPE habit_type AS ENUM ('binary', 'numeric', 'duration');
CREATE TYPE goal_horizon AS ENUM ('daily', 'weekly', 'monthly', 'yearly');

CREATE TABLE habits (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  icon VARCHAR(10) NOT NULL, -- emoji character
  color VARCHAR(7) NOT NULL, -- hex color
  type habit_type NOT NULL,
  target_value DECIMAL(10,2), -- for numeric/duration types
  unit_label VARCHAR(50), -- for numeric/duration types
  goal_horizon goal_horizon NOT NULL DEFAULT 'daily',
  frequency_goal INTEGER, -- X times per week/month/year
  occurrence_schedule JSONB NOT NULL DEFAULT '{"type": "daily"}', -- {type: "daily"} or {type: "weekdays", days: [1,2,3,4,5]}
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

**occurrence_schedule JSONB format**:
```json
// Daily
{"type": "daily"}

// Specific weekdays (1=Monday, 7=Sunday)
{"type": "weekdays", "days": [1, 2, 3, 4, 5]}
```

#### habit_logs table

```sql
CREATE TYPE completion_status AS ENUM ('not_complete', 'planned', 'complete');

CREATE TABLE habit_logs (
  id BIGSERIAL PRIMARY KEY,
  habit_id BIGINT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_date DATE NOT NULL,
  status completion_status NOT NULL DEFAULT 'not_complete',
  numeric_value DECIMAL(10,2), -- for numeric habits
  duration_minutes INTEGER, -- for duration habits
  notes TEXT,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(habit_id, local_date)
);

CREATE INDEX habit_logs_habit_id_idx ON habit_logs(habit_id);
CREATE INDEX habit_logs_user_id_local_date_idx ON habit_logs(user_id, local_date);
CREATE INDEX habit_logs_habit_id_local_date_idx ON habit_logs(habit_id, local_date);
CREATE INDEX habit_logs_inserted_at_idx ON habit_logs(inserted_at); -- for metrics
```


#### reminder_settings table

```sql
CREATE TABLE reminder_settings (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  enabled BOOLEAN NOT NULL DEFAULT false,
  time_of_day TIME NOT NULL DEFAULT '08:00:00',
  habit_selection VARCHAR(20) NOT NULL DEFAULT 'all', -- 'all' or 'selected'
  selected_habit_ids BIGINT[] DEFAULT '{}', -- array of habit IDs when habit_selection = 'selected'
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX reminder_settings_user_id_idx ON reminder_settings(user_id);
CREATE INDEX reminder_settings_enabled_idx ON reminder_settings(enabled) WHERE enabled = true;
```

#### admin_actions table

```sql
CREATE TABLE admin_actions (
  id BIGSERIAL PRIMARY KEY,
  admin_id BIGINT NOT NULL REFERENCES admins(id) ON DELETE CASCADE,
  action VARCHAR(50) NOT NULL, -- 'delete_user', 'deactivate_user', 'force_password_reset'
  target_user_id BIGINT, -- nullable for non-user actions
  metadata JSONB, -- additional context
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX admin_actions_admin_id_idx ON admin_actions(admin_id);
CREATE INDEX admin_actions_target_user_id_idx ON admin_actions(target_user_id);
CREATE INDEX admin_actions_inserted_at_idx ON admin_actions(inserted_at);
```

#### tokens table (for password reset and email confirmation)

```sql
CREATE TABLE tokens (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(255) NOT NULL UNIQUE,
  context VARCHAR(50) NOT NULL, -- 'reset_password', 'confirm_email'
  sent_to VARCHAR(255),
  expires_at TIMESTAMP NOT NULL,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX tokens_user_id_idx ON tokens(user_id);
CREATE INDEX tokens_token_context_idx ON tokens(token, context);
CREATE INDEX tokens_expires_at_idx ON tokens(expires_at);
```

#### daily_metrics table (for admin dashboard)

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

### Ecto Schemas

#### User Schema

```elixir
defmodule HabitTracker.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    field :password, :string, virtual: true, redact: true
    field :confirmed_at, :naive_datetime
    field :timezone, :string, default: "UTC"
    field :theme, :string, default: "system"
    field :deleted_at, :naive_datetime

    has_many :habits, HabitTracker.Tracker.Habit
    has_many :habit_logs, HabitTracker.Tracker.HabitLog
    has_one :reminder_settings, HabitTracker.Reminders.ReminderSettings

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :timezone])
    |> validate_required([:email, :password])
    |> validate_email()
    |> validate_password()
    |> hash_password()
  end

  def timezone_changeset(user, attrs) do
    user
    |> cast(attrs, [:timezone])
    |> validate_required([:timezone])
    |> validate_timezone()
  end

  defp validate_timezone(changeset) do
    validate_change(changeset, :timezone, fn :timezone, tz ->
      if Tzdata.zone_exists?(tz), do: [], else: [timezone: "invalid timezone"]
    end)
  end
end
```


#### Habit Schema

```elixir
defmodule HabitTracker.Tracker.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  @habit_types ~w(binary numeric duration)
  @goal_horizons ~w(daily weekly monthly yearly)

  schema "habits" do
    field :name, :string
    field :description, :string
    field :icon, :string
    field :color, :string
    field :type, :string
    field :target_value, :decimal
    field :unit_label, :string
    field :goal_horizon, :string, default: "daily"
    field :frequency_goal, :integer
    field :occurrence_schedule, :map
    field :position, :integer, default: 0
    field :active, :boolean, default: true
    field :deleted_at, :naive_datetime

    belongs_to :user, HabitTracker.Accounts.User
    has_many :habit_logs, HabitTracker.Tracker.HabitLog

    timestamps()
  end

  def changeset(habit, attrs) do
    habit
    |> cast(attrs, [:name, :description, :icon, :color, :type, :target_value, 
                    :unit_label, :goal_horizon, :frequency_goal, :occurrence_schedule, 
                    :position, :active])
    |> validate_required([:name, :icon, :color, :type, :goal_horizon])
    |> validate_inclusion(:type, @habit_types)
    |> validate_inclusion(:goal_horizon, @goal_horizons)
    |> validate_target_for_type()
    |> validate_frequency_goal()
    |> validate_occurrence_schedule()
  end

  defp validate_target_for_type(changeset) do
    type = get_field(changeset, :type)
    
    case type do
      t when t in ["numeric", "duration"] ->
        validate_required(changeset, [:target_value])
      _ ->
        changeset
    end
  end

  defp validate_frequency_goal(changeset) do
    horizon = get_field(changeset, :goal_horizon)
    
    case horizon do
      "daily" -> changeset
      _ -> validate_required(changeset, [:frequency_goal])
    end
  end

  defp validate_occurrence_schedule(changeset) do
    validate_change(changeset, :occurrence_schedule, fn :occurrence_schedule, schedule ->
      case schedule do
        %{"type" => "daily"} -> []
        %{"type" => "weekdays", "days" => days} when is_list(days) ->
          if Enum.all?(days, &(&1 in 1..7)), do: [], else: [occurrence_schedule: "invalid weekdays"]
        _ -> [occurrence_schedule: "invalid schedule format"]
      end
    end)
  end
end
```

#### HabitLog Schema

```elixir
defmodule HabitTracker.Tracker.HabitLog do
  use Ecto.Schema
  import Ecto.Changeset

  @completion_statuses ~w(not_complete planned complete)

  schema "habit_logs" do
    field :local_date, :date
    field :status, :string, default: "not_complete"
    field :numeric_value, :decimal
    field :duration_minutes, :integer
    field :notes, :string

    belongs_to :habit, HabitTracker.Tracker.Habit
    belongs_to :user, HabitTracker.Accounts.User

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:local_date, :status, :numeric_value, :duration_minutes, :notes])
    |> validate_required([:local_date, :status])
    |> validate_inclusion(:status, @completion_statuses)
    |> unique_constraint([:habit_id, :local_date])
    |> determine_completion_status()
  end

  defp determine_completion_status(changeset) do
    habit = changeset.data.habit || get_assoc(changeset, :habit)
    
    if habit do
      case habit.type do
        "binary" -> changeset
        "numeric" ->
          value = get_field(changeset, :numeric_value)
          target = habit.target_value
          if value && Decimal.compare(value, target) != :lt do
            put_change(changeset, :status, "complete")
          else
            changeset
          end
        "duration" ->
          minutes = get_field(changeset, :duration_minutes)
          target = Decimal.to_integer(habit.target_value)
          if minutes && minutes >= target do
            put_change(changeset, :status, "complete")
          else
            changeset
          end
      end
    else
      changeset
    end
  end
end
```


### Key Queries

#### Today Dashboard Query

```elixir
def today_dashboard(user, local_date) do
  from(h in Habit,
    where: h.user_id == ^user.id,
    where: h.active == true,
    where: is_nil(h.deleted_at),
    left_join: log in HabitLog,
    on: log.habit_id == h.id and log.local_date == ^local_date,
    order_by: h.position,
    preload: [habit_logs: log]
  )
  |> Repo.all()
  |> Enum.filter(&is_scheduled?(&1, local_date, user.timezone))
  |> Enum.map(&enrich_with_progress(&1, local_date, user.timezone))
end

defp is_scheduled?(habit, local_date, timezone) do
  day_of_week = Date.day_of_week(local_date) # 1=Monday, 7=Sunday
  
  case habit.occurrence_schedule do
    %{"type" => "daily"} -> true
    %{"type" => "weekdays", "days" => days} -> day_of_week in days
    _ -> false
  end
end

defp enrich_with_progress(habit, local_date, timezone) do
  log = Enum.find(habit.habit_logs, &(&1.local_date == local_date))
  streak = calculate_streak(habit, local_date, timezone)
  
  %{
    habit: habit,
    log: log,
    streak: streak,
    is_complete: log && log.status == "complete",
    progress: calculate_progress(habit, log)
  }
end
```

#### Streak Calculation Query

```elixir
def calculate_streak(habit, as_of_date, timezone) do
  # Get all logs for this habit up to as_of_date, ordered desc
  logs = from(log in HabitLog,
    where: log.habit_id == ^habit.id,
    where: log.local_date <= ^as_of_date,
    where: log.status == "complete",
    order_by: [desc: log.local_date]
  )
  |> Repo.all()
  
  # Generate scheduled dates going backwards from as_of_date
  scheduled_dates = generate_scheduled_dates_backwards(habit, as_of_date, timezone, 365)
  
  # Count consecutive completions
  Enum.reduce_while(scheduled_dates, 0, fn date, streak ->
    if Enum.any?(logs, &(&1.local_date == date)) do
      {:cont, streak + 1}
    else
      {:halt, streak}
    end
  end)
end

defp generate_scheduled_dates_backwards(habit, start_date, timezone, max_days) do
  0..max_days
  |> Enum.map(&Date.add(start_date, -&1))
  |> Enum.filter(&is_scheduled?(habit, &1, timezone))
end
```

#### Completion Rate Query

```elixir
def completion_rate(habit, period, timezone) do
  {start_date, end_date} = period_to_date_range(period, timezone)
  
  scheduled_dates = generate_scheduled_dates(habit, start_date, end_date, timezone)
  total_scheduled = length(scheduled_dates)
  
  completed = from(log in HabitLog,
    where: log.habit_id == ^habit.id,
    where: log.local_date >= ^start_date,
    where: log.local_date <= ^end_date,
    where: log.status == "complete",
    select: count(log.id)
  )
  |> Repo.one()
  
  if total_scheduled > 0 do
    completed / total_scheduled
  else
    0.0
  end
end
```

#### Admin Metrics Query

```elixir
def calculate_daily_metrics(date) do
  total_users = Repo.aggregate(User, :count, :id, where: is_nil(deleted_at))
  
  new_users_today = from(u in User,
    where: fragment("DATE(?)", u.inserted_at) == ^date,
    select: count(u.id)
  ) |> Repo.one()
  
  # DAU: users who logged habits today
  dau = from(log in HabitLog,
    where: log.local_date == ^date,
    select: count(fragment("DISTINCT ?", log.user_id))
  ) |> Repo.one()
  
  # WAU: users who logged habits in past 7 days
  week_ago = Date.add(date, -7)
  wau = from(log in HabitLog,
    where: log.local_date >= ^week_ago and log.local_date <= ^date,
    select: count(fragment("DISTINCT ?", log.user_id))
  ) |> Repo.one()
  
  # MAU: users who logged habits in past 30 days
  month_ago = Date.add(date, -30)
  mau = from(log in HabitLog,
    where: log.local_date >= ^month_ago and log.local_date <= ^date,
    select: count(fragment("DISTINCT ?", log.user_id))
  ) |> Repo.one()
  
  total_habits = Repo.aggregate(Habit, :count, :id, where: is_nil(deleted_at))
  active_habits = Repo.aggregate(Habit, :count, :id, where: [active: true] and is_nil(deleted_at))
  
  completions_today = from(log in HabitLog,
    where: log.local_date == ^date,
    where: log.status == "complete",
    select: count(log.id)
  ) |> Repo.one()
  
  # Average completion rate across all users
  avg_completion_rate = calculate_system_completion_rate(date)
  
  %{
    metric_date: date,
    total_users: total_users,
    new_users_today: new_users_today,
    dau: dau,
    wau: wau,
    mau: mau,
    total_habits: total_habits,
    active_habits: active_habits,
    completions_today: completions_today,
    avg_completion_rate: avg_completion_rate
  }
end
```


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

The following properties are derived from the requirements and will be validated through property-based testing. Each property uses universal quantification ("for all" or "for any") and references the specific requirements it validates.

### Authentication and Account Management Properties

**Property 1: Valid registration creates account and sends email**
*For any* valid email and password combination, registering a new user should create a user account in the database and enqueue a confirmation email job.
**Validates: Requirements 1.2**

**Property 2: Valid credentials authenticate successfully**
*For any* existing user with valid credentials, authentication should succeed and return the user record.
**Validates: Requirements 1.3**

**Property 3: Password reset request sends email**
*For any* registered email address, requesting a password reset should enqueue a password reset email job.
**Validates: Requirements 1.4**

**Property 4: Timezone changes affect date calculations**
*For any* user and any valid IANA timezone, changing the user's timezone should cause future date calculations to use the new timezone.
**Validates: Requirements 1.9**

### Habit Management Properties

**Property 5: Numeric habits require target value**
*For any* habit creation attempt with type "numeric", the system should reject the creation if no target_value is provided.
**Validates: Requirements 3.3**

**Property 6: Duration values stored as minutes**
*For any* duration habit log, the duration_minutes field should contain the value in minutes regardless of input format.
**Validates: Requirements 3.4**

**Property 7: Habit reordering updates positions**
*For any* user's habit list and any valid reordering, the position field of each habit should reflect the new order.
**Validates: Requirements 3.7**

**Property 8: Editing habits preserves historical logs**
*For any* habit with existing logs, editing the habit's schedule or target should not modify any existing habit_log records.
**Validates: Requirements 3.8**

**Property 9: Inactive habits excluded from dashboard**
*For any* user with inactive habits, the today dashboard should not include inactive habits, but all historical logs for those habits should remain in the database.
**Validates: Requirements 3.10**

**Property 10: Frequency goals must be positive integers**
*For any* habit with a non-daily goal horizon, the system should reject frequency_goal values that are not positive integers.
**Validates: Requirements 3.11**

### Habit Logging Properties

**Property 11: Logs can be created for any date**
*For any* habit and any date (past, present, or future), a user should be able to create a habit_log entry for that date.
**Validates: Requirements 4.1**

**Property 12: Binary habits store status only**
*For any* binary habit log, the numeric_value and duration_minutes fields should be null.
**Validates: Requirements 4.3**

**Property 13: Numeric habits auto-complete at threshold**
*For any* numeric habit log where numeric_value >= target_value, the status should automatically be set to "complete".
**Validates: Requirements 4.4**

**Property 14: Duration habits auto-complete at threshold**
*For any* duration habit log where duration_minutes >= target_value, the status should automatically be set to "complete".
**Validates: Requirements 4.5**

**Property 15: No implicit log creation**
*For any* habit and date, if the user has not explicitly logged (planned/complete/value/notes), no habit_log record should exist in the database.
**Validates: Requirements 4.6**

**Property 16: Missing logs treated as not_complete**
*For any* habit and scheduled date, if no habit_log record exists, the system should treat it as not_complete when calculating statistics.
**Validates: Requirements 4.7**

**Property 17: Logs stored with UTC timestamp and local date**
*For any* habit_log record, the inserted_at timestamp should be in UTC and the local_date should be derived from the user's timezone.
**Validates: Requirements 4.8**

**Property 18: Local date matches user timezone**
*For any* habit_log created at a specific UTC time, the local_date should match the date in the user's configured timezone at that moment.
**Validates: Requirements 4.9**

**Property 19: Log updates preserve creation timestamp**
*For any* habit_log update, the inserted_at timestamp should remain unchanged from the original creation time.
**Validates: Requirements 4.10**

**Property 20: Unique constraint on habit logs**
*For any* habit and date, attempting to create a second habit_log with the same (habit_id, local_date) should be rejected.
**Validates: Requirements 4.12**

### Dashboard and Display Properties

**Property 21: Dashboard shows only active scheduled habits**
*For any* user and date, the today dashboard should display only habits that are active and scheduled for that date.
**Validates: Requirements 5.2**

**Property 22: Habit display includes required fields**
*For any* habit displayed on the today dashboard, the rendered output should include name, icon, color, target, progress, streak, and action button.
**Validates: Requirements 5.3**

**Property 23: Completion summary matches actual completions**
*For any* date, the "X / Y complete" summary should show X as the count of completed habits and Y as the count of scheduled habits.
**Validates: Requirements 5.4**

### Streak Calculation Properties

**Property 24: Streaks count consecutive scheduled completions**
*For any* habit and date, the streak should equal the number of consecutive scheduled occurrences (working backwards from the date) where the habit was completed.
**Validates: Requirements 6.1**

**Property 25: Future dates excluded from streaks**
*For any* habit with future logs marked complete or planned, those future dates should not contribute to the current streak count.
**Validates: Requirements 6.2**

**Property 26: Unscheduled days don't break streaks**
*For any* habit with an occurrence schedule, dates that are not scheduled should not break the streak when calculating consecutive completions.
**Validates: Requirements 6.4**

**Property 27: Weekday habits don't break on weekends**
*For any* habit scheduled for weekdays only, weekend dates should not break the streak count.
**Validates: Requirements 6.5**

**Property 28: Missing scheduled occurrence resets streak**
*For any* habit, if a scheduled occurrence is not completed, the streak should reset to zero.
**Validates: Requirements 6.7**

**Property 29: Streaks calculated in user timezone**
*For any* two users with the same habit completion pattern but different timezones, their streaks should be calculated based on their respective local dates.
**Validates: Requirements 6.8**

### Analytics Properties

**Property 30: Weekly completion rate accuracy**
*For any* habit and week, the completion rate should equal (completed scheduled occurrences in week) / (total scheduled occurrences in week).
**Validates: Requirements 7.1**

**Property 31: Monthly completion rate accuracy**
*For any* habit and month, the completion rate should equal (completed scheduled occurrences in month) / (total scheduled occurrences in month).
**Validates: Requirements 7.2**

**Property 32: Frequency goal progress accuracy**
*For any* habit with a frequency goal, the progress display should show (completions in current period) / (frequency_goal).
**Validates: Requirements 7.3**

**Property 33: Completion rates use scheduled occurrences**
*For any* habit with an occurrence schedule, completion rate calculations should only count scheduled days in the denominator, not all calendar days.
**Validates: Requirements 7.4**

**Property 34: Analytics respect user timezone**
*For any* user, all analytics calculations (weekly, monthly, etc.) should use date boundaries based on the user's configured timezone.
**Validates: Requirements 7.5**

### Email Reminder Properties

**Property 35: Reminder emails scheduled at configured time**
*For any* user with reminders enabled, reminder emails should be scheduled to send at the configured time_of_day in the user's timezone.
**Validates: Requirements 8.4**

**Property 36: Reminder emails include habit information**
*For any* reminder email, the email body should contain the names and status of the user's habits scheduled for that day.
**Validates: Requirements 8.5**

**Property 37: Disabled reminders don't send emails**
*For any* user with reminders disabled, no reminder emails should be sent regardless of habit status.
**Validates: Requirements 8.8**

### Admin Metrics Properties

**Property 38: Total user count accuracy**
*For any* point in time, the total_users metric should equal the count of users where deleted_at is null.
**Validates: Requirements 9.1**

**Property 39: New user registration counts accuracy**
*For any* date, the new_users_today metric should equal the count of users where DATE(inserted_at) equals that date.
**Validates: Requirements 9.2**

**Property 40: DAU calculation accuracy**
*For any* date, DAU should equal the count of distinct users who created or modified a habit_log on that date.
**Validates: Requirements 9.3**

**Property 41: WAU calculation accuracy**
*For any* date, WAU should equal the count of distinct users who created or modified a habit_log in the 7 days ending on that date.
**Validates: Requirements 9.4**

**Property 42: MAU calculation accuracy**
*For any* date, MAU should equal the count of distinct users who created or modified a habit_log in the 30 days ending on that date.
**Validates: Requirements 9.5**

**Property 43: Total habits count accuracy**
*For any* point in time, the total_habits metric should equal the count of habits where deleted_at is null.
**Validates: Requirements 9.6**

**Property 44: Active habits count accuracy**
*For any* point in time, the active_habits metric should equal the count of habits where active = true and deleted_at is null.
**Validates: Requirements 9.7**

**Property 45: Completion events count accuracy**
*For any* date, the completions_today metric should equal the count of habit_logs where local_date equals that date and status = 'complete'.
**Validates: Requirements 9.8**

**Property 46: Average completion rate formula**
*For any* date, the avg_completion_rate should equal (total completed scheduled occurrences) / (total scheduled occurrences) across all users.
**Validates: Requirements 9.9**

### Admin User Management Properties

**Property 47: User search returns matching users**
*For any* search query, the results should include all users whose email or ID contains the query string.
**Validates: Requirements 10.1**

**Property 48: Impersonation prevents modifications**
*For any* admin impersonating a user, attempts to modify user data (create/update/delete habits or logs) should be rejected.
**Validates: Requirements 10.8**

**Property 49: Admin actions logged**
*For any* security-relevant admin action (delete, deactivate, password reset), an entry should be created in the admin_actions table.
**Validates: Requirements 10.10**

### Account Deletion Properties

**Property 50: Account deletion sets timestamp**
*For any* user requesting account deletion, the deleted_at field should be set to the current timestamp immediately.
**Validates: Requirements 12.1**

**Property 51: Deleted accounts cannot log in**
*For any* user with deleted_at set, authentication attempts should fail even with correct credentials.
**Validates: Requirements 12.2**

**Property 52: Purge job scheduled on deletion**
*For any* user account deletion, a background job should be enqueued to purge the account data within 30 days.
**Validates: Requirements 12.3**

**Property 53: Purge removes all user data**
*For any* user purge operation, all associated records (user, habits, habit_logs) should be permanently deleted from the database.
**Validates: Requirements 12.4**

**Property 54: Purge updates analytics**
*For any* user purge operation, the user should be removed from or anonymized in all analytics aggregates.
**Validates: Requirements 12.5**

### Security Properties

**Property 55: Passwords are hashed**
*For any* user account, the hashed_password field should contain a bcrypt or argon2 hash, never plaintext.
**Validates: Requirements 13.3**

**Property 56: User inputs are validated**
*For any* user input field, the system should validate and sanitize the input before processing or storage.
**Validates: Requirements 13.6**

**Property 57: Queries are parameterized**
*For any* database query, user inputs should be passed as parameters, not concatenated into SQL strings.
**Validates: Requirements 13.7**

**Property 58: Security events are logged**
*For any* security-relevant event (failed login, privilege escalation attempt), an entry should be created in the application logs.
**Validates: Requirements 13.8**

### Background Job Properties

**Property 59: Reminder emails enqueued as jobs**
*For any* user with reminders enabled, the daily reminder should be created as an Oban job, not sent synchronously.
**Validates: Requirements 14.2**

**Property 60: Failed jobs retry with backoff**
*For any* failed background job, the system should retry up to 3 times with exponential backoff (1min, 5min, 15min).
**Validates: Requirements 14.3**

**Property 61: Jobs are idempotent**
*For any* background job, executing it multiple times should produce the same result as executing it once.
**Validates: Requirements 14.4**

**Property 62: Job failures are logged**
*For any* background job that fails after all retries, an error entry should be created in the application logs.
**Validates: Requirements 14.6**

### Operational Properties

**Property 63: Structured logging format**
*For any* application event, the log entry should be in structured format (JSON) with consistent fields.
**Validates: Requirements 15.6**


## Error Handling

### Error Categories

**Validation Errors**
- Invalid email format
- Password too short
- Invalid timezone
- Invalid habit type or goal horizon
- Missing required fields
- Invalid date format

**Authentication Errors**
- Invalid credentials
- Expired token
- Account not confirmed
- Account deleted or deactivated
- Rate limit exceeded

**Authorization Errors**
- Insufficient permissions
- Admin attempting to access user features
- User attempting to access admin features
- Impersonation mode restrictions

**Business Logic Errors**
- Duplicate habit log for same date
- Invalid frequency goal for horizon
- Habit not scheduled for date
- Cannot delete habit with logs (soft delete only)

**External Service Errors**
- Email delivery failure (Resend API)
- Database connection failure
- Background job queue failure

### Error Response Format

All API errors return consistent JSON structure:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Invalid input provided",
    "details": {
      "email": ["must be a valid email address"],
      "password": ["must be at least 8 characters"]
    }
  }
}
```

### Error Handling Strategies

**Validation Errors**: Return 422 Unprocessable Entity with field-specific error messages

**Authentication Errors**: Return 401 Unauthorized with generic message (avoid leaking user existence)

**Authorization Errors**: Return 403 Forbidden with minimal details

**Rate Limiting**: Return 429 Too Many Requests with Retry-After header

**External Service Failures**: 
- Email: Log error, enqueue retry job, return success to user (async)
- Database: Return 503 Service Unavailable, trigger alert
- Background jobs: Automatic retry with exponential backoff

**Unexpected Errors**: Return 500 Internal Server Error, log full stack trace, report to error tracking service

### LiveView Error Handling

**Mount Failures**: Redirect to error page or login

**Event Handler Failures**: Display flash message, rollback optimistic updates

**Network Failures**: Show reconnection UI, queue actions for retry

**Validation Failures**: Display inline error messages, preserve form state

## Testing Strategy

### Dual Testing Approach

The application uses both unit tests and property-based tests for comprehensive coverage:

**Unit Tests**: Verify specific examples, edge cases, and error conditions
- Specific user registration scenarios
- Edge cases like timezone boundaries
- Error handling paths
- Integration between components

**Property Tests**: Verify universal properties across all inputs
- Habit logging rules hold for any valid input
- Streak calculations correct for any completion pattern
- Analytics formulas accurate for any date range
- Security properties hold for any user input

Together, unit tests catch concrete bugs while property tests verify general correctness.

### Property-Based Testing Configuration

**Library**: StreamData (Elixir's property-based testing library)

**Test Configuration**:
- Minimum 100 iterations per property test
- Each property test references its design document property
- Tag format: `@tag feature: "habit-tracker", property: 1, property_text: "Valid registration creates account and sends email"`

**Example Property Test**:

```elixir
defmodule HabitTracker.TrackerTest do
  use HabitTracker.DataCase
  use ExUnitProperties

  @tag feature: "habit-tracker", property: 24, property_text: "Streaks count consecutive scheduled completions"
  property "streak counts consecutive scheduled completions" do
    check all user <- user_generator(),
              habit <- habit_generator(user),
              completions <- completion_pattern_generator(),
              max_runs: 100 do
      
      # Create habit logs based on completion pattern
      Enum.each(completions, fn {date, completed} ->
        if completed do
          Tracker.log_habit(habit, date, %{status: "complete"})
        end
      end)
      
      # Calculate expected streak
      expected_streak = calculate_expected_streak(habit, completions)
      
      # Verify system calculation matches
      actual_streak = Tracker.calculate_streak(habit, Date.utc_today())
      assert actual_streak == expected_streak
    end
  end
end
```

### Test Coverage Goals

**Unit Test Coverage**:
- Context functions: 90%+
- LiveView event handlers: 80%+
- Schema changesets: 95%+
- Background jobs: 85%+

**Property Test Coverage**:
- All 63 correctness properties implemented
- Each property maps to specific requirements
- Generators cover full input space

### Testing Environments

**Development**: SQLite or Postgres with test database
**CI/CD**: Postgres matching production version
**Staging**: Full Gigalixir environment with test data

### Test Data Management

**Factories**: Use ExMachina for test data generation

**Generators**: Custom StreamData generators for:
- Valid/invalid emails
- Timezones (all IANA zones)
- Dates (past, present, future)
- Habit configurations
- Completion patterns

**Fixtures**: Minimal use; prefer factories and generators

### Integration Testing

**LiveView Tests**: Test full user flows
- Registration → confirmation → login → create habit → log completion
- Admin login → search user → view as user → deactivate

**Email Tests**: Use Bamboo.TestAdapter to verify email composition and delivery

**Background Job Tests**: Use Oban.Testing to verify job enqueueing and execution

### Performance Testing

**Query Performance**: Verify N+1 queries eliminated
- Dashboard query loads all habits + logs in 2 queries
- Streak calculation completes in < 100ms for 365 days

**Load Testing**: Verify system handles expected load
- 1000 concurrent users
- 10,000 habit logs per day
- Email queue processes 1000 emails/hour

### Security Testing

**Authentication Tests**: Verify all auth flows secure
- Password hashing
- Token expiration
- Session management

**Authorization Tests**: Verify role separation
- Admin cannot access user features
- User cannot access admin features
- Impersonation restrictions enforced

**Input Validation Tests**: Verify all inputs sanitized
- SQL injection attempts blocked
- XSS attempts escaped
- CSRF tokens required


## Background Jobs Architecture

### Oban Configuration

```elixir
# config/config.exs
config :habit_tracker, Oban,
  repo: HabitTracker.Repo,
  queues: [
    default: 10,
    emails: 20,
    metrics: 5,
    cleanup: 2
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}, # Keep jobs for 7 days
    {Oban.Plugins.Cron, crontab: [
      {"0 * * * *", HabitTracker.Jobs.ScheduleReminders}, # Every hour
      {"0 0 * * *", HabitTracker.Jobs.CalculateDailyMetrics}, # Midnight UTC
      {"0 2 * * *", HabitTracker.Jobs.PurgeDeletedAccounts} # 2 AM UTC
    ]}
  ]
```

### Job Definitions

#### ReminderEmailJob

```elixir
defmodule HabitTracker.Jobs.ReminderEmailJob do
  use Oban.Worker,
    queue: :emails,
    max_attempts: 3,
    unique: [period: 3600, keys: [:user_id, :date]]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "date" => date}}) do
    user = Accounts.get_user!(user_id)
    settings = Reminders.get_reminder_settings(user)
    
    if settings.enabled do
      habits = Tracker.today_dashboard(user, Date.from_iso8601!(date))
      email = Reminders.compose_reminder_email(user, habits)
      
      case Reminders.send_email(email) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :ok
    end
  end
end
```

#### ScheduleRemindersJob

```elixir
defmodule HabitTracker.Jobs.ScheduleReminders do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job) do
    # Get all users with reminders enabled
    users_with_reminders = Reminders.list_users_with_reminders_enabled()
    
    # For each user, calculate when to send reminder in their timezone
    Enum.each(users_with_reminders, fn user ->
      settings = Reminders.get_reminder_settings(user)
      send_time = calculate_send_time(settings.time_of_day, user.timezone)
      
      # Schedule reminder job for appropriate time
      %{user_id: user.id, date: Date.utc_today()}
      |> HabitTracker.Jobs.ReminderEmailJob.new(scheduled_at: send_time)
      |> Oban.insert()
    end)
    
    :ok
  end
  
  defp calculate_send_time(time_of_day, timezone) do
    # Convert user's local time to UTC for scheduling
    {:ok, local_datetime} = NaiveDateTime.new(Date.utc_today(), time_of_day)
    DateTime.from_naive!(local_datetime, timezone)
    |> DateTime.shift_zone!("Etc/UTC")
  end
end
```

#### CalculateDailyMetricsJob

```elixir
defmodule HabitTracker.Jobs.CalculateDailyMetrics do
  use Oban.Worker,
    queue: :metrics,
    unique: [period: 86400, keys: [:date]]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"date" => date}}) do
    date = Date.from_iso8601!(date)
    metrics = Admin.calculate_daily_metrics(date)
    
    Admin.store_daily_metrics(metrics)
    :ok
  end
  
  def perform(_job) do
    # Default: calculate for yesterday
    yesterday = Date.add(Date.utc_today(), -1)
    perform(%Oban.Job{args: %{"date" => Date.to_iso8601(yesterday)}})
  end
end
```

#### PurgeDeletedAccountsJob

```elixir
defmodule HabitTracker.Jobs.PurgeDeletedAccounts do
  use Oban.Worker,
    queue: :cleanup,
    max_attempts: 5

  @impl Oban.Worker
  def perform(_job) do
    # Find accounts deleted more than 30 days ago
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)
    
    users_to_purge = Accounts.list_users_for_purge(cutoff_date)
    
    Enum.each(users_to_purge, fn user ->
      Accounts.purge_user_data(user)
    end)
    
    :ok
  end
end
```

### Retry Policies

**Email Jobs**: 3 attempts with exponential backoff
- Attempt 1: Immediate
- Attempt 2: 1 minute later
- Attempt 3: 5 minutes later
- After 3 failures: Log error, alert admin

**Metrics Jobs**: 5 attempts with longer backoff
- Critical for admin dashboard
- Retry up to 5 times over 24 hours

**Cleanup Jobs**: 5 attempts
- Non-critical but important for compliance
- Extended retry window

### Idempotency Guarantees

**Unique Constraints**: Use Oban's unique option to prevent duplicate jobs
- Reminder emails: unique per user per date per hour
- Metrics calculation: unique per date per day
- Account purge: unique per user

**Idempotent Operations**:
- Email sending: Check if already sent before sending
- Metrics calculation: Upsert (insert or update) metrics records
- Account purge: Check if user still exists before purging

## Deployment Specification

### Gigalixir Setup

#### Initial Setup

```bash
# Install Gigalixir CLI
pip3 install gigalixir

# Login
gigalixir login

# Create app
gigalixir create habit-tracker-prod

# Create staging app
gigalixir create habit-tracker-staging
```

#### Database Setup

```bash
# Create Postgres database (production)
gigalixir pg:create --app habit-tracker-prod

# Create Postgres database (staging)
gigalixir pg:create --app habit-tracker-staging

# Get database URL
gigalixir pg --app habit-tracker-prod
```

#### Environment Variables

```bash
# Production
gigalixir config:set --app habit-tracker-prod \
  SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  DATABASE_URL="<from pg:create>" \
  RESEND_API_KEY="<your-resend-key>" \
  PHX_HOST="habit-tracker-prod.gigalixirapp.com" \
  POOL_SIZE="10"

# Staging
gigalixir config:set --app habit-tracker-staging \
  SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  DATABASE_URL="<from pg:create>" \
  RESEND_API_KEY="<your-resend-test-key>" \
  PHX_HOST="habit-tracker-staging.gigalixirapp.com" \
  POOL_SIZE="5"
```

#### Deployment Configuration

**elixir_buildpack.config**:
```
elixir_version=1.15.7
erlang_version=26.1
node_version=20.9.0
```

**phoenix_static_buildpack.config**:
```
node_version=20.9.0
```

**.buildpacks**:
```
https://github.com/gigalixir/gigalixir-buildpack-clean-cache.git
https://github.com/HashNuke/heroku-buildpack-elixir.git
https://github.com/gjaldon/heroku-buildpack-phoenix-static.git
https://github.com/gigalixir/gigalixir-buildpack-mix.git
```

#### Database Migrations

Migrations run automatically on deployment via release command:

**config/releases.exs**:
```elixir
import Config

config :habit_tracker, HabitTracker.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true
```

**rel/commands/migrate.sh**:
```bash
#!/bin/sh
bin/habit_tracker eval "HabitTracker.Release.migrate()"
```

**lib/habit_tracker/release.ex**:
```elixir
defmodule HabitTracker.Release do
  @app :habit_tracker

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
```

#### Deployment Commands

```bash
# Deploy to staging
git push gigalixir-staging main

# Deploy to production
git push gigalixir main

# Run migrations manually (if needed)
gigalixir ps:migrate --app habit-tracker-prod

# View logs
gigalixir logs --app habit-tracker-prod

# Scale dynos
gigalixir ps:scale --replicas=2 --app habit-tracker-prod

# Open app
gigalixir open --app habit-tracker-prod
```

### Custom Domain Setup

```bash
# Add custom domain
gigalixir domains:add habittracker.com --app habit-tracker-prod

# Get DNS target
gigalixir domains --app habit-tracker-prod

# Configure DNS (at your registrar)
# Add CNAME record: habittracker.com -> <gigalixir-dns-target>

# Enable SSL (automatic via Let's Encrypt)
# SSL certificates are automatically provisioned
```

### Health Check Endpoint

**lib/habit_tracker_web/controllers/health_controller.ex**:
```elixir
defmodule HabitTrackerWeb.HealthController do
  use HabitTrackerWeb, :controller

  def index(conn, _params) do
    # Check database connection
    case Ecto.Adapters.SQL.query(HabitTracker.Repo, "SELECT 1", []) do
      {:ok, _} ->
        json(conn, %{status: "healthy", timestamp: DateTime.utc_now()})
      {:error, _} ->
        conn
        |> put_status(503)
        |> json(%{status: "unhealthy", reason: "database_unavailable"})
    end
  end
end
```

### Monitoring and Observability

**Error Tracking**: Integrate Sentry or AppSignal

```elixir
# config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: "production"
  }
```

**Logging**: Structured JSON logging

```elixir
# config/prod.exs
config :logger, :console,
  format: {Jason, :encode!},
  metadata: [:request_id, :user_id, :remote_ip]
```

**Metrics**: Use Telemetry for application metrics

```elixir
# lib/habit_tracker_web/telemetry.ex
defmodule HabitTrackerWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("habit_tracker.repo.query.total_time",
        unit: {:native, :millisecond}
      ),
      summary("habit_tracker.repo.query.decode_time",
        unit: {:native, :millisecond}
      ),
      summary("habit_tracker.repo.query.query_time",
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    []
  end
end
```


## UI/UX Design System

### Design Tokens

**Color Palette**:
```css
/* Light Theme */
--color-primary: #6366f1; /* Indigo */
--color-primary-hover: #4f46e5;
--color-success: #10b981; /* Green */
--color-warning: #f59e0b; /* Amber */
--color-danger: #ef4444; /* Red */
--color-background: #ffffff;
--color-surface: #f9fafb;
--color-text-primary: #111827;
--color-text-secondary: #6b7280;
--color-border: #e5e7eb;

/* Dark Theme */
--color-primary-dark: #818cf8;
--color-primary-hover-dark: #6366f1;
--color-success-dark: #34d399;
--color-warning-dark: #fbbf24;
--color-danger-dark: #f87171;
--color-background-dark: #111827;
--color-surface-dark: #1f2937;
--color-text-primary-dark: #f9fafb;
--color-text-secondary-dark: #9ca3af;
--color-border-dark: #374151;

/* Habit Colors (12 options) */
--habit-red: #ef4444;
--habit-orange: #f97316;
--habit-amber: #f59e0b;
--habit-yellow: #eab308;
--habit-lime: #84cc16;
--habit-green: #10b981;
--habit-teal: #14b8a6;
--habit-cyan: #06b6d4;
--habit-blue: #3b82f6;
--habit-indigo: #6366f1;
--habit-purple: #a855f7;
--habit-pink: #ec4899;
```

**Typography**:
```css
--font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
--font-size-xs: 0.75rem;    /* 12px */
--font-size-sm: 0.875rem;   /* 14px */
--font-size-base: 1rem;     /* 16px */
--font-size-lg: 1.125rem;   /* 18px */
--font-size-xl: 1.25rem;    /* 20px */
--font-size-2xl: 1.5rem;    /* 24px */
--font-size-3xl: 1.875rem;  /* 30px */

--font-weight-normal: 400;
--font-weight-medium: 500;
--font-weight-semibold: 600;
--font-weight-bold: 700;
```

**Spacing**:
```css
--spacing-1: 0.25rem;  /* 4px */
--spacing-2: 0.5rem;   /* 8px */
--spacing-3: 0.75rem;  /* 12px */
--spacing-4: 1rem;     /* 16px */
--spacing-5: 1.25rem;  /* 20px */
--spacing-6: 1.5rem;   /* 24px */
--spacing-8: 2rem;     /* 32px */
--spacing-10: 2.5rem;  /* 40px */
--spacing-12: 3rem;    /* 48px */
```

**Border Radius**:
```css
--radius-sm: 0.25rem;  /* 4px */
--radius-md: 0.5rem;   /* 8px */
--radius-lg: 0.75rem;  /* 12px */
--radius-xl: 1rem;     /* 16px */
--radius-full: 9999px; /* Fully rounded */
```

**Shadows**:
```css
--shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
--shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
--shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1);
--shadow-xl: 0 20px 25px -5px rgb(0 0 0 / 0.1);
```

### Component Library

#### HabitCard Component

```heex
<div class="habit-card" data-habit-id={@habit.id}>
  <div class="habit-card-header">
    <div class="habit-icon" style={"background-color: #{@habit.color}"}>
      <%= @habit.icon %>
    </div>
    <div class="habit-info">
      <h3 class="habit-name"><%= @habit.name %></h3>
      <div class="habit-streak">
        🔥 <%= @streak %> day streak
      </div>
    </div>
  </div>
  
  <div class="habit-progress">
    <%= if @habit.type == "binary" do %>
      <button
        phx-click="toggle_habit"
        phx-value-habit-id={@habit.id}
        class={"habit-toggle #{if @is_complete, do: "complete", else: ""}"}
      >
        <%= if @is_complete, do: "✓", else: "○" %>
      </button>
    <% else %>
      <div class="habit-value-input">
        <input
          type="number"
          value={@current_value}
          phx-blur="log_value"
          phx-value-habit-id={@habit.id}
          placeholder="0"
        />
        <span class="habit-unit"><%= @habit.unit_label %></span>
        <span class="habit-target">/ <%= @habit.target_value %></span>
      </div>
      <div class="progress-bar">
        <div
          class="progress-fill"
          style={"width: #{min(@progress_percent, 100)}%"}
        ></div>
      </div>
    <% end %>
  </div>
</div>
```

**Styles**:
```css
.habit-card {
  @apply bg-white dark:bg-gray-800 rounded-lg shadow-md p-4 mb-4;
  @apply border border-gray-200 dark:border-gray-700;
  @apply transition-all duration-200;
}

.habit-card:hover {
  @apply shadow-lg;
}

.habit-card-header {
  @apply flex items-center gap-3 mb-3;
}

.habit-icon {
  @apply w-12 h-12 rounded-full flex items-center justify-center text-2xl;
}

.habit-name {
  @apply text-lg font-semibold text-gray-900 dark:text-gray-100;
}

.habit-streak {
  @apply text-sm text-gray-600 dark:text-gray-400;
}

.habit-toggle {
  @apply w-16 h-16 rounded-full border-4 border-gray-300 dark:border-gray-600;
  @apply flex items-center justify-center text-3xl;
  @apply transition-all duration-200;
  @apply hover:scale-110 active:scale-95;
}

.habit-toggle.complete {
  @apply border-green-500 bg-green-50 dark:bg-green-900/20 text-green-600;
}

.progress-bar {
  @apply w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden;
}

.progress-fill {
  @apply h-full bg-gradient-to-r from-indigo-500 to-purple-500;
  @apply transition-all duration-300;
}
```

#### CompletionSummary Component

```heex
<div class="completion-summary">
  <div class="summary-content">
    <span class="summary-count">
      <%= @completed %> / <%= @total %>
    </span>
    <span class="summary-label">complete</span>
  </div>
  
  <%= if @completed == @total and @total > 0 do %>
    <div class="celebration" phx-hook="Confetti">
      🎉 All done!
    </div>
  <% end %>
  
  <div class="progress-ring">
    <svg width="80" height="80">
      <circle
        cx="40"
        cy="40"
        r="36"
        stroke="currentColor"
        stroke-width="8"
        fill="none"
        class="text-gray-200 dark:text-gray-700"
      />
      <circle
        cx="40"
        cy="40"
        r="36"
        stroke="currentColor"
        stroke-width="8"
        fill="none"
        class="text-indigo-500"
        stroke-dasharray={circumference()}
        stroke-dashoffset={circumference() * (1 - @completed / @total)}
        transform="rotate(-90 40 40)"
      />
    </svg>
  </div>
</div>
```

#### DateNavigator Component

```heex
<div class="date-navigator" phx-hook="SwipeDetector">
  <button
    phx-click="prev_day"
    class="nav-button"
    aria-label="Previous day"
  >
    ←
  </button>
  
  <button
    phx-click="open_calendar"
    class="date-display"
  >
    <%= format_date(@selected_date, @timezone) %>
  </button>
  
  <button
    phx-click="next_day"
    class="nav-button"
    aria-label="Next day"
  >
    →
  </button>
  
  <%= if !@is_today do %>
    <button
      phx-click="back_to_today"
      class="today-button"
    >
      Today
    </button>
  <% end %>
</div>
```

### Mobile Interactions

#### Swipe Gesture Detection

**JavaScript Hook**:
```javascript
// assets/js/hooks/swipe_detector.js
export const SwipeDetector = {
  mounted() {
    let touchStartX = 0;
    let touchEndX = 0;
    const threshold = 50; // pixels

    this.el.addEventListener('touchstart', (e) => {
      touchStartX = e.changedTouches[0].screenX;
    });

    this.el.addEventListener('touchend', (e) => {
      touchEndX = e.changedTouches[0].screenX;
      this.handleSwipe(touchStartX, touchEndX, threshold);
    });
  },

  handleSwipe(startX, endX, threshold) {
    const diff = startX - endX;

    if (Math.abs(diff) > threshold) {
      if (diff > 0) {
        // Swipe left - next day
        this.pushEvent('swipe_left', {});
      } else {
        // Swipe right - previous day
        this.pushEvent('swipe_right', {});
      }
    }
  }
};
```

#### Confetti Animation

**JavaScript Hook**:
```javascript
// assets/js/hooks/confetti.js
import confetti from 'canvas-confetti';

export const Confetti = {
  mounted() {
    this.triggerConfetti();
  },

  triggerConfetti() {
    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 },
      colors: ['#6366f1', '#a855f7', '#ec4899', '#10b981']
    });
  }
};
```

### iOS Safari Considerations

**Safe Area Padding**:
```css
/* Respect iOS safe areas */
.app-container {
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
  padding-left: env(safe-area-inset-left);
  padding-right: env(safe-area-inset-right);
}
```

**Touch Target Sizing**:
```css
/* Minimum 44x44px touch targets */
.touch-target {
  min-width: 44px;
  min-height: 44px;
  @apply flex items-center justify-center;
}
```

**Momentum Scrolling**:
```css
.scrollable {
  -webkit-overflow-scrolling: touch;
  overflow-y: auto;
}
```

**Prevent Zoom on Input Focus**:
```html
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
```

```css
/* Ensure inputs are at least 16px to prevent zoom */
input, select, textarea {
  font-size: 16px;
}
```

### Accessibility

**ARIA Labels**:
- All interactive elements have aria-label or aria-labelledby
- Form inputs have associated labels
- Buttons have descriptive text or aria-label

**Keyboard Navigation**:
- All interactive elements accessible via Tab
- Modal dialogs trap focus
- Escape key closes modals

**Color Contrast**:
- All text meets WCAG AA standards (4.5:1 for normal text)
- Interactive elements have sufficient contrast
- Focus indicators visible on all focusable elements

**Screen Reader Support**:
- Semantic HTML elements (nav, main, article, etc.)
- Live regions for dynamic content updates
- Skip navigation links

### Animation Guidelines

**Subtle Animations**:
- Transitions: 200-300ms for most interactions
- Easing: ease-in-out for natural feel
- Respect prefers-reduced-motion

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

**Loading States**:
- Skeleton screens for initial load
- Spinners for actions in progress
- Optimistic UI updates with rollback on error

## Route Map and Information Architecture

### Public Routes

| Route | LiveView | Purpose |
|-------|----------|---------|
| `/` | `PageLive` | Landing page with product overview |
| `/privacy` | `PrivacyLive` | Privacy policy |
| `/terms` | `TermsLive` | Terms of service |

### Authentication Routes

| Route | LiveView | Purpose |
|-------|----------|---------|
| `/signup` | `RegistrationLive` | User registration |
| `/login` | `SessionLive` | User login |
| `/logout` | - | Session termination (controller action) |
| `/reset-password` | `ResetPasswordLive` | Password reset request |
| `/reset-password/:token` | `ResetPasswordLive` | Password reset form |
| `/confirm/:token` | - | Email confirmation (controller action) |

### User Application Routes

| Route | LiveView | Purpose |
|-------|----------|---------|
| `/app` | - | Redirect to `/app/today` |
| `/app/today` | `TodayLive` | Today dashboard (default view) |
| `/app/day/:date` | `TodayLive` | Dashboard for specific date |
| `/app/habits` | `HabitsLive` | Habit list and management |
| `/app/habits/new` | `HabitFormLive` | Create new habit |
| `/app/habits/:id/edit` | `HabitFormLive` | Edit existing habit |
| `/app/settings` | `SettingsLive` | User settings |

### Admin Routes

| Route | LiveView | Purpose |
|-------|----------|---------|
| `/admin` | `AdminDashboardLive` | Admin dashboard with metrics |
| `/admin/users` | `AdminUsersLive` | User search and management |
| `/admin/users/:id` | `AdminUserDetailLive` | User detail and actions |

### API Routes (if needed)

| Route | Controller | Purpose |
|-------|------------|---------|
| `/health` | `HealthController` | Health check endpoint |
| `/api/webhooks/resend` | `WebhookController` | Resend webhook handler |

## Security Checklist

### Authentication Security
- [x] Passwords hashed with bcrypt (cost factor 12)
- [x] Session tokens cryptographically secure
- [x] Session expiration after 30 days inactivity
- [x] Password reset tokens expire after 1 hour
- [x] Email confirmation tokens expire after 7 days
- [x] Rate limiting on login (10 attempts per 15 min)
- [x] Rate limiting on registration (5 attempts per hour)
- [x] Rate limiting on password reset (3 attempts per hour)

### Authorization Security
- [x] Role-based access control (User vs Admin)
- [x] Admin cannot access user habit features
- [x] User cannot access admin features
- [x] Impersonation mode is read-only
- [x] All context functions check user ownership
- [x] LiveView mounts verify authentication

### Input Validation
- [x] All user inputs validated with Ecto changesets
- [x] Email format validation
- [x] Timezone validation against IANA database
- [x] Date validation (valid ISO8601 format)
- [x] Numeric values validated for type and range
- [x] SQL injection prevented via Ecto parameterized queries
- [x] XSS prevented via Phoenix HTML escaping

### CSRF Protection
- [x] CSRF tokens required for all state-changing operations
- [x] Phoenix.Controller.protect_from_forgery enabled
- [x] LiveView CSRF protection enabled

### Session Security
- [x] httpOnly flag on session cookies
- [x] secure flag on session cookies (HTTPS only)
- [x] SameSite=Lax on session cookies
- [x] Session signing with secret key base

### Data Privacy
- [x] Soft delete with 30-day purge for GDPR compliance
- [x] User data anonymized in analytics after purge
- [x] No PII in logs
- [x] Secure environment variable storage

### API Security
- [x] Resend API key stored in environment variables
- [x] Database credentials in environment variables
- [x] No secrets in version control
- [x] Health endpoint does not leak sensitive info

### Deployment Security
- [x] HTTPS enforced (Gigalixir automatic SSL)
- [x] Database connections use SSL
- [x] Secrets managed via Gigalixir config vars
- [x] Error messages don't leak stack traces in production

## Roadmap

### v1.0 - Core Features (MVP)
**Timeline**: 8-10 weeks

**Features**:
- User authentication and account management
- Habit creation with all types and schedules
- Habit logging for past/present/future
- Today dashboard with swipe navigation
- Streak calculation
- Basic analytics (weekly/monthly completion rates)
- Email reminders
- Admin dashboard with metrics
- Admin user management
- Light/dark themes
- Mobile-responsive design

**Infrastructure**:
- Gigalixir deployment
- Postgres database
- Resend email integration
- Oban background jobs
- Error tracking
- Health monitoring

### v1.1 - Enhanced Analytics
**Timeline**: 4-6 weeks after v1.0

**Features**:
- Habit history charts (completion over time)
- Longest streak tracking
- Completion heatmap calendar view
- Weekly/monthly summary emails
- Habit insights and suggestions
- Achievement badges
- Habit templates (common habits pre-configured)

**Improvements**:
- Performance optimizations
- Enhanced mobile gestures
- Improved admin analytics

### v1.2 - Social and Sharing
**Timeline**: 6-8 weeks after v1.1

**Features**:
- Share habit progress (optional)
- Public habit profiles
- Habit challenges
- Friend accountability (optional)
- Export data (CSV, JSON)
- Import from other habit trackers

**Infrastructure**:
- CDN for static assets
- Image uploads for custom habit icons
- S3 or similar for file storage

### v2.0 - Advanced Features
**Timeline**: 3-4 months after v1.2

**Features**:
- Advanced scheduling (RRULE support)
- Habit dependencies (do X before Y)
- Custom reminder templates
- SMS reminders (via Twilio)
- Push notifications (web push)
- Habit notes and journaling
- Tags and categories
- Advanced filtering and search
- API for third-party integrations

**Infrastructure**:
- Multi-region deployment
- Redis for caching and rate limiting
- Elasticsearch for advanced search
- GraphQL API

### Future Considerations
- Native mobile apps (iOS/Android)
- Team/organization features
- Habit coaching and AI suggestions
- Integration with fitness trackers
- Gamification elements
- Premium tier with advanced features

