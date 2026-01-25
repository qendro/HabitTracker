import Config

# This file is loaded when running releases in production.
# It is executed after compilation and before the system starts.
# For compile-time configuration, see config/prod.exs

# Configure Oban for background jobs with minimal queue sizes for free tier
config :habit_tracker, Oban,
  repo: HabitTracker.Repo,
  queues: [
    default: 1,
    emails: 1,
    metrics: 1,
    cleanup: 1
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", HabitTracker.Workers.ScheduleRemindersJob},
       {"0 0 * * *", HabitTracker.Workers.CalculateDailyMetricsJob},
       {"0 2 * * *", HabitTracker.Workers.PurgeDeletedAccountsJob}
     ]}
  ]
