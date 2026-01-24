# Requirements Document: Habit Tracker Web Application

## Introduction

This document specifies the requirements for a single-tenant habit tracker web application built with Elixir Phoenix + LiveView. The system enables users to create habits, log completions across past/present/future days, and track progress through an intuitive dashboard. The application includes user authentication, email reminders via Resend, and a separate admin area for system oversight.

## Glossary

- **System**: The habit tracker web application
- **User**: A registered account holder who tracks personal habits
- **Admin**: A privileged account type with system oversight capabilities but no personal habit data
- **Habit**: A user-defined activity to be tracked over time
- **Habit_Log**: A record of habit completion status for a specific date
- **Local_Date**: A calendar date in the user's configured timezone
- **Streak**: Consecutive scheduled occurrences where a habit was completed
- **Goal_Horizon**: The time period over which habit performance is measured (daily/weekly/monthly/yearly)
- **Frequency_Goal**: Target number of completions within a goal horizon (e.g., 3 times per week)
- **Schedule_Rule**: Constraints defining when a habit is active (e.g., weekdays only)
- **Reminder_Service**: Email notification system using Resend API
- **Today_Dashboard**: Primary user interface showing habits scheduled for the current day

## Requirements

### Requirement 1: User Authentication and Account Management

**User Story:** As a user, I want to create an account and securely log in, so that I can access my personal habit tracking data.

#### Acceptance Criteria

1. THE System SHALL provide email/password registration for new users
2. WHEN a user submits valid registration credentials, THE System SHALL create a new user account and send a confirmation email
3. WHEN a user submits valid login credentials, THE System SHALL authenticate the user and establish a secure session
4. WHEN a user requests password reset, THE System SHALL send a password reset email via Reminder_Service
5. THE System SHALL rate-limit registration attempts to prevent abuse (maximum 5 attempts per IP per hour)
6. THE System SHALL rate-limit login attempts to prevent brute force attacks (maximum 10 attempts per IP per 15 minutes)
7. WHEN a user's session is established, THE System SHALL store session data securely with httpOnly cookies
8. THE System SHALL auto-detect user timezone from browser on registration
9. WHERE a user modifies their timezone setting, THE System SHALL update all future date calculations accordingly

### Requirement 2: Admin Account Management

**User Story:** As a system administrator, I want a separate admin account type with oversight capabilities, so that I can manage the platform without mixing personal habit data.

#### Acceptance Criteria

1. THE System SHALL maintain separate account types for User and Admin roles
2. THE System SHALL prevent admin accounts from accessing habit tracking features
3. THE System SHALL prevent privilege escalation from User to Admin role through application interfaces
4. WHEN an admin account is created, THE System SHALL require secure initialization (via seed script or authenticated admin-only flow)
5. THE System SHALL prevent public signup flows from creating admin accounts

### Requirement 3: Habit Definition and Configuration

**User Story:** As a user, I want to create and configure habits with various tracking types and schedules, so that I can track different kinds of activities.

#### Acceptance Criteria

1. THE System SHALL support creating habits with name, description, icon, color, type, and position attributes
2. THE System SHALL support three habit types: binary (done/not done), numeric (with unit and target), and duration (minutes)
3. WHEN a user creates a numeric habit, THE System SHALL require a target value and optional unit label
4. WHEN a user creates a duration habit, THE System SHALL store duration values as minutes internally
5. THE System SHALL support goal horizons: daily, weekly (X times per week), monthly (X times per month), and yearly (X times per year)
6. THE System SHALL support occurrence schedules: daily OR specific weekdays (Monday through Sunday toggles)
7. THE System SHALL allow users to reorder habits via drag-and-drop on Today_Dashboard
8. WHEN a user edits a habit's schedule or target, THE System SHALL preserve all historical Habit_Log records unchanged
9. THE System SHALL allow users to mark habits as active or inactive
10. WHILE a habit is inactive, THE System SHALL exclude it from Today_Dashboard but retain all historical data
11. THE System SHALL validate that frequency goals are positive integers appropriate for the goal horizon

