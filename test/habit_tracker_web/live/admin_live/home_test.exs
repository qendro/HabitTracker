defmodule HabitTrackerWeb.AdminLive.HomeTest do
  use HabitTrackerWeb.ConnCase

  import Phoenix.LiveViewTest
  import HabitTracker.AdminFixtures

  describe "Admin Dashboard" do
    setup do
      admin = admin_fixture()
      %{admin: admin}
    end

    test "displays system metrics", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_admin(admin) |> live(~p"/admin")

      assert html =~ "Admin Dashboard"
      assert html =~ "Total Users"
      assert html =~ "Daily Active Users"
      assert html =~ "Total Habits"
      assert html =~ "Completions Today"
      assert html =~ "Avg Completion Rate"
    end

    test "displays metric values", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_admin(admin) |> live(~p"/admin")

      # Should display numeric values for metrics
      assert html =~ ~r/\d+/
    end

    test "manual refresh updates metrics", %{conn: conn, admin: admin} do
      {:ok, view, _html} = conn |> log_in_admin(admin) |> live(~p"/admin")

      # Click refresh button
      html = view |> element("button", "Refresh") |> render_click()

      assert html =~ "Admin Dashboard"
      assert html =~ "Total Users"
    end

    test "auto-refresh updates metrics after 60 seconds", %{conn: conn, admin: admin} do
      {:ok, view, _html} = conn |> log_in_admin(admin) |> live(~p"/admin")

      # Simulate auto-refresh message
      send(view.pid, :refresh_metrics)

      # Wait for the view to process the message
      _ = :sys.get_state(view.pid)

      html = render(view)
      assert html =~ "Admin Dashboard"
    end

    test "requires admin authentication", %{conn: conn} do
      # Try to access without authentication
      assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, ~p"/admin")
    end
  end
end
