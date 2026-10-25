defmodule HabitTracker.HealthJournal.Attachment do
  use Ecto.Schema

  schema "health_attachments" do
    belongs_to :entry, HabitTracker.HealthJournal.Entry
    belongs_to :user, HabitTracker.Accounts.User
    field :storage_key, Ecto.UUID
    field :state, :string, default: "pending"
    field :content_type, :string
    field :byte_size, :integer
    field :width, :integer
    field :height, :integer
    field :checksum, :string
    timestamps(type: :utc_datetime_usec)
  end
end
