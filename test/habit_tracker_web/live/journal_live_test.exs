defmodule HabitTrackerWeb.JournalLiveTest do
  use HabitTrackerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HabitTracker.AccountsFixtures

  describe "JournalLive" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "saves a journal entry", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/journal")

      view
      |> form("#journal-form", journal_entry: %{content: "My journal entry"})
      |> render_submit()

      assert render(view) =~ "My journal entry"
    end

    test "navigates to previous day", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/journal")

      view
      |> element("button[phx-click='prev_day']")
      |> render_click()

      yesterday = Date.add(Date.utc_today(), -1)
      assert_patched(view, ~p"/app/journal/#{Date.to_iso8601(yesterday)}")
    end

    test "selects date from calendar picker", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/journal")

      target_date = Date.add(Date.utc_today(), 3)
      date_string = Date.to_iso8601(target_date)

      view
      |> element("input#date-picker")
      |> render_change(%{"date" => date_string})

      assert_patched(view, ~p"/app/journal/#{date_string}")
    end

    test "deletes a journal entry", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/journal")

      view
      |> form("#journal-form", journal_entry: %{content: "Entry to delete"})
      |> render_submit()

      assert render(view) =~ "Entry to delete"

      view
      |> element("button[phx-click='delete_entry']")
      |> render_click("Delete this journal entry?")

      refute render(view) =~ "Entry to delete"
    end
  end
end
