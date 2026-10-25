defmodule HabitTrackerWeb.AuthTest do
  use HabitTrackerWeb.ConnCase, async: true
  import HabitTracker.AccountsFixtures
  alias HabitTracker.Accounts

  test "login renews session, remembers user, logout revokes token", %{conn: conn} do
    u = user_fixture()

    conn =
      post(conn, ~p"/users/log-in",
        user: %{email: u.email, password: valid_user_password(), remember_me: "true"}
      )

    assert redirected_to(conn) == ~p"/app/today"
    token = get_session(conn, :user_token)
    assert Accounts.get_user_by_session_token(token)
    assert conn.resp_cookies["_habit_tracker_web_user_remember_me"].max_age == 2_592_000
    conn = delete(recycle(conn), ~p"/users/log-out")
    refute Accounts.get_user_by_session_token(token)
    refute get_session(conn, :user_token)
  end

  test "invalid password cannot login; password change revokes sessions", %{conn: conn} do
    u = user_fixture()
    denied = post(conn, ~p"/users/log-in", user: %{email: u.email, password: "wrong"})
    refute get_session(denied, :user_token)
    token = Accounts.generate_user_session_token(u)
    logged = log_in_user(recycle(conn), u)

    updated =
      post(logged, ~p"/users/update-password",
        user: %{
          current_password: valid_user_password(),
          password: "new valid password",
          password_confirmation: "new valid password"
        }
      )

    assert redirected_to(updated) == ~p"/app/today"
    refute Accounts.get_user_by_session_token(token)
    assert Accounts.get_user_by_email_and_password(u.email, "new valid password")
  end

  test "missing owner recovery cannot expose account information", %{conn: conn} do
    assert get(conn, "/users/reset-password").status == 404
  end

  test "changing password requires the current password", %{conn: conn} do
    u = user_fixture()
    token = Accounts.generate_user_session_token(u)

    denied =
      post(log_in_user(conn, u), ~p"/users/update-password",
        user: %{
          current_password: "wrong",
          password: "new password",
          password_confirmation: "new password"
        }
      )

    assert redirected_to(denied) == ~p"/app/settings"
    assert Accounts.get_user_by_session_token(token)
    assert Accounts.get_user_by_email_and_password(u.email, valid_user_password())
  end
end
