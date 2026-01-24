defmodule HabitTrackerWeb.HabitsLiveTest do
  use HabitTrackerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HabitTracker.AccountsFixtures
  import HabitTracker.TrackerFixtures

  describe "HabitsLive" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "displays all habits", %{conn: conn, user: user} do
      habit1 = habit_fixture(user, %{name: "Morning Exercise", type: :binary, icon: "🏃", color: "#3B82F6"})
      habit2 = habit_fixture(user, %{name: "Read Book", type: :binary, icon: "📚", color: "#10B981"})

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits")

      assert html =~ "Morning Exercise"
      assert html =~ "Read Book"
    end

    test "deletes habit", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{name: "Delete Me", type: :binary, icon: "🗑️", color: "#EF4444"})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits")

      assert render(view) =~ "Delete Me"

      # Delete the habit
      view
      |> element("button[phx-click='delete_habit'][phx-value-habit-id='#{habit.id}']")
      |> render_click()

      refute render(view) =~ "Delete Me"
    end

    test "shows empty state when no habits", %{conn: conn, user: user} do
      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits")

      assert html =~ "No habits yet"
    end

    test "displays habit details", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Drink Water",
        description: "Stay hydrated",
        type: :numeric,
        target_value: 8,
        unit_label: "glasses",
        icon: "💧",
        color: "#3B82F6"
      })

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits")

      assert html =~ "Drink Water"
      assert html =~ "Stay hydrated"
      assert html =~ "Target: 8 glasses"
      assert html =~ "Numeric"
    end

    test "displays schedule information", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Weekday Habit",
        type: :binary,
        icon: "💼",
        color: "#3B82F6",
        occurrence_schedule: %{type: "weekdays", days: [1, 2, 3, 4, 5]}
      })

      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits")

      assert html =~ "Mon, Tue, Wed, Thu, Fri"
    end

    test "reorders habits", %{conn: conn, user: user} do
      habit1 = habit_fixture(user, %{name: "First Habit", type: :binary, icon: "1️⃣", color: "#3B82F6", position: 0})
      habit2 = habit_fixture(user, %{name: "Second Habit", type: :binary, icon: "2️⃣", color: "#10B981", position: 1})
      habit3 = habit_fixture(user, %{name: "Third Habit", type: :binary, icon: "3️⃣", color: "#F59E0B", position: 2})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits")

      # Reorder: move habit3 to first position
      view
      |> render_hook("reorder", %{"habit_ids" => [habit3.id, habit1.id, habit2.id]})

      # Verify the habits are reordered in the database
      habits = HabitTracker.Tracker.list_habits(user)
      assert Enum.at(habits, 0).id == habit3.id
      assert Enum.at(habits, 1).id == habit1.id
      assert Enum.at(habits, 2).id == habit2.id
    end
  end
end
