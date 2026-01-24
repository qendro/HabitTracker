defmodule Mix.Tasks.CreateAdmin do
  @moduledoc """
  Creates an admin account.

  Usage:
      mix create_admin <email> <password>

  Example:
      mix create_admin admin@habbits.xyz Admin123!
  """

  use Mix.Task

  @shortdoc "Creates an admin account"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [email, password] ->
        create_admin(email, password)

      _ ->
        Mix.shell().error("Usage: mix create_admin <email> <password>")
        Mix.shell().error("Example: mix create_admin admin@habbits.xyz Admin123!")
    end
  end

  defp create_admin(email, password) do
    alias HabitTracker.Admin

    case Admin.get_admin_by_email(email) do
      nil ->
        case Admin.register_admin(%{email: email, password: password}) do
          {:ok, admin} ->
            Mix.shell().info("\n✅ Admin account created successfully!")
            Mix.shell().info("Email: #{admin.email}")
            Mix.shell().info("Password: #{password}")
            Mix.shell().info("\nYou can now log in at: http://localhost:4000/admin/login")

          {:error, changeset} ->
            Mix.shell().error("\n❌ Admin creation failed:")
            Mix.shell().error(inspect(changeset.errors))
        end

      _admin ->
        Mix.shell().info("\n⚠️  Admin account already exists for #{email}")
        Mix.shell().info("You can log in at: http://localhost:4000/admin/login")
    end
  end
end
