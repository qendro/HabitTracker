# Implementation Plan: Habit Tracker Web Application

## Overview

This implementation plan breaks down the habit tracker application into discrete, incremental tasks. Each task builds on previous work and includes testing to validate functionality early. The plan follows a bottom-up approach: database → contexts → LiveViews → background jobs → deployment.

## Tasks

- [x] 1. Project setup and database foundation
  - Create new Phoenix 1.7+ project with LiveView
  - Configure Postgres database connection
  - Set up Ecto with timezone support (tzdata)
  - Create initial database migration for users table with timezone and soft delete fields
  - Configure phx.gen.auth for authentication foundation
  - Set up Tailwind CSS with custom configuration
  - Configure test environment with test database
  - _Requirements: 15.2, 15.3_

- [x] 2. User authentication and account management
  - [x] 2.1 Implement user registration with email confirmation
    - Generate user registration LiveView with email/password fields
    - Add timezone auto-detection from browser on registration
    - Implement email confirmation token generation and validation
    - Create confirmation email template
    - _Requirements: 1.1, 1.2, 1.8_

  - [x]* 2.2 Write property test for user registration
    - **Property 1: Valid registration creates account and sends email**
    - **Validates: Requirements 1.2**

  - [x] 2.3 Implement login and session management
    - Create login LiveView with email/password fields
    - Implement secure session storage with httpOnly cookies
    - Add session expiration (30 days inactivity)
    - _Requirements: 1.3, 1.7_

  - [x]* 2.4 Write property test for authentication
    - **Property 2: Valid credentials authenticate successfully**
    - **Validates: Requirements 1.3**

  - [x] 2.5 Implement password reset flow
    - Create password reset request LiveView
    - Generate password reset tokens with 1-hour expiration
    - Create password reset email template
    - Implement password reset form with token validation
    - _Requirements: 1.4_

  - [x]* 2.6 Write property test for password reset
    - **Property 3: Password reset request sends email**
    - **Validates: Requirements 1.4**

  - [x] 2.7 Implement rate limiting for auth endpoints
    - Install and configure Hammer library for rate limiting
    - Add rate limiting to registration (5 per IP per hour)
    - Add rate limiting to login (10 per IP per 15 min)
    - Add rate limiting to password reset (3 per email per hour)
    - _Requirements: 1.5, 1.6, 13.4, 13.9, 13.10_

  - [x]* 2.8 Write unit tests for rate limiting
    - Test registration rate limit enforcement
    - Test login rate limit enforcement
    - Test password reset rate limit enforcement
    - _Requirements: 1.5, 1.6, 13.4_

- [x] 3. Checkpoint - Verify authentication system
  - Ensure all tests pass, ask the user if questions arise.


- [x] 4. Admin account system
  - [x] 4.1 Create admin schema and authentication
    - Create admins table migration (separate from users)
    - Generate Admin schema with email/password
    - Implement admin authentication (separate from user auth)
    - Create admin login page at /admin/login
    - Add admin session management
    - _Requirements: 2.1, 2.4_

  - [x]* 4.2 Write unit tests for admin authentication
    - Test admin login succeeds with valid credentials
    - Test admin cannot access user routes
    - Test user cannot access admin routes
    - _Requirements: 2.2, 2.3_

  - [x] 4.3 Implement admin authorization guards
    - Create plug to verify admin role
    - Add authorization checks to admin LiveViews
    - Prevent privilege escalation from user to admin
    - _Requirements: 2.3, 2.5_

  - [x]* 4.4 Write unit tests for authorization
    - Test privilege escalation prevention
    - Test admin route protection
    - _Requirements: 2.3, 2.5_

