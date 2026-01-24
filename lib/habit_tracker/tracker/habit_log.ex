defmodule HabitTracker.Tracker.HabitLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "habit_logs" do
    field :local_date, :date
    field :status, Ecto.Enum, values: [:not_complete, :planned, :complete]
    field :numeric_value, :integer
    field :duration_minutes, :integer
    field :notes, :string

    belongs_to :habit, HabitTracker.Tracker.Habit
    belongs_to :user, HabitTracker.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @fields [:local_date, :status, :numeric_value, :duration_minutes, :notes]
  @required_fields [:local_date, :status]

  def changeset(log, attrs) do
    log
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_number(:numeric_value, greater_than_or_equal_to: 0)
    |> validate_number(:duration_minutes, greater_than_or_equal_to: 0)
    |> unique_constraint([:habit_id, :local_date])
  end
end
