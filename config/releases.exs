import Config

# This file is loaded when running releases in production.
# It is executed after compilation and before the system starts.
# For compile-time configuration, see config/prod.exs

# Configure Oban for background jobs with MINIMAL queue sizes for free tier
# Free tier PostgreSQL only allows 2 total connections!
# We use 1 for web requests and 1 shared across all Oban queues
config :habit_tracker, Oban,
  repo: HabitTracker.Repo,
  queues: false,  # Disable queues in production on free tier
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
    # Cron disabled on free tier due to connection limits
  ]
