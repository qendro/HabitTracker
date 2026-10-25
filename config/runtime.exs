import Config

if System.get_env("PHX_SERVER") in ["true", "1"],
  do: config(:habit_tracker, HabitTrackerWeb.Endpoint, server: true)

config :habit_tracker, HabitTrackerWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  required = fn key ->
    value = System.fetch_env!(key)
    if value == "" or String.starts_with?(value, "CHANGE_"), do: raise("Configure #{key}")
    value
  end

  host = required.("PHX_HOST")
  secret = required.("SECRET_KEY_BASE")
  if byte_size(secret) < 64, do: raise("SECRET_KEY_BASE must be at least 64 bytes")

  config :habit_tracker, HabitTracker.Repo,
    url: required.("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "5")),
    log: false

  config :habit_tracker, :media_root, required.("MEDIA_ROOT")

  config :habit_tracker,
         :max_photo_bytes,
         String.to_integer(System.get_env("MAX_PHOTO_BYTES", "26214400"))

  config :habit_tracker,
         :max_photo_pixels,
         String.to_integer(System.get_env("MAX_PHOTO_PIXELS", "60000000"))

  config :habit_tracker, HabitTrackerWeb.Endpoint,
    url: [host: host, scheme: "https", port: 443],
    check_origin: ["https://#{host}"],
    http: [ip: {0, 0, 0, 0}],
    secret_key_base: secret
end
