defmodule HabitTracker.Repo.Migrations.CreateAdminActions do
  use Ecto.Migration

  def change do
    create table(:admin_actions) do
      add :admin_id, references(:admins, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :target_user_id, references(:users, on_delete: :nilify_all)
      add :success, :boolean, null: false, default: true
      add :metadata, :map

      timestamps(updated_at: false)
    end

    create index(:admin_actions, [:admin_id])
    create index(:admin_actions, [:target_user_id])
    create index(:admin_actions, [:inserted_at])
    create index(:admin_actions, [:action])
  end
end
