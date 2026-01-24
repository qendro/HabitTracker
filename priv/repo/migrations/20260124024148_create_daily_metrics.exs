defmodule HabitTracker.Repo.Migrations.CreateDailyMetrics do
  use Ecto.Migration

  def change do
    create table(:daily_metrics) do
      add :metric_date, :date, null: false
      add :total_users, :integer, null: false
      add :new_users_today, :integer, null: false
      add :dau, :integer, null: false
      add :wau, :integer, null: false
      add :mau, :integer, null: false
      add :total_habits, :integer, null: false
      add :active_habits, :integer, null: false
      add :completions_today, :integer, null: false
      add :avg_completion_rate, :float, null: false

      timestamps()
    end

    create unique_index(:daily_metrics, [:metric_date])
    create index(:daily_metrics, [:metric_date])
  end
end
