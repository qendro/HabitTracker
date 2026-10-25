defmodule HabitTracker.Repo.Migrations.CreateHealthJournal do
  use Ecto.Migration

  def change do
    alter table(:users), do: add(:hide_previews, :boolean, null: false, default: false)

    create table(:health_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false
      add :event_timezone, :string, null: false
      add :notes, :text
      add :details, :map, null: false, default: %{}
      add :client_entry_id, :uuid, null: false
      add :source, :string, null: false, default: "manual"
      add :lock_version, :integer, null: false, default: 1
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:health_entries, [:user_id, :client_entry_id])
    create index(:health_entries, [:user_id, :occurred_at, :id])

    create constraint(:health_entries, :valid_kind,
             check: "kind IN ('stool', 'check_in', 'note')"
           )

    create table(:health_attachments) do
      add :entry_id, references(:health_entries, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :storage_key, :uuid, null: false
      add :state, :string, null: false, default: "pending"
      add :content_type, :string
      add :byte_size, :bigint
      add :width, :integer
      add :height, :integer
      add :checksum, :string
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:health_attachments, [:storage_key])
    create index(:health_attachments, [:entry_id, :user_id])
    create index(:health_attachments, [:state, :updated_at])
  end
end
