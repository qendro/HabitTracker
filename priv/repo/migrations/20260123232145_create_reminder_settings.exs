defmodule HabitTracker.Repo.Migrations.CreateReminderSettings do
  use Ecto.Migration

  def change do
    create table(:reminder_settings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :enabled, :boolean, default: false, null: false
      add :time_of_day, :time, default: fragment("'08:00:00'"), null: false
      add :habit_selection, :string, default: "all", null: false
      add :selected_habit_ids, {:array, :bigint}, default: []

      timestamps()
    end

    create unique_index(:reminder_settings, [:user_id])
    create index(:reminder_settings, [:enabled])
  end
end
