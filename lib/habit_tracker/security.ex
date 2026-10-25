defmodule HabitTracker.Security do
  @moduledoc "Log only event names and numeric user IDs. Forwarded client IPs require a trusted proxy configuration."
  require Logger

  def log_event(event, metadata \\ %{}) do
    Logger.info("Authentication event", event: event, user_id: metadata[:user_id])
  end

  def get_client_ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
end