- [x] 5. Habit data model and core context
  - [x] 5.1 Create habits table and schema
    - Create habits migration with all fields (name, description, icon, color, type, target_value, unit_label, goal_horizon, frequency_goal, occurrence_schedule, position, active, deleted_at)
    - Define habit_type enum (binary, numeric, duration)
    - Define goal_horizon enum (daily, weekly, monthly, yearly)
    - Create Habit schema with validations
    - Add indexes for user_id, active, position
    - _Requirements: 3.1, 3.2, 3.5, 3.6_

  - [x]* 5.2 Write property test for habit validation
    - **Property 5: Numeric habits require target value**
    - **Validates: Requirements 3.3**

  - [x]* 5.3 Write property test for frequency goal validation
    - **Property 10: Frequency goals must be positive integers**
    - **Validates: Requirements 3.11**

  - [x] 5.4 Create habit_logs table and schema
    - Create habit_logs migration with fields (habit_id, user_id, local_date, status, numeric_value, duration_minutes, notes)
    - Define completion_status enum (not_complete, planned, complete)
    - Create HabitLog schema with validations
    - Add unique constraint on (habit_id, local_date)
    - Add indexes for habit_id, user_id, local_date
    - _Requirements: 4.1, 4.2, 4.12_

  - [x]* 5.5 Write property test for habit log uniqueness
    - **Property 20: Unique constraint on habit logs**
    - **Validates: Requirements 4.12**

  - [x] 5.6 Implement Tracker context core functions
    - Implement create_habit/2
    - Implement update_habit/2
    - Implement delete_habit/1 (soft delete)
    - Implement list_active_habits/1
    - Implement reorder_habits/2
    - _Requirements: 3.7, 3.8, 3.9_

  - [x]* 5.7 Write property test for habit editing
    - **Property 8: Editing habits preserves historical logs**
    - **Validates: Requirements 3.8**

  - [x]* 5.8 Write property test for habit reordering
    - **Property 7: Habit reordering updates positions**
    - **Validates: Requirements 3.7**

- [x] 6. Habit logging functionality
  - [x] 6.1 Implement habit log creation and updates with sparse storage
    - Implement log_habit/3 with timezone-aware date handling
    - Only create habit_log records when user explicitly logs (planned/complete/value/notes)
    - Do NOT create not_complete records automatically
    - Implement update_habit_log/2
    - Implement get_logs_for_date/2
    - Add logic to auto-complete numeric/duration habits when value >= target
    - Allow binary habits to be explicitly set to planned or complete
    - Allow numeric/duration habits to be set to planned without value
    - Define validation matrix for allowed status/value combinations by habit type
    - Store UTC timestamps with derived local_date
    - _Requirements: 4.1, 4.3, 4.4, 4.5, 4.6, 4.8, 4.9_

  - [x]* 6.2 Write property test for numeric habit auto-completion
    - **Property 13: Numeric habits auto-complete at threshold**
    - **Validates: Requirements 4.4**

  - [x]* 6.3 Write property test for duration habit auto-completion
    - **Property 14: Duration habits auto-complete at threshold**
    - **Validates: Requirements 4.5**

  - [x]* 6.4 Write property test for sparse storage
    - **Property 15: No implicit log creation**
    - Test that no logs created without explicit user action
    - **Validates: Requirements 4.6**

  - [x]* 6.5 Write property test for missing logs
    - **Property 16: Missing logs treated as not_complete**
    - **Validates: Requirements 4.7**

  - [x]* 6.6 Write property test for timezone handling
    - **Property 18: Local date matches user timezone**
    - **Validates: Requirements 4.9**

  - [x]* 6.7 Write property test for log updates
    - **Property 19: Log updates preserve creation timestamp**
    - **Validates: Requirements 4.10**

  - [x]* 6.8 Write unit tests for habit log validation matrix
    - Test binary habit can be planned without value
    - Test binary habit can be complete without value
    - Test numeric habit can be planned without value
    - Test numeric habit auto-completes when value >= target
    - Test duration habit can be planned without value
    - Test duration habit auto-completes when duration >= target
    - _Requirements: 4.3, 4.4, 4.5_

  - [x] 6.9 Implement occurrence schedule logic
    - Implement is_scheduled?/2 to check if habit is scheduled for a date
    - Implement scheduled_dates/2 to generate scheduled dates for a range
    - Handle daily and weekday schedules
    - _Requirements: 3.6_

  - [x]* 6.10 Write property test for schedule logic
    - **Property 26: Unscheduled days don't break streaks**
    - **Validates: Requirements 6.4**

