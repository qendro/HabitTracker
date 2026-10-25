defmodule HabitTracker.MixProject do
  use Mix.Project

  def project do
    [
      app: :habit_tracker,
      listeners: [Phoenix.CodeReloader],
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {HabitTracker.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:hammer, "~> 6.0"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:tzdata, "~> 1.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:oban, "~> 2.18"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["compile", "assets.css", "esbuild habit_tracker"],
      "assets.css": fn _ ->
        File.mkdir_p!("priv/static/assets/css")
        File.cp!("assets/css/app.css", "priv/static/assets/css/app.css")
      end,
      "assets.deploy": [
        "assets.css",
        "esbuild habit_tracker --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  # Release configuration
  defp releases do
    [
      habit_tracker: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ]
    ]
  end
end
