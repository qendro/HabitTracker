# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Or with environment variables to create an admin:
#
#     ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=password mix run priv/repo/seeds.exs

alias HabitTracker.Admin

# Create admin account if environment variables are provided
if admin_email = System.get_env("ADMIN_EMAIL") do
  admin_password = System.get_env("ADMIN_PASSWORD")

  if admin_password do
    case Admin.get_admin_by_email(admin_email) do
      nil ->
        case Admin.register_admin(%{email: admin_email, password: admin_password}) do
          {:ok, _admin} ->
            IO.puts("✅ Admin account created for #{admin_email}")

          {:error, changeset} ->
            IO.puts("❌ Admin creation failed:")
            IO.inspect(changeset.errors)
        end

      _admin ->
        IO.puts("ℹ️  Admin account already exists for #{admin_email}")
    end
  else
    IO.puts("⚠️  ADMIN_PASSWORD is required when ADMIN_EMAIL is set")
  end
end
