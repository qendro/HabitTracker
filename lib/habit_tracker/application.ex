defmodule HabitTracker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Completely skip Oban in production to save database connections
    # Free tier only has 2 connections total
    children = [
      HabitTrackerWeb.Telemetry,
      HabitTracker.Repo,
      {DNSCluster, query: Application.get_env(:habit_tracker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HabitTracker.PubSub},
      HabitTrackerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HabitTracker.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    maybe_bootstrap_admin()

    {:ok, pid}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HabitTrackerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_bootstrap_admin do
    email = System.get_env("ADMIN_BOOTSTRAP_EMAIL")
    password = System.get_env("ADMIN_BOOTSTRAP_PASSWORD")

    if email && password do
      case HabitTracker.Admin.get_admin_by_email(email) do
        nil ->
          case HabitTracker.Admin.register_admin(%{email: email, password: password}) do
            {:ok, _admin} ->
              Logger.info("Bootstrap admin created", email: email)

            {:error, changeset} ->
              Logger.error("Bootstrap admin creation failed",
                email: email,
                errors: inspect(changeset.errors)
              )
          end

        _admin ->
          Logger.info("Bootstrap admin already exists", email: email)
      end
    end
  end
end
