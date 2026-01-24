defmodule HabitTracker.Repo.Migrations.CreateHabits do
  use Ecto.Migration

  def change do
    create table(:habits) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :string
      add :icon, :string
      add :color, :string
      add :type, :string, null: false
      add :target_value, :integer
      add :unit_label, :string
      add :goal_horizon, :string, null: false
      add :frequency_goal, :integer
      add :occurrence_schedule, :map, null: false
      add :position, :integer, null: false, default: 0
      add :active, :boolean, null: false, default: true
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:habits, [:user_id])
    create index(:habits, [:active])
    create index(:habits, [:position])
  end
end