- [x] 7. Streak calculation
  - [x] 7.1 Implement streak calculation algorithm with future date exclusion
    - Implement calculate_streak/2 with timezone support
    - Use min(as_of_date, today_in_user_tz) as upper bound for streak calculation
    - Count consecutive scheduled occurrences backwards from effective date
    - Only count completed logs with local_date <= effective_as_of_date
    - Exclude future dates from streak calculation (even if marked complete or planned)
    - Handle weekday-only habits correctly
    - _Requirements: 6.1, 6.2, 6.4, 6.5, 6.8_

  - [x]* 7.2 Write property test for streak calculation
    - **Property 24: Streaks count consecutive scheduled completions**
    - **Validates: Requirements 6.1**

  - [x]* 7.3 Write property test for future date exclusion
    - **Property 25: Future dates excluded from streaks**
    - Test that future completions don't inflate streak
    - Test that future planned logs don't inflate streak
    - **Validates: Requirements 6.2**

  - [x]* 7.4 Write property test for weekday streaks
    - **Property 27: Weekday habits don't break on weekends**
    - **Validates: Requirements 6.5**

  - [x]* 7.5 Write property test for streak reset
    - **Property 28: Missing scheduled occurrence resets streak**
    - **Validates: Requirements 6.7**

  - [x]* 7.6 Write unit tests for future date handling
    - Test creating future completion doesn't change current streak
    - Test creating future planned doesn't change current streak
    - Test viewing future date shows streak "as of today"
    - _Requirements: 6.2_

- [x] 8. Checkpoint - Verify core habit tracking
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Analytics and progress tracking
  - [x] 9.1 Implement completion rate calculations
    - Implement completion_rate/3 for weekly/monthly periods
    - Calculate based on scheduled occurrences, not calendar days
    - Handle timezone-aware date boundaries
    - _Requirements: 7.1, 7.2, 7.4, 7.5_

  - [ ]* 9.2 Write property test for weekly completion rate
    - **Property 30: Weekly completion rate accuracy**
    - **Validates: Requirements 7.1**

  - [ ]* 9.3 Write property test for monthly completion rate
    - **Property 31: Monthly completion rate accuracy**
    - **Validates: Requirements 7.2**

  - [ ]* 9.4 Write property test for completion rate formula
    - **Property 33: Completion rates use scheduled occurrences**
    - **Validates: Requirements 7.4**

  - [x] 9.5 Implement frequency goal progress
    - Implement frequency_progress/2 to calculate progress toward frequency goals
    - Count completions in current period (week/month/year)
    - _Requirements: 7.3_

  - [ ]* 9.6 Write property test for frequency progress
    - **Property 32: Frequency goal progress accuracy**
    - **Validates: Requirements 7.3**

- [ ] 10. Today dashboard LiveView
  - [x] 10.1 Create TodayLive with sparse storage query
    - Generate TodayLive at /app/today and /app/day/:date
    - Implement mount with authentication check
    - Load habits for selected date with today_dashboard/2 query
    - Query uses LEFT JOIN on habit_logs (missing log = implicit not_complete)
    - Do NOT create not_complete records in database
    - Calculate completion summary from query results
    - Render habit cards with progress
    - Display streak badge with label "as of today" when viewing future dates
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ]* 10.2 Write property test for dashboard filtering
    - **Property 21: Dashboard shows only active scheduled habits**
    - **Validates: Requirements 5.2**

  - [ ]* 10.3 Write property test for completion summary
    - **Property 23: Completion summary matches actual completions**
    - **Validates: Requirements 5.4**

  - [x] 10.4 Implement habit logging interactions with readonly mode check
    - Add toggle_habit event for binary habits
    - Add log_value event for numeric/duration habits
    - Check readonly_mode flag before allowing mutations
    - Return error if in readonly mode (admin impersonation)
    - Implement optimistic UI updates
    - Handle rollback on error
    - _Requirements: 4.1, 10.8_

  - [ ]* 10.5 Write unit tests for logging interactions
    - Test binary habit toggle
    - Test numeric value logging
    - Test duration logging
    - _Requirements: 4.1_

  - [x] 10.6 Implement day navigation
    - Add prev_day and next_day events
    - Add select_date event for calendar picker
    - Add back_to_today event
    - Update selected_date assign and reload habits
    - _Requirements: 5.6, 5.7, 5.8_

  - [ ]* 10.7 Write unit tests for navigation
    - Test day navigation updates date
    - Test back to today button
    - _Requirements: 5.6, 5.8_

  - [x] 10.8 Add swipe gesture support
    - Create SwipeDetector JavaScript hook
    - Handle swipe_left and swipe_right events
    - Set 50px swipe threshold
    - _Requirements: 5.6, 11.5_

  - [ ]* 10.9 Write unit tests for swipe gestures
    - Test swipe left navigates to next day
    - Test swipe right navigates to previous day
    - _Requirements: 5.6_

  - [x] 10.10 Add celebration animation
    - Create Confetti JavaScript hook using canvas-confetti
    - Trigger when all habits complete
    - _Requirements: 5.5_