### Requirement 4: Habit Logging and Completion Tracking

**User Story:** As a user, I want to log habit completions for past, present, and future days, so that I can maintain accurate records and plan ahead.

#### Acceptance Criteria

1. THE System SHALL allow users to create Habit_Log entries for any Local_Date (past, present, or future)
2. THE System SHALL support three completion states: not_complete, planned, and complete
3. WHEN a user logs a binary habit, THE System SHALL record the completion state only
4. WHEN a user logs a numeric habit, THE System SHALL record the numeric value and mark complete when value >= target
5. WHEN a user logs a duration habit, THE System SHALL record duration in minutes and mark complete when duration >= target
6. THE System SHALL store Habit_Log records only when user explicitly logs planned, complete, or adds value/notes
7. WHEN no Habit_Log record exists for a scheduled date, THE System SHALL treat it as implicit not_complete
8. THE System SHALL store all Habit_Log records with UTC timestamp and derived Local_Date
9. THE System SHALL calculate Local_Date using the user's configured timezone
10. WHEN a user modifies an existing Habit_Log, THE System SHALL update the record while preserving the original creation timestamp
11. THE System SHALL allow users to add optional notes to any Habit_Log entry
12. THE System SHALL enforce unique constraint on (user_id, habit_id, local_date) for Habit_Log records

### Requirement 5: Today Dashboard and Day Navigation

**User Story:** As a user, I want a dashboard showing today's habits with easy navigation between days, so that I can quickly log completions and review progress.

#### Acceptance Criteria

1. WHEN a user logs in, THE System SHALL display the Today_Dashboard as the default view
2. THE Today_Dashboard SHALL display all active habits scheduled for the selected Local_Date
3. WHEN displaying a habit on Today_Dashboard, THE System SHALL show name, icon, color, target, progress, streak, and quick action button
4. THE System SHALL display a summary showing "X / Y complete" for the selected day
5. WHEN all scheduled habits are complete for a day, THE System SHALL display a celebration animation
6. THE System SHALL support swipe gestures on mobile devices to navigate between adjacent days
7. THE System SHALL provide a calendar day picker to jump to any Local_Date
8. THE System SHALL provide a "Back to Today" button when viewing non-current dates
9. THE System SHALL display the selected Local_Date prominently on Today_Dashboard
10. WHEN a user navigates to a future date, THE System SHALL display habits with planned and complete states visually distinct from not_complete

### Requirement 6: Streak Calculation

**User Story:** As a user, I want to see streak counts for my habits, so that I can stay motivated by tracking consecutive completions.

#### Acceptance Criteria

1. THE System SHALL calculate streak as consecutive scheduled occurrences where the habit was completed
2. WHEN calculating streaks, THE System SHALL only count past and current day completions
3. WHEN calculating streaks, THE System SHALL exclude future dates with planned or complete status
4. WHEN calculating streaks for habits with occurrence schedules, THE System SHALL only count scheduled days
5. WHEN a habit is scheduled for weekdays only, THE System SHALL not break the streak on weekends
6. THE System SHALL display current streak count for each habit on Today_Dashboard
7. WHEN a scheduled occurrence is not completed, THE System SHALL reset the streak to zero
8. THE System SHALL calculate streaks in the user's configured timezone

### Requirement 7: Analytics and Progress Tracking

**User Story:** As a user, I want to view completion statistics and goal progress, so that I can understand my habit performance over time.

#### Acceptance Criteria

1. THE System SHALL calculate and display "this week" completion rate for each habit
2. THE System SHALL calculate and display "this month" completion rate for each habit
3. WHEN a habit has a frequency goal, THE System SHALL display progress toward that goal for the current period
4. THE System SHALL calculate completion rates based on scheduled occurrences, not calendar days
5. THE System SHALL compute all analytics in the user's configured timezone

### Requirement 8: Email Reminders

**User Story:** As a user, I want to receive email reminders for my habits, so that I can stay on track with my goals.

#### Acceptance Criteria

