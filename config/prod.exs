import Config

config :habit_tracker, HabitTrackerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  force_ssl: [rewrite_on: [:x_forwarded_proto], exclude: [paths: ["/health"]]]

config :logger, level: :info
