defmodule HabitTracker.HealthJournal.Note do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false
  embedded_schema do
    field :category, :string, redact: true
  end

  def changeset(data, attrs) do
    data
    |> cast(attrs, [:category])
    |> validate_required([:category])
    |> validate_inclusion(:category, ~w(general meal supplement))
  end
end
