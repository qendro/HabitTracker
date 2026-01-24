defmodule HabitTracker.Reminders.ReminderSettings do
  @moduledoc """
  Schema for user reminder settings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "reminder_settings" do
    field :enabled, :boolean, default: false
    field :time_of_day, :time, default: ~T[08:00:00]
    field :habit_selection, :string, default: "all"
    field :selected_habit_ids, {:array, :integer}, default: []

    belongs_to :user, HabitTracker.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(reminder_settings, attrs) do
    reminder_settings
    |> cast(attrs, [:enabled, :time_of_day, :habit_selection, :selected_habit_ids])
    |> validate_required([:enabled, :time_of_day, :habit_selection])
    |> validate_inclusion(:habit_selection, ["all", "selected"])
    |> validate_selected_habits()
  end

  defp validate_selected_habits(changeset) do
    habit_selection = get_field(changeset, :habit_selection)
    selected_habit_ids = get_field(changeset, :selected_habit_ids)

    case habit_selection do
      "selected" ->
        if selected_habit_ids == [] or is_nil(selected_habit_ids) do
          add_error(changeset, :selected_habit_ids, "must select at least one habit")
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