1. THE System SHALL allow users to enable or disable email reminders
2. WHEN reminders are enabled, THE System SHALL allow users to configure time of day for reminder delivery
3. THE System SHALL allow users to select which habits receive reminders (all active or specific subset)
4. THE System SHALL send reminder emails via Reminder_Service at the configured time in the user's timezone
5. THE System SHALL include relevant habit information in reminder emails
6. THE System SHALL send account confirmation emails via Reminder_Service
7. THE System SHALL send password reset emails via Reminder_Service
8. THE System SHALL respect user opt-out preferences for all reminder emails

### Requirement 9: Admin Dashboard and Metrics

**User Story:** As an admin, I want to view system-wide metrics and user statistics, so that I can monitor platform health and growth.

#### Acceptance Criteria

1. THE System SHALL display total user count on admin dashboard
2. THE System SHALL display new user registrations (daily and weekly) on admin dashboard
3. THE System SHALL calculate DAU (Daily Active Users) as users who created or modified a Habit_Log on that day
4. THE System SHALL calculate WAU (Weekly Active Users) as users who created or modified a Habit_Log in the past 7 days
5. THE System SHALL calculate MAU (Monthly Active Users) as users who created or modified a Habit_Log in the past 30 days
6. THE System SHALL display total habits created across all users
7. THE System SHALL display count of currently active habits
8. THE System SHALL display completion events per day
9. THE System SHALL calculate average completion rate as completed scheduled occurrences divided by total scheduled occurrences
10. THE System SHALL provide basic retention and cohort metrics
11. THE System SHALL calculate daily metric rollups at midnight UTC

### Requirement 10: Admin User Management

**User Story:** As an admin, I want to manage user accounts and handle abuse cases, so that I can maintain platform integrity.

#### Acceptance Criteria

1. THE System SHALL provide admin search functionality to find users by email or ID
2. WHEN an admin views a user profile, THE System SHALL display read-only summary information
3. THE System SHALL allow admins to deactivate user accounts
4. THE System SHALL allow admins to reactivate previously deactivated accounts
5. WHEN an admin deletes a user account, THE System SHALL soft-delete the account immediately
6. THE System SHALL allow admins to trigger password reset flow for any user
7. THE System SHALL provide "View as User" functionality allowing admins to see a user's dashboard in read-only mode
8. WHEN using "View as User", THE System SHALL prevent admins from modifying user data
9. THE System SHALL allow admins to apply rate limits or account locks for abuse prevention
10. THE System SHALL log security-relevant admin actions (account deletion, deactivation, password reset) to admin_actions table

### Requirement 11: Responsive Design and Mobile Support

**User Story:** As a user, I want the application to work seamlessly on desktop and mobile devices, so that I can track habits anywhere.

#### Acceptance Criteria

1. THE System SHALL render all interfaces responsively for desktop and mobile viewports
2. THE System SHALL support iOS Safari with appropriate safe-area padding
3. THE System SHALL provide touch targets of at least 44x44 pixels on mobile devices
4. THE System SHALL support momentum scrolling on mobile devices
5. THE System SHALL implement swipe gestures for day navigation on touch devices
6. THE System SHALL support both light and dark color themes
7. WHEN a user's device is in dark mode, THE System SHALL default to dark theme
8. THE System SHALL allow users to manually override theme preference

### Requirement 12: Data Retention and Account Deletion

**User Story:** As a user, I want my data to be permanently deleted when I close my account, so that I can exercise my data privacy rights.

#### Acceptance Criteria

1. WHEN a user requests account deletion, THE System SHALL soft-delete the account immediately by setting deleted_at timestamp
2. THE System SHALL prevent soft-deleted accounts from logging in or being restored
3. THE System SHALL schedule a background job to permanently purge soft-deleted account data within 30 days
4. WHEN purging an account, THE System SHALL remove all personal data including user record, habits, and Habit_Log entries
5. THE System SHALL anonymize or remove user data from analytics aggregates during purge
6. THE System SHALL send confirmation email when account deletion is initiated

### Requirement 13: Security and Rate Limiting

**User Story:** As a system operator, I want comprehensive security controls and rate limiting, so that the platform is protected from abuse and attacks.

