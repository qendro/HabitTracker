defmodule HabitTracker.Tracker.Habit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "habits" do
    field :name, :string
    field :description, :string
    field :icon, :string
    field :color, :string
    field :type, Ecto.Enum, values: [:binary, :numeric, :duration]
    field :target_value, :integer
    field :unit_label, :string
    field :goal_horizon, Ecto.Enum, values: [:daily, :weekly, :monthly, :yearly]
    field :frequency_goal, :integer
    field :occurrence_schedule, :map
    field :position, :integer, default: 0
    field :active, :boolean, default: true
    field :deleted_at, :utc_datetime

    belongs_to :user, HabitTracker.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @fields [
    :name,
    :description,
    :icon,
    :color,
    :type,
    :target_value,
    :unit_label,
    :goal_horizon,
    :frequency_goal,
    :occurrence_schedule,
    :position,
    :active
  ]

  @required_fields [:name, :type, :goal_horizon, :occurrence_schedule]

  def changeset(habit, attrs) do
    habit
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_frequency_goal()
    |> validate_occurrence_schedule()
    |> validate_target_value()
  end

  def soft_delete_changeset(habit) do
    change(habit, deleted_at: DateTime.utc_now(:second), active: false)
  end

  defp validate_frequency_goal(changeset) do
    validate_number(changeset, :frequency_goal, greater_than: 0)
  end

  defp validate_occurrence_schedule(changeset) do
    validate_change(changeset, :occurrence_schedule, fn :occurrence_schedule, value ->
      if is_map(value) do
        []
      else
        [occurrence_schedule: "must be a map"]
      end
    end)
  end

  defp validate_target_value(changeset) do
    case get_field(changeset, :type) do
      type when type in [:numeric, :duration] ->
        changeset
        |> validate_required([:target_value])
        |> validate_number(:target_value, greater_than: 0)

      _ ->
        changeset
    end
  end
end
