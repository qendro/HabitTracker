defmodule HabitTracker.Tracker.HabitFormTest do
  use HabitTracker.DataCase, async: true

  alias HabitTracker.Tracker.HabitForm

  test "weekdays schedule requires at least one day" do
    habit = HabitForm.default_habit()

    params = %{
      "name" => "Read",
      "type" => "binary",
      "goal_horizon" => "daily",
      "schedule_type" => "weekdays",
      "weekdays" => []
    }

    changeset = HabitForm.changeset(habit, params)

    refute changeset.valid?
    assert "select at least one day" in errors_on(changeset).occurrence_schedule
  end

  test "frequency goal is required for non-daily horizons" do
    habit = HabitForm.default_habit()

    params = %{
      "name" => "Meditate",
      "type" => "binary",
      "goal_horizon" => "weekly",
      "schedule_type" => "daily"
    }

    changeset = HabitForm.changeset(habit, params)

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).frequency_goal
  end
end
