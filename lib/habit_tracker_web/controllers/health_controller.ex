defmodule HabitTrackerWeb.HealthController do
  use HabitTrackerWeb, :controller

  @moduledoc """
  Health check endpoint for monitoring and load balancers.

  Returns 200 OK when the application is healthy and can connect to the database.
  Returns 503 Service Unavailable when the application is unhealthy.
  """

  @doc """
  Health check endpoint.

  Checks:
  - Database connectivity
  - Application is running

  Returns JSON with status and optional error details.
  """
  def check(conn, _params) do
    case check_health() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "healthy",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          version: Application.spec(:habit_tracker, :vsn) |> to_string()
        })

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          reason: reason,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  defp check_health do
    with :ok <- check_database() do
      :ok
    else
      {:error, _} = error -> error
    end
  end

  defp check_database do
    try do
      # Simple query to check database connectivity
      case Ecto.Adapters.SQL.query(HabitTracker.Repo, "SELECT 1", []) do
        {:ok, _} -> :ok
        {:error, _error} -> {:error, "Database unavailable"}
      end
    rescue
      _error -> {:error, "Database unavailable"}
    end
  end
end
