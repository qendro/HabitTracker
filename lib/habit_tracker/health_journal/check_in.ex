defmodule HabitTracker.HealthJournal.CheckIn do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false
  embedded_schema do
    field :overall, :integer, redact: true
    field :bloating, :integer, redact: true
    field :discomfort, :integer, redact: true
    field :energy, :integer, redact: true
    field :stress, :integer, redact: true
  end

  def changeset(data, attrs) do
    data
    |> cast(attrs, [:overall, :bloating, :discomfort, :energy, :stress])
    |> validate_number(:overall, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:bloating, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:discomfort, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:energy, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:stress, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
  end
end
