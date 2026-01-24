defmodule HabitTracker.Release do
  @moduledoc """
  Release tasks for production deployment.
  
  These functions are used during deployment to perform operations
  like database migrations that need to run before the application starts.
  """

  @app :habit_tracker

  @doc """
  Runs database migrations.
  
  This function is called during deployment to ensure the database
  schema is up to date before the application starts.
  
  ## Usage
  
  In production, run this via the release command:
  
      bin/habit_tracker eval "HabitTracker.Release.migrate()"
  
  Or use the migrate.sh script:
  
      bin/migrate.sh
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Rolls back the database by the given number of migrations.
  
  ## Usage
  
      bin/habit_tracker eval "HabitTracker.Release.rollback(HabitTracker.Repo, 1)"
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seeds the database with initial data.
  
  ## Usage
  
      bin/habit_tracker eval "HabitTracker.Release.seed()"
  """
  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo ->
        # Run the seed script
        seed_script = Path.join([priv_dir(@app), "repo", "seeds.exs"])
        
        if File.exists?(seed_script) do
          Code.eval_file(seed_script)
        end
      end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp priv_dir(app) do
    Application.app_dir(app, "priv")
  end
end