- [ ] 11. Habit management LiveViews
  - [x] 11.1 Create HabitsLive for habit list
    - Generate HabitsLive at /app/habits
    - Display all user habits (active and inactive)
    - Add filter for active/inactive/all
    - Implement toggle_active event
    - Implement delete_habit event (soft delete)
    - _Requirements: 3.9_

  - [ ]* 11.2 Write property test for inactive habit filtering
    - **Property 9: Inactive habits excluded from dashboard**
    - **Validates: Requirements 3.10**

  - [x] 11.3 Create HabitFormLive for create/edit
    - Generate HabitFormLive at /app/habits/new and /app/habits/:id/edit
    - Build form with all habit fields
    - Add emoji picker for icon selection
    - Add color palette selector (12 colors)
    - Add weekday toggles for occurrence schedule
    - Implement real-time validation
    - Handle create and update modes
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [ ]* 11.4 Write unit tests for habit form
    - Test habit creation with all types
    - Test validation errors
    - Test weekday schedule configuration
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 11.5 Implement drag-and-drop reordering
    - Add SortableJS integration for habit reordering
    - Handle reorder event
    - Update habit positions in database
    - _Requirements: 3.7_

- [x] 12. User settings LiveView
  - [x] 12.1 Create SettingsLive
    - Generate SettingsLive at /app/settings
    - Add timezone selector with IANA timezone list
    - Add theme selector (light/dark/system)
    - Add account deletion button
    - _Requirements: 1.9, 11.6, 11.7, 11.8_

  - [ ]* 12.2 Write property test for timezone changes
    - **Property 4: Timezone changes affect date calculations**
    - **Validates: Requirements 1.9**

  - [x] 12.3 Implement account deletion flow
    - Add confirmation modal for account deletion
    - Implement soft delete (set deleted_at timestamp)
    - Prevent login for deleted accounts
    - Send confirmation email
    - _Requirements: 12.1, 12.2, 12.6_

  - [ ]* 12.4 Write property test for account deletion
    - **Property 50: Account deletion sets timestamp**
    - **Validates: Requirements 12.1**

  - [ ]* 12.5 Write property test for deleted account login
    - **Property 51: Deleted accounts cannot log in**
    - **Validates: Requirements 12.2**

- [ ] 13. Checkpoint - Verify user-facing features
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Email reminder system
  - [x] 14.1 Set up Resend integration
    - Add resend_ex dependency
    - Configure Resend API key from environment
    - Create email templates module
    - Implement compose_reminder_email/2
    - Implement compose_confirmation_email/2
    - Implement compose_password_reset_email/2
    - _Requirements: 8.5, 8.6, 8.7_

  - [ ]* 14.2 Write property test for reminder email content
    - **Property 36: Reminder emails include habit information**
    - **Validates: Requirements 8.5**

  - [x] 14.3 Create reminder_settings table and schema
    - Create reminder_settings migration (user_id, enabled, time_of_day, habit_selection, selected_habit_ids)
    - Create ReminderSettings schema
    - Add unique constraint on user_id
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 14.4 Add reminder settings to SettingsLive
    - Add reminder enable/disable toggle
    - Add time of day picker
    - Add habit selection (all or specific)
    - Add habit multi-select when "specific" selected
    - _Requirements: 8.1, 8.2, 8.3_

  - [ ]* 14.5 Write unit tests for reminder settings
    - Test enabling/disabling reminders
    - Test time of day configuration
    - Test habit selection
    - _Requirements: 8.1, 8.2, 8.3_

