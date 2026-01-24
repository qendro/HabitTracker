defmodule HabitTracker.Tracker.HabitLogPropertyTest do
  use HabitTracker.DataCase, async: true
  use ExUnitProperties

  import HabitTracker.AccountsFixtures
  import HabitTracker.TrackerFixtures

  alias HabitTracker.Repo
  alias HabitTracker.Tracker
  alias HabitTracker.Tracker.HabitLog

  @tag feature: "habit-tracker",
       property: 13,
       property_text: "Numeric habits auto-complete at threshold"
  property "numeric habits auto-complete at threshold" do
    check all(
            target <- StreamData.integer(1..10),
            value <- StreamData.integer(1..25),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Numbers",
          type: :numeric,
          target_value: target,
          unit_label: "count",
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-02], %{numeric_value: value})

      if value >= target do
        assert log.status == :complete
      else
        assert log.status == :planned
      end
    end
  end

  @tag feature: "habit-tracker",
       property: 14,
       property_text: "Duration habits auto-complete at threshold"
  property "duration habits auto-complete at threshold" do
    check all(
            target <- StreamData.integer(1..60),
            minutes <- StreamData.integer(1..120),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      {:ok, habit} =
        Tracker.create_habit(user, %{
          name: "Focus",
          type: :duration,
          target_value: target,
          unit_label: "minutes",
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-03], %{duration_minutes: minutes})

      if minutes >= target do
        assert log.status == :complete
      else
        assert log.status == :planned
      end
    end
  end

  @tag feature: "habit-tracker",
       property: 15,
       property_text: "No implicit log creation"
  property "no implicit log creation" do
    check all(
            date <- date_gen(),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()
      _habit = habit_fixture(user)

      assert Tracker.get_logs_for_date(user, date) == []
    end
  end

  @tag feature: "habit-tracker",
       property: 16,
       property_text: "Missing logs treated as not_complete"
  property "missing logs treated as not_complete" do
    check all(
            date <- date_gen(),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()
      habit = habit_fixture(user)

      assert is_nil(Repo.get_by(HabitLog, habit_id: habit.id, local_date: date))
    end
  end

  @tag feature: "habit-tracker",
       property: 18,
       property_text: "Local date matches user timezone"
  property "local date matches user timezone" do
    check all(
            timezone <- StreamData.member_of(["UTC", "America/Los_Angeles", "Asia/Tokyo"]),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture(%{timezone: timezone})
      habit = habit_fixture(user)

      dt = ~U[2026-01-01 01:30:00Z]

      {:ok, log} = Tracker.log_habit(habit, dt, %{status: :planned})

      expected =
        case DateTime.shift_zone(dt, timezone) do
          {:ok, shifted} -> DateTime.to_date(shifted)
          _ -> DateTime.to_date(dt)
        end

      assert log.local_date == expected
    end
  end

  @tag feature: "habit-tracker",
       property: 19,
       property_text: "Log updates preserve creation timestamp"
  property "log updates preserve creation timestamp" do
    check all(
            status <- StreamData.member_of([:planned, :complete]),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()
      habit = habit_fixture(user)

      {:ok, log} = Tracker.log_habit(habit, ~D[2026-01-04], %{status: :planned})
      inserted_at = log.inserted_at

      {:ok, updated} = Tracker.update_habit_log(log, %{status: status})

      assert updated.inserted_at == inserted_at
    end
  end

  defp date_gen do
    StreamData.map(
      StreamData.tuple({StreamData.integer(1..12), StreamData.integer(1..28)}),
      fn {month, day} -> Date.new!(2026, month, day) end
    )
  end
end
