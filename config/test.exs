import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :habit_tracker, HabitTracker.Repo,
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASSWORD") || "postgres",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  database:
    System.get_env("DATABASE_NAME") ||
      "habit_tracker_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("DATABASE_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :habit_tracker, HabitTrackerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BNI36nRwkaSBUeLOx2LDsqs9990j+sjqSEULtpgD9E7alQlF0gV8o5eSfwnylRXn",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :habit_tracker, :rate_limiting, false

# Configure Oban for testing (disable queues and plugins)
config :habit_tracker, Oban, testing: :manual, queues: false, plugins: false

config :habit_tracker, :media_root, Path.expand("../tmp/test-media", __DIR__)
