defmodule HabitTracker.Release do
  @moduledoc "Explicit one-time operations. Never provision or migrate at boot."
  @app :habit_tracker
  def migrate do
    Application.load(@app)

    {:ok, _, _} =
      Ecto.Migrator.with_repo(HabitTracker.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  def owner do
    {:ok, _} = Application.ensure_all_started(@app)
    email = IO.gets("Owner email: ") |> String.trim()
    password = read_password()

    case provision_owner(email, password, System.get_env("OWNER_RESET") == "YES") do
      {:ok, _} ->
        IO.puts("Owner ready.")

      {:error, :exists} ->
        raise "Owner exists; use the explicit reset command to change its password"

      {:error, _} ->
        raise "Owner validation failed; use valid email and password (8–72 bytes)"
    end
  end

  defp read_password do
    case System.cmd("stty", ["-F", "/dev/tty", "-echo"], stderr_to_stdout: true) do
      {_, 0} ->
        try do
          IO.gets("Password: ") |> String.trim_trailing("\n")
        after
          System.cmd("stty", ["-F", "/dev/tty", "echo"], stderr_to_stdout: true)
          IO.puts("")
        end

      _ ->
        raise "Use a private interactive terminal to provision or reset the owner"
    end
  end

  def provision_owner(email, password, reset? \\ false) do
    alias HabitTracker.{Accounts, Repo}
    # Serialize provisioning; never silently overwrite an existing account.
    Repo.transaction(fn ->
      Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock(720261025)", [])
      existing = Repo.get_by(Accounts.User, email: email)

      result =
        cond do
          existing && reset? ->
            Accounts.update_user_password(existing, %{password: password})

          existing ->
            {:error, :exists}

          Repo.aggregate(Accounts.User, :count) > 0 ->
            {:error, :owner_already_provisioned}

          true ->
            case Accounts.register_user(%{email: email, password: password}) do
              {:ok, u} -> Repo.update(Accounts.User.confirm_changeset(u))
              error -> error
            end
        end

      case result do
        {:ok, user} -> user
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
