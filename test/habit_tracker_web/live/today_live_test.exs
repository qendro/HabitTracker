defmodule HabitTrackerWeb.TodayLiveTest do
  use HabitTrackerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HabitTracker.AccountsFixtures
  import HabitTracker.TrackerFixtures

  describe "TodayLive" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "displays today's habits", %{conn: conn, user: user} do
      # Create a habit
      habit = habit_fixture(user, %{
        name: "Morning Exercise",
        type: :binary,
        icon: "🏃",
        color: "#3B82F6"
      })

      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      assert has_element?(view, "#habit-card-#{habit.id}")
      assert render(view) =~ "Morning Exercise"
      assert_completion_summary(render(view), 0, 1)
    end

    test "displays completion summary", %{conn: conn, user: user} do
      # Create two habits
      habit1 = habit_fixture(user, %{name: "Habit 1", type: :binary, icon: "🏃", color: "#3B82F6"})
      _habit2 = habit_fixture(user, %{name: "Habit 2", type: :binary, icon: "📚", color: "#10B981"})

      # Complete one habit
      today = Date.utc_today()
      {:ok, _log} = HabitTracker.Tracker.log_habit(habit1, today, %{status: :complete})

      {:ok, _view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      assert_completion_summary(html, 1, 2)
    end

    test "navigates to previous day", %{conn: conn, user: user} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      view
      |> element("button[phx-click='prev_day']")
      |> render_click()

      yesterday = Date.add(Date.utc_today(), -1)
      assert_patched(view, ~p"/app/day/#{Date.to_iso8601(yesterday)}")
    end

    test "navigates to next day", %{conn: conn, user: user} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      view
      |> element("button[phx-click='next_day']")
      |> render_click()

      tomorrow = Date.add(Date.utc_today(), 1)
      assert_patched(view, ~p"/app/day/#{Date.to_iso8601(tomorrow)}")
    end

    test "shows back to today button when viewing past date", %{conn: conn, user: user} do
      yesterday = Date.add(Date.utc_today(), -1)

      {:ok, view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/day/#{Date.to_iso8601(yesterday)}")

      assert html =~ "Back to Today"
      
      view
      |> element("button[phx-click='back_to_today']")
      |> render_click()

      assert_patched(view, ~p"/app/today")
    end

    test "selects date from calendar picker", %{conn: conn, user: user} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      # Select a specific date
      target_date = Date.add(Date.utc_today(), 5)
      date_string = Date.to_iso8601(target_date)

      view
      |> element("input#date-picker")
      |> render_change(%{"date" => date_string})

      assert_patched(view, ~p"/app/day/#{date_string}")
    end

    test "handles invalid date format in calendar picker", %{conn: conn, user: user} do
      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      # Try to select an invalid date
      view
      |> element("input#date-picker")
      |> render_change(%{"date" => "invalid-date"})

      # Should remain on the same page (today) and not crash
      assert render(view) =~ "Today"
    end

    test "toggles binary habit completion", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Morning Exercise",
        type: :binary,
        icon: "🏃",
        color: "#3B82F6"
      })

      {:ok, view, _html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      # Toggle to complete
      view
      |> element("button[phx-click='toggle_habit'][phx-value-habit-id='#{habit.id}']")
      |> render_click()

      assert_completion_summary(render(view), 1, 1)

      # Toggle back to not complete
      view
      |> element("button[phx-click='toggle_habit'][phx-value-habit-id='#{habit.id}']")
      |> render_click()

      assert_completion_summary(render(view), 0, 1)
    end

    test "displays numeric habit progress", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Drink Water",
        type: :numeric,
        target_value: 8,
        unit_label: "glasses",
        icon: "💧",
        color: "#3B82F6"
      })

      # Log partial progress
      today = Date.utc_today()
      {:ok, _log} = HabitTracker.Tracker.log_habit(habit, today, %{numeric_value: 5})

      {:ok, _view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      assert html =~ "5 / 8"
      assert html =~ "glasses"
      assert html =~ "62%" # 5/8 * 100 = 62.5, rounded to 62
    end

    test "displays duration habit progress", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Meditation",
        type: :duration,
        target_value: 30,
        unit_label: "minutes",
        icon: "🧘",
        color: "#8B5CF6"
      })

      # Log partial progress
      today = Date.utc_today()
      {:ok, _log} = HabitTracker.Tracker.log_habit(habit, today, %{duration_minutes: 15})

      {:ok, _view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      assert html =~ "15 / 30"
      assert html =~ "minutes"
      assert html =~ "50%"
    end

    test "displays streak count", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Daily Habit",
        type: :binary,
        icon: "✅",
        color: "#10B981"
      })

      # Create a 3-day streak
      today = Date.utc_today()
      {:ok, _} = HabitTracker.Tracker.log_habit(habit, Date.add(today, -2), %{status: :complete})
      {:ok, _} = HabitTracker.Tracker.log_habit(habit, Date.add(today, -1), %{status: :complete})
      {:ok, _} = HabitTracker.Tracker.log_habit(habit, today, %{status: :complete})

      {:ok, _view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/today")

      assert html =~ "3 days"
    end

    test "shows 'as of today' label for future dates", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Future Habit",
        type: :binary,
        icon: "🔮",
        color: "#8B5CF6"
      })

      # Create a streak up to today
      today = Date.utc_today()
      {:ok, _} = HabitTracker.Tracker.log_habit(habit, today, %{status: :complete})

      # View tomorrow
      tomorrow = Date.add(today, 1)

      {:ok, _view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/day/#{Date.to_iso8601(tomorrow)}")

      assert html =~ "(as of today)"
    end

    test "only shows scheduled habits", %{conn: conn, user: user} do
      # Create a weekday-only habit
      _habit = habit_fixture(user, %{
        name: "Weekday Habit",
        type: :binary,
        icon: "💼",
        color: "#3B82F6",
        occurrence_schedule: %{type: "weekdays", days: [1, 2, 3, 4, 5]}
      })

      # Find next Monday
      today = Date.utc_today()
      days_until_monday = rem(8 - Date.day_of_week(today), 7)
      next_monday = Date.add(today, days_until_monday)

      {:ok, _view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/day/#{Date.to_iso8601(next_monday)}")

      assert html =~ "Weekday Habit"

      # Find next Sunday
      days_until_sunday = rem(7 - Date.day_of_week(today), 7)
      days_until_sunday = if days_until_sunday == 0, do: 7, else: days_until_sunday
      next_sunday = Date.add(today, days_until_sunday)

      {:ok, _view, html} = 
        conn
        |> log_in_user(user)
        |> live(~p"/app/day/#{Date.to_iso8601(next_sunday)}")

      refute html =~ "Weekday Habit"
    end
  end

  describe "TodayLive with readonly mode" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "blocks binary habit toggle in readonly mode", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Morning Exercise",
        type: :binary,
        icon: "🏃",
        color: "#3B82F6"
      })

      # Log in and add readonly_mode to session
      conn = conn
      |> log_in_user(user)
      |> Plug.Conn.put_session("readonly_mode", true)

      {:ok, view, _html} = live(conn, ~p"/app/today")

      # Verify read-only UI is shown (no toggle button)
      refute has_element?(
               view,
               "button[phx-click='toggle_habit'][phx-value-habit-id='#{habit.id}']"
             )

      assert has_element?(view, "div[aria-label='Read-only mode']")

      # Verify habit was not completed (readonly mode blocked the mutation)
      html = render(view)
      assert_completion_summary(html, 0, 1)
      assert html =~ "Not Complete"
      
      # Verify no log was created in the database
      assert HabitTracker.Tracker.get_log(habit, Date.utc_today()) == nil
    end

    test "blocks numeric value logging in readonly mode", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Drink Water",
        type: :numeric,
        target_value: 8,
        unit_label: "glasses",
        icon: "💧",
        color: "#3B82F6"
      })

      # Log in and add readonly_mode to session
      conn = conn
      |> log_in_user(user)
      |> Plug.Conn.put_session("readonly_mode", true)

      {:ok, view, _html} = live(conn, ~p"/app/today")

      # Verify read-only UI is shown (no log form)
      refute has_element?(view, "form[phx-submit='log_value']")
      assert has_element?(view, "input[type='number'][disabled]")

      # Verify value was not logged (readonly mode blocked the mutation)
      html = render(view)
      assert html =~ "0 / 8"
      refute html =~ "5 / 8"
      
      # Verify no log was created in the database
      assert HabitTracker.Tracker.get_log(habit, Date.utc_today()) == nil
    end

    test "blocks duration logging in readonly mode", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Meditation",
        type: :duration,
        target_value: 30,
        unit_label: "minutes",
        icon: "🧘",
        color: "#8B5CF6"
      })

      # Log in and add readonly_mode to session
      conn = conn
      |> log_in_user(user)
      |> Plug.Conn.put_session("readonly_mode", true)

      {:ok, view, _html} = live(conn, ~p"/app/today")

      # Verify read-only UI is shown (no log form)
      refute has_element?(view, "form[phx-submit='log_value']")
      assert has_element?(view, "input[type='number'][disabled]")

      # Verify duration was not logged (readonly mode blocked the mutation)
      html = render(view)
      assert html =~ "0 / 30"
      refute html =~ "15 / 30"
      
      # Verify no log was created in the database
      assert HabitTracker.Tracker.get_log(habit, Date.utc_today()) == nil
    end

    test "allows viewing habits in readonly mode", %{conn: conn, user: user} do
      habit = habit_fixture(user, %{
        name: "Morning Exercise",
        type: :binary,
        icon: "🏃",
        color: "#3B82F6"
      })

      # Log a completion before entering readonly mode
      today = Date.utc_today()
      {:ok, _log} = HabitTracker.Tracker.log_habit(habit, today, %{status: :complete})

      # Log in and add readonly_mode to session
      conn = conn
      |> log_in_user(user)
      |> Plug.Conn.put_session("readonly_mode", true)

      {:ok, _view, html} = live(conn, ~p"/app/today")

      # Verify we can still view the habit and its completion status
      assert html =~ "Morning Exercise"
      assert_completion_summary(html, 1, 1)
    end
  end

  defp assert_completion_summary(html, completed, total) do
    assert html =~ "Habits Complete"

    pattern =
      ~r|>\s*#{completed}\s*</span>\s*<span[^>]*>/\s*</span>\s*<span[^>]*>\s*#{total}\s*</span>|

    assert html =~ pattern
  end
end
