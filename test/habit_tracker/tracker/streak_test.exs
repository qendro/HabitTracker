defmodule HabitTracker.Tracker.StreakTest do
  use HabitTracker.DataCase, async: true

  import HabitTracker.AccountsFixtures

  alias HabitTracker.Tracker

  describe "future date handling" do
    setup do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit}
    end

    test "creating future completion doesn't change current streak", %{habit: habit} do
      today = Date.utc_today()
      future_date = Date.add(today, 3)

      {:ok, _} = Tracker.log_habit(habit, today, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, future_date, %{status: :complete})

      assert Tracker.calculate_streak(habit, today) == 1
    end

    test "creating future planned doesn't change current streak", %{habit: habit} do
      today = Date.utc_today()
      future_date = Date.add(today, 2)

      {:ok, _} = Tracker.log_habit(habit, today, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, future_date, %{status: :planned})

      assert Tracker.calculate_streak(habit, today) == 1
    end

    test "viewing future date shows streak as of today", %{habit: habit} do
      today = Date.utc_today()
      future_date = Date.add(today, 5)

      {:ok, _} = Tracker.log_habit(habit, today, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, future_date, %{status: :complete})

      assert Tracker.calculate_streak(habit, future_date) == 1
    end
  end
end
