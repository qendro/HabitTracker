defmodule HabitTracker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Get Oban config to check if we should start it
    oban_config = Application.get_env(:habit_tracker, Oban, [])
    
    # Base children that always start
    base_children = [
      HabitTrackerWeb.Telemetry,
      HabitTracker.Repo,
      {DNSCluster, query: Application.get_env(:habit_tracker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HabitTracker.PubSub}
    ]
    
    # Only add Oban if not in testing mode (free tier uses testing: :manual to disable)
    children = if oban_config[:testing] == :manual do
      base_children
    else
      base_children ++ [{Oban, oban_config}]
    end
    
    # Always add endpoint last
    children = children ++ [HabitTrackerWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HabitTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HabitTrackerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
