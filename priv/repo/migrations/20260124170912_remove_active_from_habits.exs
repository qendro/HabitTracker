defmodule HabitTracker.Repo.Migrations.RemoveActiveFromHabits do
  use Ecto.Migration

  def up do
    # Remove the active field index
    drop_if_exists index(:habits, [:active])
    
    # Remove the active field from habits table
    alter table(:habits) do
      remove :active
    end
    
    # Remove active_habits field from daily_metrics table if it exists
    alter table(:daily_metrics) do
      remove_if_exists :active_habits, :integer
    end
  end

  def down do
    # Add back the active field with default true
    alter table(:habits) do
      add :active, :boolean, null: false, default: true
    end
    
    # Recreate the index
    create index(:habits, [:active])
    
    # Add back active_habits field to daily_metrics
    alter table(:daily_metrics) do
      add :active_habits, :integer
    end
  end
end
