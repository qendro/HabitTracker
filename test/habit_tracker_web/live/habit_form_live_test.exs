defmodule HabitTrackerWeb.HabitFormLiveTest do
  use HabitTrackerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HabitTracker.AccountsFixtures

  alias HabitTracker.Tracker

  describe "HabitFormLive" do
    setup do
      user = unconfirmed_user_fixture()
      %{user: user}
    end

    test "creates a habit", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits/new")

      view
      |> form("#habit-form-v2",
        habit: %{
          name: "Hydration",
          type: "numeric"
        }
      )
      |> render_change()

      view
      |> form("#habit-form-v2",
        habit: %{
          name: "Hydration",
          type: "numeric",
          target_value: "8",
          unit_label: "glasses",
          schedule_type: "daily"
        }
      )
      |> render_submit()

      assert Enum.any?(Tracker.list_habits(user), &(&1.name == "Hydration"))
    end

    test "validates missing target for numeric habits", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits/new")

      view
      |> form("#habit-form-v2",
        habit: %{
          name: "Run",
          type: "numeric"
        }
      )
      |> render_change()

      html =
        view
        |> form("#habit-form-v2",
          habit: %{
            name: "Run",
            type: "numeric",
            target_value: "",
            schedule_type: "daily"
          }
        )
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "validates weekday selection", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/habits/new")

      view
      |> form("#habit-form-v2",
        habit: %{
          name: "Read",
          type: "binary",
          schedule_type: "weekdays"
        }
      )
      |> render_change()

      html =
        view
        |> form("#habit-form-v2",
          habit: %{
            name: "Read",
            type: "binary",
            schedule_type: "weekdays",
            weekdays: [""]
          }
        )
        |> render_change()

      assert html =~ "select at least one day"
    end
  end
end
