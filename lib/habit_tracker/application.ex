defmodule HabitTracker.Application do
  use Application

  def start(_type, _args) do
    HabitTracker.Privacy.install()

    children = [
      HabitTracker.Repo,
      {Phoenix.PubSub, name: HabitTracker.PubSub},
      {Oban, Application.fetch_env!(:habit_tracker, Oban)},
      HabitTrackerWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: HabitTracker.Supervisor)
  end

  def config_change(changed, _new, removed),
    do: HabitTrackerWeb.Endpoint.config_change(changed, removed)
end