#### Acceptance Criteria

1. THE System SHALL enforce HTTPS for all connections
2. THE System SHALL use httpOnly and secure flags for session cookies
3. THE System SHALL hash all passwords using bcrypt or argon2
4. THE System SHALL rate-limit password reset requests to 3 per email per hour
5. THE System SHALL implement CSRF protection for all state-changing operations
6. THE System SHALL validate and sanitize all user inputs
7. THE System SHALL prevent SQL injection through parameterized queries
8. THE System SHALL log security-relevant events (failed logins, privilege escalation attempts)
9. WHERE the System runs on multiple nodes, THE System SHALL use Postgres-backed or Redis-backed rate limiting
10. WHERE the System runs on a single node, THE System SHALL use ETS-backed rate limiting with Hammer library

### Requirement 14: Background Job Processing

**User Story:** As a system operator, I want reliable background job processing for emails and metrics, so that the system can handle asynchronous tasks efficiently.

#### Acceptance Criteria

1. THE System SHALL use a job queue system (Oban) for background task processing
2. THE System SHALL schedule reminder emails as background jobs
3. THE System SHALL implement retry policies for failed email delivery (3 retries with exponential backoff)
4. THE System SHALL ensure idempotency for all background jobs
5. WHERE daily metric rollups are implemented, THE System SHALL schedule them as background jobs
6. THE System SHALL log job failures for monitoring and debugging

### Requirement 15: Deployment and Operations

**User Story:** As a system operator, I want clear deployment procedures and operational monitoring, so that I can maintain a reliable production environment.

#### Acceptance Criteria

1. THE System SHALL deploy to Gigalixir platform
2. THE System SHALL use Postgres database for data persistence
3. THE System SHALL store sensitive configuration in environment variables
4. THE System SHALL run database migrations automatically on deployment
5. THE System SHALL provide a health check endpoint at /health
6. THE System SHALL implement structured logging for all application events
7. THE System SHALL integrate with error tracking services
8. THE System SHALL support separate staging and production environments

## Default Decisions

The following design decisions were made where requirements were unspecified:

1. **Email Confirmation**: Email confirmation is required for new user registrations
2. **Password Requirements**: Minimum 8 characters, no complexity requirements (following modern NIST guidelines)
3. **Session Duration**: Sessions expire after 30 days of inactivity
4. **Streak Definition**: Streaks count consecutive scheduled occurrences for past/today only; future dates excluded
5. **Timezone Storage**: User timezone stored as IANA timezone identifier (e.g., "America/New_York")
6. **Habit Icon**: Icons stored as emoji characters (single Unicode character)
7. **Color Palette**: Predefined set of 12 colors for habit selection
8. **Reminder Email Time**: Default reminder time is 8:00 AM in user's timezone
9. **Admin Audit Log**: Security-relevant admin actions (delete, deactivate, password reset) logged to admin_actions table
10. **Job Retry Policy**: Failed jobs retry 3 times with exponential backoff (1min, 5min, 15min)
11. **Metric Calculation**: Metrics calculated daily at midnight UTC (system timezone for rollups)
12. **Account Deletion**: Soft delete immediately with deleted_at timestamp; permanent purge within 30 days; restore disabled
13. **Rate Limit Storage**: ETS-backed for single node (Hammer library); Postgres or Redis-backed for multi-node
14. **Celebration Animation**: Confetti animation using lightweight CSS/JS library
15. **Mobile Swipe Threshold**: 50px horizontal swipe to trigger day navigation
16. **Custom Patterns**: For v1, "custom patterns" means weekday toggles only (Monday-Sunday); advanced RRULE patterns deferred to v2
17. **Habit Log Storage**: Store rows only when user explicitly logs (planned/complete/value/notes); no row = implicit not_complete
18. **Active User Definition**: User is active if they created or modified a Habit_Log (not just login)
19. **Habit Ordering**: Habits have position field for drag-and-drop reordering on Today_Dashboard
20. **Soft Delete Fields**: Users, habits, and habit_logs include deleted_at timestamp for soft delete support