- [x] 15. Background job system with Oban
  - [x] 15.1 Set up Oban
    - Add oban dependency
    - Configure Oban with queues (default, emails, metrics, cleanup)
    - Add Oban to supervision tree
    - Configure Oban pruner plugin
    - _Requirements: 14.1_

  - [x] 15.2 Create ReminderEmailJob
    - Implement ReminderEmailJob worker
    - Add retry policy (3 attempts, exponential backoff)
    - Add unique constraint (per user per date per hour)
    - Implement perform/1 to send reminder email
    - _Requirements: 14.2, 14.3_

  - [ ]* 15.3 Write property test for reminder job enqueueing
    - **Property 59: Reminder emails enqueued as jobs**
    - **Validates: Requirements 14.2**

  - [ ]* 15.4 Write property test for job retry policy
    - **Property 60: Failed jobs retry with backoff**
    - **Validates: Requirements 14.3**

  - [ ]* 15.5 Write property test for job idempotency
    - **Property 61: Jobs are idempotent**
    - **Validates: Requirements 14.4**

  - [x] 15.6 Create ScheduleRemindersJob with correct timezone handling
    - Implement ScheduleRemindersJob cron worker
    - Run hourly to schedule reminder emails
    - For each user with reminders enabled:
      - Compute user's current local date from their timezone
      - Compute next send time from local date + time_of_day
      - Convert send time to UTC for job scheduling
      - Set reminder "for date" as user's local date at send time
    - Enqueue ReminderEmailJob for each user with correct date
    - _Requirements: 8.4_

  - [ ]* 15.7 Write property test for reminder scheduling
    - **Property 35: Reminder emails scheduled at configured time**
    - **Validates: Requirements 8.4**

  - [ ]* 15.8 Write unit tests for timezone-aware reminder scheduling
    - Test user in timezone behind UTC gets correct date
    - Test user in timezone ahead of UTC gets correct date
    - Test send time correctly converted to UTC
    - _Requirements: 8.4_

  - [ ]* 15.9 Write property test for disabled reminders
    - **Property 37: Disabled reminders don't send emails**
    - **Validates: Requirements 8.8**

  - [x] 15.10 Create CalculateDailyMetricsJob (start with live queries)
    - Implement CalculateDailyMetricsJob cron worker
    - Run daily at midnight UTC
    - Calculate all admin metrics using live queries (no rollup table initially)
    - Store in daily_metrics table for historical tracking
    - Note: Start with live queries; optimize with rollups later if needed
    - _Requirements: 9.11, 14.5_

  - [x] 15.11 Create PurgeDeletedAccountsJob
    - Implement PurgeDeletedAccountsJob cron worker
    - Run daily at 2 AM UTC
    - Find accounts deleted > 30 days ago
    - Permanently delete user, habits, and logs
    - Anonymize in analytics
    - _Requirements: 12.3, 12.4, 12.5_

  - [ ]* 15.12 Write property test for account purge
    - **Property 53: Purge removes all user data**
    - **Validates: Requirements 12.4**

- [x] 16. Admin dashboard and metrics
  - [x] 16.1 Create daily_metrics table
    - Create daily_metrics migration (metric_date, total_users, new_users_today, dau, wau, mau, total_habits, active_habits, completions_today, avg_completion_rate)
    - Add unique constraint on metric_date
    - Add index on metric_date DESC
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9_

  - [x] 16.2 Implement Admin context metrics functions
    - Implement calculate_daily_metrics/1
    - Implement store_daily_metrics/1
    - Implement system_metrics/0 to fetch latest metrics
    - Calculate DAU/WAU/MAU based on habit log activity
    - Calculate average completion rate
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9_

  - [ ]* 16.3 Write property tests for metrics calculations
    - **Property 38: Total user count accuracy**
    - **Property 40: DAU calculation accuracy**
    - **Property 41: WAU calculation accuracy**
    - **Property 42: MAU calculation accuracy**
    - **Property 43: Total habits count accuracy**
    - **Property 44: Active habits count accuracy**
    - **Property 45: Completion events count accuracy**
    - **Property 46: Average completion rate formula**
    - **Validates: Requirements 9.1, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9**

  - [x] 16.4 Create AdminDashboardLive
    - Generate AdminDashboardLive at /admin
    - Display all system metrics
    - Add auto-refresh every 60 seconds
    - Add manual refresh button
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9_

  - [ ]* 16.5 Write unit tests for admin dashboard
    - Test metrics display
    - Test auto-refresh
    - _Requirements: 9.1_

