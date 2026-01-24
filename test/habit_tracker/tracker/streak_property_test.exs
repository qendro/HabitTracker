defmodule HabitTracker.Tracker.StreakPropertyTest do
  use HabitTracker.DataCase, async: true
  use ExUnitProperties

  import HabitTracker.AccountsFixtures

  alias HabitTracker.Tracker

  @tag feature: "habit-tracker",
       property: 24,
       property_text: "Streaks count consecutive scheduled completions"
  property "streaks count consecutive scheduled completions" do
    check all(
            length <- StreamData.integer(1..7),
            offset <- StreamData.integer(1..10),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      end_date = Date.add(Date.utc_today(), -offset)
      start_date = Date.add(end_date, -(length - 1))

      Enum.each(Date.range(start_date, end_date), fn date ->
        {:ok, _} = Tracker.log_habit(habit, date, %{status: :complete})
      end)

      assert Tracker.calculate_streak(habit, end_date) == length
    end
  end

  @tag feature: "habit-tracker",
       property: 25,
       property_text: "Future dates excluded from streaks"
  property "future dates excluded from streaks" do
    check all(
            future_offset <- StreamData.integer(1..5),
            future_status <- StreamData.member_of([:planned, :complete]),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      today = Date.utc_today()
      future_date = Date.add(today, future_offset)

      {:ok, _} = Tracker.log_habit(habit, today, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, future_date, %{status: future_status})

      assert Tracker.calculate_streak(habit, future_date) == 1
    end
  end

  @tag feature: "habit-tracker",
       property: 26,
       property_text: "Unscheduled days don't break streaks"
  property "unscheduled days don't break streaks" do
    check all(
            day <- StreamData.integer(1..7),
            weeks_back <- StreamData.integer(1..6),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Weekly",
          type: :binary,
          goal_horizon: :weekly,
          frequency_goal: 1,
          occurrence_schedule: %{"type" => "weekly", "days" => [day]}
        })

      base_date = Date.add(Date.utc_today(), -7 * weeks_back)
      last_scheduled = last_weekday(base_date, day)
      previous_scheduled = Date.add(last_scheduled, -7)

      {:ok, _} = Tracker.log_habit(habit, previous_scheduled, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, last_scheduled, %{status: :complete})

      assert Tracker.calculate_streak(habit, last_scheduled) == 2
    end
  end

  @tag feature: "habit-tracker",
       property: 27,
       property_text: "Weekday habits don't break on weekends"
  property "weekday habits don't break on weekends" do
    check all(
            weeks_back <- StreamData.integer(1..6),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Weekdays",
          type: :binary,
          goal_horizon: :weekly,
          frequency_goal: 5,
          occurrence_schedule: %{"type" => "weekdays", "days" => [1, 2, 3, 4, 5]}
        })

      base_date = Date.add(Date.utc_today(), -7 * weeks_back)
      monday = last_weekday(base_date, 1)
      friday = Date.add(monday, -3)

      {:ok, _} = Tracker.log_habit(habit, friday, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, monday, %{status: :complete})

      assert Tracker.calculate_streak(habit, monday) == 2
    end
  end

  @tag feature: "habit-tracker",
       property: 28,
       property_text: "Missing scheduled occurrence resets streak"
  property "missing scheduled occurrence resets streak" do
    check all(
            offset <- StreamData.integer(1..10),
            gap <- StreamData.integer(1..3),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Daily",
          type: :binary,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      end_date = Date.add(Date.utc_today(), -offset)
      previous_date = Date.add(end_date, -(gap + 1))

      {:ok, _} = Tracker.log_habit(habit, previous_date, %{status: :complete})
      {:ok, _} = Tracker.log_habit(habit, end_date, %{status: :complete})

      assert Tracker.calculate_streak(habit, end_date) == 1
    end
  end

  defp last_weekday(date, target_day) do
    days_back = rem(Date.day_of_week(date) - target_day + 7, 7)
    Date.add(date, -days_back)
  end
end
