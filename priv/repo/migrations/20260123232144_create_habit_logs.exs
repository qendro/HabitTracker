defmodule HabitTracker.Repo.Migrations.CreateHabitLogs do
  use Ecto.Migration

  def change do
    create table(:habit_logs) do
      add :habit_id, references(:habits, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :local_date, :date, null: false
      add :status, :string, null: false
      add :numeric_value, :integer
      add :duration_minutes, :integer
      add :notes, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:habit_logs, [:habit_id, :local_date])
    create index(:habit_logs, [:habit_id])
    create index(:habit_logs, [:user_id])
    create index(:habit_logs, [:local_date])
  end
end
