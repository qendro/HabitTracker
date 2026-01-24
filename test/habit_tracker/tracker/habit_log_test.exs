defmodule HabitTracker.Tracker.HabitLogTest do
  use HabitTracker.DataCase, async: true

  import HabitTracker.AccountsFixtures

  alias HabitTracker.Tracker

  describe "habit log validation matrix" do
    setup do
      user = unconfirmed_user_fixture()

      {:ok, binary_habit} =
        Tracker.create_habit(user, %{
          name: "Stretch",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      {:ok, numeric_habit} =
        Tracker.create_habit(user, %{
          name: "Pushups",
          type: :numeric,
          target_value: 10,
          unit_label: "reps",
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      {:ok, duration_habit} =
        Tracker.create_habit(user, %{
          name: "Meditate",
          type: :duration,
          target_value: 20,
          unit_label: "minutes",
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{binary_habit: binary_habit, numeric_habit: numeric_habit, duration_habit: duration_habit}
    end

    test "binary habit can be planned without value", %{binary_habit: habit} do
      assert {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-05], %{status: :planned})
      assert log.status == :planned
      assert is_nil(log.numeric_value)
      assert is_nil(log.duration_minutes)
    end

    test "binary habit can be complete without value", %{binary_habit: habit} do
      assert {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-06], %{status: :complete})
      assert log.status == :complete
      assert is_nil(log.numeric_value)
      assert is_nil(log.duration_minutes)
    end

    test "numeric habit can be planned without value", %{numeric_habit: habit} do
      assert {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-07], %{status: :planned})
      assert log.status == :planned
      assert is_nil(log.numeric_value)
    end

    test "numeric habit auto-completes when value >= target", %{numeric_habit: habit} do
      assert {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-08], %{numeric_value: 12})
      assert log.status == :complete
    end

    test "duration habit can be planned without value", %{duration_habit: habit} do
      assert {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-09], %{status: :planned})
      assert log.status == :planned
      assert is_nil(log.duration_minutes)
    end

    test "duration habit auto-completes when duration >= target", %{duration_habit: habit} do
      assert {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-10], %{duration_minutes: 25})
      assert log.status == :complete
    end
  end
end
