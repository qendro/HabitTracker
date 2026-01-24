defmodule HabitTrackerWeb.AdminAuthTest do
  use HabitTrackerWeb.ConnCase, async: true

  import HabitTracker.AccountsFixtures
  import HabitTracker.AdminFixtures

  alias HabitTracker.Admin

  describe "admin login" do
    test "admin login succeeds with valid credentials", %{conn: conn} do
      admin = admin_fixture()

      conn =
        post(conn, ~p"/admin/log-in", %{
          "admin" => %{"email" => admin.email, "password" => valid_admin_password()}
        })

      assert redirected_to(conn) == ~p"/admin"
      assert admin_token = get_session(conn, :admin_token)
      assert {logged_in_admin, _} = Admin.get_admin_by_session_token(admin_token)
      assert logged_in_admin.id == admin.id
    end
  end

  test "admin cannot access user routes", %{conn: conn} do
    admin = admin_fixture()

    conn =
      post(conn, ~p"/admin/log-in", %{
        "admin" => %{"email" => admin.email, "password" => valid_admin_password()}
      })

    conn = get(conn, ~p"/users/settings")

    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "user cannot access admin routes", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    conn = get(conn, ~p"/admin")

    assert redirected_to(conn) == ~p"/admin/login"
  end

  test "user credentials do not create admin session", %{conn: conn} do
    user = user_fixture()

    conn =
      post(conn, ~p"/admin/log-in", %{
        "admin" => %{"email" => user.email, "password" => valid_user_password()}
      })

    assert redirected_to(conn) == ~p"/admin/login"
    refute get_session(conn, :admin_token)
  end
end