- [x] 17. Admin user management
  - [x] 17.1 Create admin_actions table with proper schema
    - Create admin_actions migration (admin_id, action, target_user_id, success, metadata)
    - Define action enum or validated strings: deactivate_user, reactivate_user, delete_user_requested, force_password_reset, view_as_started, view_as_ended
    - Add indexes for admin_id, target_user_id, inserted_at, action
    - Add success boolean field to track failures
    - _Requirements: 10.10_

  - [x] 17.2 Implement Admin context user management functions with audit logging
    - Implement search_users/1
    - Implement get_user_summary/1
    - Create transactional wrapper for admin actions that logs to admin_actions
    - Implement deactivate_user/2 (admin, user) with audit logging
    - Implement reactivate_user/2 (admin, user) with audit logging
    - Implement admin_delete_user/2 (admin, user) with audit logging
    - Implement force_password_reset/2 (admin, user) with audit logging
    - Log both successful and failed admin actions with error metadata
    - Scrub sensitive data from metadata (no passwords, tokens, full request bodies)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.10_

  - [ ]* 17.3 Write property test for user search
    - **Property 47: User search returns matching users**
    - **Validates: Requirements 10.1**

  - [ ]* 17.4 Write property test for admin action logging
    - **Property 49: Admin actions logged**
    - **Validates: Requirements 10.10**

  - [x] 17.5 Create AdminUsersLive
    - Generate AdminUsersLive at /admin/users
    - Add search input with live search
    - Display paginated user list
    - Add links to user detail pages
    - _Requirements: 10.1_

  - [ ]* 17.6 Write unit tests for user search
    - Test search by email
    - Test search by ID
    - _Requirements: 10.1_

  - [x] 17.7 Create AdminUserDetailLive
    - Generate AdminUserDetailLive at /admin/users/:id
    - Display user summary (email, created_at, habit count, log count)
    - Add deactivate/reactivate button
    - Add delete button with confirmation
    - Add force password reset button
    - Add "View as User" button
    - _Requirements: 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 17.8 Create AdminActivityLive for audit log viewing
    - Generate AdminActivityLive at /admin/activity
    - Display recent admin actions with pagination
    - Add filters by action type, date range, and target user
    - Show action, admin email, target user email, timestamp, success status
    - Display error metadata for failed actions
    - _Requirements: 10.10_

  - [x] 17.9 Implement "View as User" impersonation with server-side enforcement
    - Add impersonate_user/2 function that logs view_as_started action
    - Store impersonation state in session with readonly_mode flag
    - Redirect to user's today dashboard in read-only mode
    - Add readonly_mode check to all Tracker context mutation functions
    - Block create_habit, update_habit, delete_habit, log_habit in readonly mode
    - Allow only read operations (list_habits, get_logs, calculate_streak, etc.)
    - Add "Stop Impersonation" button that logs view_as_ended action
    - Clear readonly_mode flag on stop impersonation
    - _Requirements: 10.7, 10.8_

  - [ ]* 17.10 Write property test for impersonation restrictions
    - **Property 48: Impersonation prevents modifications**
    - **Validates: Requirements 10.8**

  - [ ]* 17.11 Write unit tests for impersonation enforcement
    - Test readonly_mode blocks habit creation
    - Test readonly_mode blocks habit updates
    - Test readonly_mode blocks habit logging
    - Test readonly_mode allows read operations
    - Test view_as_started and view_as_ended logged
    - _Requirements: 10.8_

- [ ] 18. Checkpoint - Verify admin features
  - Ensure all tests pass, ask the user if questions arise.

