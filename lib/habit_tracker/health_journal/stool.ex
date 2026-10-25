defmodule HabitTracker.HealthJournal.Stool do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false
  embedded_schema do
    field :bristol, :integer, redact: true
    field :urgency, :string, redact: true
    field :discomfort, :integer, redact: true
  end

  def changeset(data, attrs) do
    data
    |> cast(attrs, [:bristol, :urgency, :discomfort])
    |> validate_number(:bristol, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
    |> validate_inclusion(:urgency, ~w(none mild moderate severe))
    |> validate_number(:discomfort, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
  end
end
