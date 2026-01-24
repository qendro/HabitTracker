defmodule HabitTracker.Tracker.FrequencyProgressTest do
  use HabitTracker.DataCase, async: true

  import HabitTracker.AccountsFixtures

  alias HabitTracker.Tracker

  describe "frequency_progress/2 for daily goal horizons" do
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

    test "returns {0, 0} for daily habits (no frequency goal)", %{habit: habit} do
      assert Tracker.frequency_progress(habit, "America/New_York") == {0, 0}
    end
  end

  describe "frequency_progress/2 for weekly goal horizons" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "America/New_York"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Weekly Habit",
          type: :binary,
          goal_horizon: :weekly,
          frequency_goal: 5,
          occurrence_schedule: %{"type" => "weekdays", "days" => [1, 2, 3, 4, 5]}
        })

      %{habit: habit, user: user}
    end

    test "returns {0, target} when no completions", %{habit: habit} do
      assert Tracker.frequency_progress(habit, "America/New_York") == {0, 5}
    end

    test "counts completions in current week", %{habit: habit} do
      # Get this week's date range
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))

      # Complete Monday, Tuesday, Wednesday
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, Date.add(start_of_week, 1), %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, Date.add(start_of_week, 2), %{status: :complete})

      assert Tracker.frequency_progress(habit, "America/New_York") == {3, 5}
    end

    test "only counts complete status, not planned", %{habit: habit} do
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))

      # Complete Monday, plan Tuesday
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, Date.add(start_of_week, 1), %{status: :planned})

      assert Tracker.frequency_progress(habit, "America/New_York") == {1, 5}
    end

    test "does not count completions from previous week", %{habit: habit} do
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))
      last_week = Date.add(start_of_week, -7)

      # Complete last Monday
      {:ok, _} = Tracker.log_habit(habit, last_week, %{status: :complete})

      # Complete this Monday
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{status: :complete})

      # Should only count this week's completion
      assert Tracker.frequency_progress(habit, "America/New_York") == {1, 5}
    end

    test "counts all completions in the week including future dates", %{habit: habit} do
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))
      end_of_week = Date.add(start_of_week, 6)

      # Complete all days in the week
      for days_offset <- 0..6 do
        date = Date.add(start_of_week, days_offset)
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      assert Tracker.frequency_progress(habit, "America/New_York") == {7, 5}
    end

    test "can exceed frequency goal", %{habit: habit} do
      today = today_in_timezone("America/New_York")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))

      # Complete 6 days (more than the goal of 5)
      for days_offset <- 0..5 do
        date = Date.add(start_of_week, days_offset)
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      assert Tracker.frequency_progress(habit, "America/New_York") == {6, 5}
    end
  end

  describe "frequency_progress/2 for monthly goal horizons" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "UTC"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Monthly Habit",
          type: :binary,
          goal_horizon: :monthly,
          frequency_goal: 20,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "returns {0, target} when no completions", %{habit: habit} do
      assert Tracker.frequency_progress(habit, "UTC") == {0, 20}
    end

    test "counts completions in current month", %{habit: habit} do
      today = today_in_timezone("UTC")
      start_of_month = %{today | day: 1}

      # Complete first 10 days of the month
      for day <- 1..10 do
        date = %{start_of_month | day: day}
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      assert Tracker.frequency_progress(habit, "UTC") == {10, 20}
    end

    test "does not count completions from previous month", %{habit: habit} do
      today = today_in_timezone("UTC")
      start_of_month = %{today | day: 1}
      
      # Get last month
      last_month = Date.add(start_of_month, -1)

      # Complete last month
      {:ok, _} = Tracker.log_habit(habit, last_month, %{status: :complete})

      # Complete this month
      {:ok, _} = Tracker.log_habit(habit, start_of_month, %{status: :complete})

      # Should only count this month's completion
      assert Tracker.frequency_progress(habit, "UTC") == {1, 20}
    end

    test "can exceed frequency goal", %{habit: habit} do
      today = today_in_timezone("UTC")
      start_of_month = %{today | day: 1}

      # Complete 25 days (more than the goal of 20)
      for day <- 1..25 do
        date = %{start_of_month | day: day}
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      assert Tracker.frequency_progress(habit, "UTC") == {25, 20}
    end
  end

  describe "frequency_progress/2 for yearly goal horizons" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "America/Los_Angeles"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Yearly Habit",
          type: :binary,
          goal_horizon: :yearly,
          frequency_goal: 100,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "returns {0, target} when no completions", %{habit: habit} do
      assert Tracker.frequency_progress(habit, "America/Los_Angeles") == {0, 100}
    end

    test "counts completions in current year", %{habit: habit} do
      today = today_in_timezone("America/Los_Angeles")
      start_of_year = %{today | month: 1, day: 1}

      # Complete 15 days in January
      for day <- 1..15 do
        date = %{start_of_year | day: day}
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      assert Tracker.frequency_progress(habit, "America/Los_Angeles") == {15, 100}
    end

    test "does not count completions from previous year", %{habit: habit} do
      today = today_in_timezone("America/Los_Angeles")
      start_of_year = %{today | month: 1, day: 1}
      
      # Get last year
      last_year = %{start_of_year | year: start_of_year.year - 1}

      # Complete last year
      {:ok, _} = Tracker.log_habit(habit, last_year, %{status: :complete})

      # Complete this year
      {:ok, _} = Tracker.log_habit(habit, start_of_year, %{status: :complete})

      # Should only count this year's completion
      assert Tracker.frequency_progress(habit, "America/Los_Angeles") == {1, 100}
    end

    test "can exceed frequency goal", %{habit: habit} do
      today = today_in_timezone("America/Los_Angeles")
      start_of_year = %{today | month: 1, day: 1}

      # Complete 120 days (more than the goal of 100)
      for day <- 1..120 do
        date = Date.add(start_of_year, day - 1)
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end

      assert Tracker.frequency_progress(habit, "America/Los_Angeles") == {120, 100}
    end
  end

  describe "frequency_progress/2 with numeric habits" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "UTC"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Numeric Habit",
          type: :numeric,
          target_value: 100,
          unit_label: "reps",
          goal_horizon: :weekly,
          frequency_goal: 3,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "counts numeric habit as complete when value >= target", %{habit: habit} do
      today = today_in_timezone("UTC")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))

      # Log with value >= target (should auto-complete)
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{numeric_value: 100})
      {:ok, _} = Tracker.log_habit(habit, Date.add(start_of_week, 1), %{numeric_value: 150})

      assert Tracker.frequency_progress(habit, "UTC") == {2, 3}
    end

    test "does not count numeric habit as complete when value < target", %{habit: habit} do
      today = today_in_timezone("UTC")
      day_of_week = Date.day_of_week(today)
      start_of_week = Date.add(today, -(day_of_week - 1))

      # Log with value < target (should be planned, not complete)
      {:ok, _} = Tracker.log_habit(habit, start_of_week, %{numeric_value: 50})

      assert Tracker.frequency_progress(habit, "UTC") == {0, 3}
    end
  end

  describe "frequency_progress/2 with duration habits" do
    setup do
      user = unconfirmed_user_fixture(%{timezone: "UTC"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Duration Habit",
          type: :duration,
          target_value: 30,
          unit_label: "minutes",
          goal_horizon: :monthly,
          frequency_goal: 15,
          occurrence_schedule: %{"type" => "daily"}
        })

      %{habit: habit, user: user}
    end

    test "counts duration habit as complete when duration >= target", %{habit: habit} do
      today = today_in_timezone("UTC")
      start_of_month = %{today | day: 1}

      # Log with duration >= target (should auto-complete)
      {:ok, _} = Tracker.log_habit(habit, start_of_month, %{duration_minutes: 30})
      {:ok, _} = Tracker.log_habit(habit, %{start_of_month | day: 2}, %{duration_minutes: 45})

      assert Tracker.frequency_progress(habit, "UTC") == {2, 15}
    end

    test "does not count duration habit as complete when duration < target", %{habit: habit} do
      today = today_in_timezone("UTC")
      start_of_month = %{today | day: 1}

      # Log with duration < target (should be planned, not complete)
      {:ok, _} = Tracker.log_habit(habit, start_of_month, %{duration_minutes: 15})

      assert Tracker.frequency_progress(habit, "UTC") == {0, 15}
    end
  end

  describe "frequency_progress/2 with timezone boundaries" do
    test "respects timezone for week boundaries" do
      # Create user in timezone ahead of UTC
      user = unconfirmed_user_fixture(%{timezone: "Asia/Tokyo"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Weekly",
          type: :binary,
          goal_horizon: :weekly,
          frequency_goal: 7,
          occurrence_schedule: %{"type" => "daily"}
        })

      # Get today in Tokyo timezone
      tokyo_today = today_in_timezone("Asia/Tokyo")
      
      # Complete today
      {:ok, _} = Tracker.log_habit(habit, tokyo_today, %{status: :complete})

      # Progress should be calculated based on Tokyo timezone week
      {completed, target} = Tracker.frequency_progress(habit, "Asia/Tokyo")
      
      assert completed == 1
      assert target == 7
    end

    test "respects timezone for month boundaries" do
      # Create user in timezone behind UTC
      user = unconfirmed_user_fixture(%{timezone: "America/New_York"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Monthly",
          type: :binary,
          goal_horizon: :monthly,
          frequency_goal: 20,
          occurrence_schedule: %{"type" => "daily"}
        })

      # Get today in New York timezone
      ny_today = today_in_timezone("America/New_York")
      
      # Complete today
      {:ok, _} = Tracker.log_habit(habit, ny_today, %{status: :complete})

      # Progress should be calculated based on New York timezone month
      {completed, target} = Tracker.frequency_progress(habit, "America/New_York")
      
      assert completed == 1
      assert target == 20
    end

    test "respects timezone for year boundaries" do
      # Create user in timezone ahead of UTC
      user = unconfirmed_user_fixture(%{timezone: "Australia/Sydney"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Yearly",
          type: :binary,
          goal_horizon: :yearly,
          frequency_goal: 100,
          occurrence_schedule: %{"type" => "daily"}
        })

      # Get today in Sydney timezone
      sydney_today = today_in_timezone("Australia/Sydney")
      
      # Complete today
      {:ok, _} = Tracker.log_habit(habit, sydney_today, %{status: :complete})

      # Progress should be calculated based on Sydney timezone year
      {completed, target} = Tracker.frequency_progress(habit, "Australia/Sydney")
      
      assert completed == 1
      assert target == 100
    end
  end

  describe "frequency_progress/2 with nil frequency_goal" do
    test "returns {completed, 0} when frequency_goal is nil" do
      user = unconfirmed_user_fixture(%{timezone: "UTC"})

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "No Goal",
          type: :binary,
          goal_horizon: :weekly,
          frequency_goal: nil,
          occurrence_schedule: %{"type" => "daily"}
        })

      today = today_in_timezone("UTC")
      {:ok, _} = Tracker.log_habit(habit, today, %{status: :complete})

      assert Tracker.frequency_progress(habit, "UTC") == {1, 0}
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
