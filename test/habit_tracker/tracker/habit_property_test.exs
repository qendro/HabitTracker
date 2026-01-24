defmodule HabitTracker.Tracker.HabitPropertyTest do
  use HabitTracker.DataCase, async: true
  use ExUnitProperties

  import HabitTracker.AccountsFixtures
  import HabitTracker.TrackerFixtures

  alias HabitTracker.Repo
  alias HabitTracker.Tracker
  alias HabitTracker.Tracker.{Habit, HabitLog}

  @tag feature: "habit-tracker",
       property: 5,
       property_text: "Numeric habits require target value"
  property "numeric habits require target value" do
    check all(
            name <- StreamData.string(:alphanumeric, min_length: 1, max_length: 20),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      changeset =
        Habit.changeset(%Habit{user_id: user.id}, %{
          name: name,
          type: :numeric,
          goal_horizon: :daily,
          occurrence_schedule: %{"type" => "daily"}
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).target_value
    end
  end

  @tag feature: "habit-tracker",
       property: 10,
       property_text: "Frequency goals must be positive integers"
  property "frequency goals must be positive integers" do
    check all(
            frequency_goal <- StreamData.integer(-10..0),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      changeset =
        Habit.changeset(%Habit{user_id: user.id}, %{
          name: "Read",
          type: :binary,
          goal_horizon: :weekly,
          frequency_goal: frequency_goal,
          occurrence_schedule: %{"type" => "daily"}
        })

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).frequency_goal
    end
  end

  @tag feature: "habit-tracker",
       property: 7,
       property_text: "Habit reordering updates positions"
  property "habit reordering updates positions" do
    check all(
            names <-
              StreamData.uniq_list_of(
                StreamData.string(:alphanumeric, min_length: 3, max_length: 10),
                min_length: 2,
                max_length: 5
              ),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()

      habits =
        names
        |> Enum.with_index()
        |> Enum.map(fn {name, index} ->
          habit_fixture(user, %{name: name, position: index})
        end)

      new_order = Enum.reverse(habits)
      assert :ok = Tracker.reorder_habits(user, Enum.map(new_order, & &1.id))

      positions =
        Tracker.list_habits(user)
        |> Map.new(&{&1.id, &1.position})

      Enum.with_index(new_order, fn habit, index ->
        assert positions[habit.id] == index
      end)
    end
  end

  @tag feature: "habit-tracker",
       property: 8,
       property_text: "Editing habits preserves historical logs"
  property "editing habits preserves historical logs" do
    check all(
            new_name <- StreamData.string(:alphanumeric, min_length: 3, max_length: 20),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()
      habit = habit_fixture(user)

      log =
        %HabitLog{habit_id: habit.id, user_id: user.id}
        |> HabitLog.changeset(%{local_date: ~D[2026-01-01], status: :complete})
        |> Repo.insert!()

      assert {:ok, _habit} = Tracker.update_habit(habit, %{name: new_name})

      log_id = log.id
      habit_id = habit.id

      assert %HabitLog{id: ^log_id, habit_id: ^habit_id} = Repo.get!(HabitLog, log_id)
    end
  end

  @tag feature: "habit-tracker",
       property: 20,
       property_text: "Unique constraint on habit logs"
  property "unique constraint on habit logs" do
    check all(
            status <- StreamData.member_of([:planned, :complete]),
            max_runs: 100
          ) do
      user = unconfirmed_user_fixture()
      habit = habit_fixture(user)

      attrs = %{local_date: ~D[2026-01-02], status: status}

      assert {:ok, _log} =
               %HabitLog{habit_id: habit.id, user_id: user.id}
               |> HabitLog.changeset(attrs)
               |> Repo.insert()

      assert {:error, changeset} =
               %HabitLog{habit_id: habit.id, user_id: user.id}
               |> HabitLog.changeset(attrs)
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).habit_id
    end
  end
end
