defmodule HabitTrackerWeb.AdminLive.ResetPasswordTest do
  use HabitTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HabitTracker.AdminFixtures

  alias HabitTracker.Admin
  alias HabitTracker.Admin.AdminToken
  alias HabitTracker.Repo

  describe "reset password request" do
    test "renders reset password request page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/reset-password")

      assert html =~ "Reset your admin password"
      assert html =~ "Send reset instructions"
    end

    test "sends reset instructions when admin exists", %{conn: conn} do
      admin = admin_fixture()
      {:ok, lv, _html} = live(conn, ~p"/admin/reset-password")

      {:ok, _lv, html} =
        form(lv, "#admin_reset_password_request_form", admin: %{email: admin.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/admin/login")

      assert html =~ "reset instructions"
      assert Repo.get_by(AdminToken, admin_id: admin.id, context: "reset_password")
    end

    test "does not disclose if admin is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/reset-password")

      {:ok, _lv, html} =
        form(lv, "#admin_reset_password_request_form", admin: %{email: "missing@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/admin/login")

      assert html =~ "reset instructions"
    end
  end

  describe "reset password" do
    test "resets the password with a valid token", %{conn: conn} do
      admin = admin_fixture()

      token =
        extract_admin_token(fn url ->
          Admin.deliver_admin_reset_password_instructions(admin, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/admin/reset-password/#{token}")

      form =
        form(lv, "#admin_reset_password_form", %{
          "admin" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/admin/login")

      assert html =~ "Password reset successfully"
      assert Admin.get_admin_by_email_and_password(admin.email, "new valid password")
    end

    test "redirects for invalid token", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/admin/reset-password/invalid-token")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/admin/reset-password"
      assert %{"error" => message} = flash
      assert message =~ "Reset link is invalid"
    end
  end
end
