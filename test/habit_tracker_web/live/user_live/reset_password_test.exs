defmodule HabitTrackerWeb.UserLive.ResetPasswordTest do
  use HabitTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HabitTracker.AccountsFixtures

  alias HabitTracker.Accounts
  alias HabitTracker.Accounts.UserToken
  alias HabitTracker.Repo

  describe "reset password request" do
    test "renders reset password request page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password")

      assert html =~ "Reset your password"
      assert html =~ "Send reset instructions"
    end

    test "sends reset instructions when user exists", %{conn: conn} do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        form(lv, "#reset_password_request_form", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "reset instructions"
      assert Repo.get_by(UserToken, user_id: user.id, context: "reset_password")
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        form(lv, "#reset_password_request_form", user: %{email: "missing@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "reset instructions"
    end
  end

  describe "reset password" do
    test "resets the password with a valid token", %{conn: conn} do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      form =
        form(lv, "#reset_password_form", %{
          "user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Password reset successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "redirects for invalid token", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/users/reset-password/invalid-token")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/reset-password"
      assert %{"error" => message} = flash
      assert message =~ "Reset link is invalid"
    end
  end
end
