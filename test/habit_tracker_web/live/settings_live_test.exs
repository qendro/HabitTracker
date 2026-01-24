defmodule HabitTrackerWeb.SettingsLiveTest do
  use HabitTrackerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HabitTracker.AccountsFixtures

  describe "SettingsLive" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "displays settings page", %{conn: conn, user: user} do
      {:ok, _view, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/settings")

      assert html =~ "Settings"
      assert html =~ "Timezone"
      assert html =~ "Theme"
      assert html =~ "Danger Zone"
    end

    test "updates timezone", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/settings")

      assert view
             |> form("#timezone-form", user: %{timezone: "America/New_York"})
             |> render_submit()

      assert render(view) =~ "Timezone updated successfully"
    end

    test "updates theme", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/settings")

      view
      |> element("input[value='dark']")
      |> render_click()

      assert render(view) =~ "Theme updated successfully"
    end

    test "shows deletion confirmation modal", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/settings")

      refute render(view) =~ "Confirm Account Deletion"

      view
      |> element("button", "Delete Account")
      |> render_click()

      assert render(view) =~ "Confirm Account Deletion"
      assert render(view) =~ "Are you absolutely sure"
    end

    test "cancels deletion", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/settings")

      view
      |> element("button", "Delete Account")
      |> render_click()

      assert render(view) =~ "Confirm Account Deletion"

      view
      |> element("button", "Cancel")
      |> render_click()

      refute render(view) =~ "Confirm Account Deletion"
    end

    test "deletes account", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/app/settings")

      view
      |> element("button", "Delete Account")
      |> render_click()

      view
      |> element("button", "Yes, Delete My Account")
      |> render_click()

      # Verify user is redirected to logout
      assert_redirect(view, ~p"/users/log-out")

      # Verify user is soft deleted
      deleted_user = HabitTracker.Accounts.get_user!(user.id)
      assert deleted_user.deleted_at != nil
    end

    test "deleted user cannot log in", %{user: user} do
      # Soft delete the user
      {:ok, _deleted_user} = HabitTracker.Accounts.soft_delete_user(user)

      # Attempt to log in
      result = HabitTracker.Accounts.get_user_by_email_and_password(user.email, "password123")

      assert result == nil
    end
  end
end