- [x] 19. UI/UX polish and theming
  - [x] 19.1 Implement design system
    - Create Tailwind config with custom colors and design tokens
    - Define light and dark theme CSS variables
    - Create reusable component modules (HabitCard, CompletionSummary, DateNavigator)
    - Add theme toggle to SettingsLive
    - Implement theme persistence in user preferences
    - _Requirements: 11.6, 11.7, 11.8_

  - [ ]* 19.2 Write unit tests for theme switching
    - Test theme toggle updates preference
    - Test theme persists across sessions
    - _Requirements: 11.8_

  - [x] 19.3 Optimize for mobile and iOS Safari
    - Add safe-area-inset CSS for iOS
    - Ensure all touch targets are 44x44px minimum
    - Add momentum scrolling CSS
    - Prevent zoom on input focus (16px font size minimum)
    - Test on iOS Safari
    - _Requirements: 11.2, 11.3, 11.4_

  - [ ]* 19.4 Write property test for touch target sizing
    - **Property: Touch targets meet minimum size**
    - **Validates: Requirements 11.3**

  - [x] 19.5 Add accessibility features
    - Add ARIA labels to all interactive elements
    - Ensure keyboard navigation works
    - Add focus indicators
    - Test with screen reader
    - Add skip navigation links
    - _Requirements: Not explicitly required but best practice_

- [-] 20. Security hardening
  - [x] 20.1 Implement security measures
    - Verify password hashing with bcrypt (cost 12)
    - Add CSRF protection to all forms
    - Implement input validation and sanitization
    - Verify SQL injection prevention via Ecto
    - Add security event logging
    - _Requirements: 13.1, 13.2, 13.3, 13.5, 13.6, 13.7, 13.8_

  - [ ]* 20.2 Write property tests for security
    - **Property 55: Passwords are hashed**
    - **Property 56: User inputs are validated**
    - **Property 57: Queries are parameterized**
    - **Property 58: Security events are logged**
    - **Validates: Requirements 13.3, 13.6, 13.7, 13.8**

  - [ ]* 20.3 Write unit tests for security features
    - Test CSRF protection
    - Test session cookie flags
    - Test input sanitization
    - _Requirements: 13.2, 13.5, 13.6_

- [x] 21. Deployment preparation
  - [x] 21.1 Configure production environment
    - Create elixir_buildpack.config
    - Create phoenix_static_buildpack.config
    - Create .buildpacks file
    - Configure releases.exs for production
    - Create migrate.sh release command
    - Create Release module with migrate/0 function
    - _Requirements: 15.4_

  - [x] 21.2 Set up error tracking and logging
    - Add Sentry or AppSignal integration
    - Configure structured JSON logging
    - Add Telemetry metrics
    - Create health check endpoint at /health
    - _Requirements: 15.5, 15.6, 15.7_

  - [ ]* 21.3 Write property test for structured logging
    - **Property 63: Structured logging format**
    - **Validates: Requirements 15.6**

  - [ ]* 21.4 Write unit test for health endpoint
    - Test /health returns 200 when database connected
    - Test /health returns 503 when database unavailable
    - _Requirements: 15.5_

  - [x] 21.5 Create deployment documentation
    - Document Gigalixir setup steps
    - Document environment variable configuration
    - Document database setup
    - Document custom domain setup
    - Document monitoring setup
    - _Requirements: 15.1, 15.3_

- [x] 22. Deploy to staging
  - Create Gigalixir staging app
  - Configure staging environment variables
  - Deploy to staging
  - Run smoke tests on staging
  - _Requirements: 15.1, 15.8_

- [x] 23. Deploy to production
  - Create Gigalixir production app
  - Configure production environment variables
  - Deploy to production
  - Verify health endpoint
  - Test critical user flows
  - _Requirements: 15.1, 15.8_

- [ ] 24. Final checkpoint - Production verification
  - Ensure all tests pass, ask the user if questions arise.
  - Verify all features working in production
  - Monitor error rates and performance
  - Confirm email delivery working

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties (minimum 100 iterations each)
- Unit tests validate specific examples and edge cases
- All property tests must include tag: `@tag feature: "habit-tracker", property: N, property_text: "..."`
- Background jobs use Oban with retry policies and idempotency guarantees
- Security is built in from the start, not added later
- Deployment is automated via Gigalixir with automatic migrations
