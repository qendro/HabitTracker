defmodule HabitTracker.Repo.Migrations.CreateJournalEntries do
  use Ecto.Migration

  def change do
    create table(:journal_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :local_date, :date, null: false
      add :content, :text, null: false
      add :word_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:journal_entries, [:user_id, :local_date])
    create index(:journal_entries, [:user_id])
    create index(:journal_entries, [:local_date])
  end
end
