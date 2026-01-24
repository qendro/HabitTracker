defmodule HabitTracker.Tracker.CompletionRateTest do
  use HabitTracker.DataCase, async: true

  import HabitTracker.AccountsFixtures

  alias HabitTracker.Tracker

  describe "completion_rate/3 for weekly periods" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "America/New_York"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily Habit",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "returns 0.0 when no scheduled occurrences", %{user: user} do
      # Create a habit that is never scheduled (empty weekdays)
      {:ok, never_scheduled} =
        Tracker.create_habit(user, %{
          name: "Never",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "weekdays", "days" => []}
        })

      assert Tracker.completion_rate(never_scheduled, :this_week, "America/New_York") == 0.0
    end

    test "returns 0.0 when no completions", %{habit: habit} do
      # No logs created
      assert Tracker.completion_rate(habit, :this_week, "America/New_York") == 0.0
    end

    test "returns 1.0 when all scheduled occurrences completed", %{habit: habit} do
      # Get this week's date range
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))
      end_of_week = Date.add(start_of_week, 6)
      
      # Complete all days this week (entire week, not just up to today)
      for days_offset <- 0..6 do
        date = Date.add(start_of_week, days_offset)
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      # Should be 100% for the entire week
      rate = Tracker.completion_rate(habit, :this_week, "America/New_York")
      assert rate == 1.0
    end

    test "calculates partial completion correctly", %{habit: habit} do
      # Get this week's date range
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))
      
      # Complete exactly 3 days out of the 7-day week
      for days_offset <- 0..2 do
        date = Date.add(start_of_week, days_offset)
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      rate = Tracker.completion_rate(habit, :this_week, "America/New_York")
      expected_rate = 3 / 7  # 3 completed out of 7 days in the week
      
      assert_in_delta rate, expected_rate, 0.01
    end

    test "only counts complete status, not planned", %{habit: habit} do
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))
      
      # Mark some as planned, some as complete
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, Date.add(start_of_week, 1), %{status: :planned})
      
      rate = Tracker.completion_rate(habit, :this_week, "America/New_York")
      expected_rate = 1 / 7  # Only 1 complete out of 7 days in the week
      
      assert_in_delta rate, expected_rate, 0.01
    end
  end

  describe "completion_rate/3 for monthly periods" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "UTC"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily Habit",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "returns 0.0 when no completions", %{habit: habit} do
      assert Tracker.completion_rate(habit, :this_month, "UTC") == 0.0
    end

    test "calculates monthly completion correctly", %{habit: habit} do
      today = today_in_timezone("UTC")
      start_of_month = %{today | day: 1}
      end_of_month = Date.end_of_month(today)
      days_in_month = Date.diff(end_of_month, start_of_month) + 1
      
      # Complete first 10 days of the month
      for day <- 1..10 do
        date = %{start_of_month | day: day}
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      rate = Tracker.completion_rate(habit, :this_month, "UTC")
      expected_rate = 10 / days_in_month  # 10 completed out of total days in month
      
      assert_in_delta rate, expected_rate, 0.01
    end
  end

  describe "completion_rate/3 with weekday schedules" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "America/Los_Angeles"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Weekday Habit",
          type: :binary,
          goal_horizon: :weekly,
          frequency_goal: 5,
          occurrence_schedule: %{"type" => "weekdays", "days" => [1, 2, 3, 4, 5]}
        })

      %{habit: habit, user: user}
    end

    test "only counts scheduled weekdays in denominator", %{habit: habit} do
      # Get this week's date range
      today = today_in_timezone("America/Los_Angeles")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))
      end_of_week = Date.add(start_of_week, 6)
      
      # Complete Monday and Tuesday (days 1 and 2)
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, Date.add(start_of_week, 1), %{status: :complete})
      
      # Count total weekdays in the entire week (should be 5: Mon-Fri)
      total_weekdays = 
        0..6
        |> Enum.map(&Date.add(start_of_week, &1))
        |> Enum.count(&(Date.day_of_week(&1) in [1, 2, 3, 4, 5]))
      
      rate = Tracker.completion_rate(habit, :this_week, "America/Los_Angeles")
      expected_rate = 2 / total_weekdays  # 2 completed out of 5 weekdays
      
      assert_in_delta rate, expected_rate, 0.01
    end

    test "weekend completions are counted even for weekday habits", %{habit: habit} do
      # This test verifies that completions on unscheduled days still count
      # toward the completion rate (bonus completions are allowed)
      today = today_in_timezone("America/Los_Angeles")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))
      
      # Complete Saturday and Sunday (unscheduled days)
      saturday = Date.add(start_of_week, 5)
      sunday = Date.add(start_of_week, 6)
      
      {:ok, _} = Tracker.log_habit(habit, saturday, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, sunday, %{status: :complete})
      
      # Complete Monday
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{status: :complete})
      
      # Count total weekdays in the week (should be 5: Mon-Fri)
      total_weekdays = 
        0..6
        |> Enum.map(&Date.add(start_of_week, &1))
        |> Enum.count(&(Date.day_of_week(&1) in [1, 2, 3, 4, 5]))
      
      rate = Tracker.completion_rate(habit, :this_week, "America/Los_Angeles")
      
      # All 3 completions count (including weekend bonus), denominator is 5 weekdays
      expected_rate = 3 / total_weekdays  # 3 completions / 5 scheduled days = 0.6
      assert_in_delta rate, expected_rate, 0.01
    end
  end

  describe "completion_rate/3 with timezone boundaries" do
    test "respects timezone for week boundaries" do
      # Create user in timezone ahead of UTC
      user = unconfirmed_user_fixture(%{timezone: "Asia/Tokyo"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      # Get today in Tokyo timezone
      tokyo_today = today_in_timezone("Asia/Tokyo")
      
      # Complete today
      {:ok, _} = Tracker.log_habit(habit, tokyo_today, %{status: :complete})

      # Rate should be calculated based on Tokyo timezone week
      rate = Tracker.completion_rate(habit, :this_week, "Asia/Tokyo")
      
      # Should have at least some completion rate
      assert rate > 0.0
      assert rate <= 1.0
    end

    test "respects timezone for month boundaries" do
      # Create user in timezone behind UTC
      user = unconfirmed_user_fixture(%{timezone: "America/New_York"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      # Get today in New York timezone
      ny_today = today_in_timezone("America/New_York")
      
      # Complete today
      {:ok, _} = Tracker.log_habit(habit, ny_today, %{status: :complete})

      # Rate should be calculated based on New York timezone month
      rate = Tracker.completion_rate(habit, :this_month, "America/New_York")
      
      # Should have at least some completion rate
      assert rate > 0.0
      assert rate <= 1.0
    end
  end

  describe "completion_rate/3 with numeric habits" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "UTC"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Numeric Habit",
          type: :numeric,
          target_value: 100,
          unit_label: "reps",
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "counts numeric habit as complete when value >= target", %{habit: habit} do
      today = today_in_timezone("UTC")
      
      # Log with value >= target (should auto-complete)
      {:ok, _} = Tracker.log_habit(habit, today, %{numeric_value: 100})

      rate = Tracker.completion_rate(habit, :this_week, "UTC")
      
      # Should count as complete
      assert rate > 0.0
    end

    test "does not count numeric habit as complete when value < target", %{habit: habit} do
      today = today_in_timezone("UTC")
      
      # Log with value < target (should be planned, not complete)
      {:ok, _} = Tracker.log_habit(habit, today, %{numeric_value: 50})

      rate = Tracker.completion_rate(habit, :this_week, "UTC")
      
      # Should not count as complete
      assert rate == 0.0
    end
  end

  describe "completion_rate/3 with duration habits" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "UTC"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Duration Habit",
          type: :duration,
          target_value: 30,
          unit_label: "minutes",
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "counts duration habit as complete when duration >= target", %{habit: habit} do
      today = today_in_timezone("UTC")
      
      # Log with duration >= target (should auto-complete)
      {:ok, _} = Tracker.log_habit(habit, today, %{duration_minutes: 30})

      rate = Tracker.completion_rate(habit, :this_week, "UTC")
      
      # Should count as complete
      assert rate > 0.0
    end

    test "does not count duration habit as complete when duration < target", %{habit: habit} do
      today = today_in_timezone("UTC")
      
      # Log with duration < target (should be planned, not complete)
      {:ok, _} = Tracker.log_habit(habit, today, %{duration_minutes: 15})

      rate = Tracker.completion_rate(habit, :this_week, "UTC")
      
      # Should not count as complete
      assert rate == 0.0
    end
  end

  # Helper function to get today in a specific timezone
  defp today_in_timezone(timezone) do
    case DateTime.shift_zone(DateTime.utc_now(:second), timezone) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> DateTime.utc_now(:second) |> DateTime.to_date()
    end
  end
end
