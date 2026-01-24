defmodule HabitTracker.TrackerFixtures do
  @moduledoc """
  This module defines test helpers for creating habits.
  """

  alias HabitTracker.AccountsFixtures
  alias HabitTracker.Tracker

  def valid_habit_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Habit #{System.unique_integer()}",
      type: :binary,
      goal_horizon: :daily,
      occurrence_schedule: %{"type" => "daily"},
      position: 0,
      active: true
    })
  end

  def habit_fixture(user \\ AccountsFixtures.user_fixture(), attrs \\ %{}) do
    {:ok, habit} = Tracker.create_habit(user, valid_habit_attributes(attrs))
    habit
  end
end
