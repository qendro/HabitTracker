# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :habit_tracker, :scopes,
  user: [
    default: true,
    module: HabitTracker.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: HabitTracker.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :habit_tracker,
  ecto_repos: [HabitTracker.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :habit_tracker, HabitTrackerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HabitTrackerWeb.ErrorHTML, json: HabitTrackerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HabitTracker.PubSub,
  live_view: [signing_salt: "FOnPILM8"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  habit_tracker: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure bcrypt with cost factor 12 for security
config :bcrypt_elixir, log_rounds: 12

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000, cleanup_interval_ms: 60_000]}

config :habit_tracker, Oban,
  repo: HabitTracker.Repo,
  queues: [media: 1],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 86400},
    {Oban.Plugins.Cron, crontab: [{"*/15 * * * *", HabitTracker.Media.Reconcile}]}
  ]

config :habit_tracker, :media_root, Path.expand("../tmp/media", __DIR__)
config :habit_tracker, :max_photo_bytes, 25 * 1024 * 1024
config :habit_tracker, :max_photo_pixels, 60_000_000
config :phoenix, :filter_parameters, {:keep, []}
config :habit_tracker, HabitTracker.Repo, log: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
