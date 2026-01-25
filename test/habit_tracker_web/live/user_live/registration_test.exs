defmodule HabitTrackerWeb.UserLive.RegistrationTest do
  use HabitTrackerWeb.ConnCase, async: true

  import HabitTracker.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      html = html_response(conn, 200)

      assert html =~ "Create your account"
      assert html =~ "Sign in"
    end

    test "renders registration page when already logged in", %{conn: conn} do
      conn =
        conn
        |> log_in_user(user_fixture())
        |> get(~p"/users/register")

      html = html_response(conn, 200)
      assert html =~ "Create your account"
    end

    test "renders errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => "with spaces", "password" => "short"}
        })

      html = html_response(conn, 200)
      assert html =~ "Oops"
      assert html =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "creates account but does not log in", %{conn: conn} do
      email = unique_user_email()
      conn = post(conn, ~p"/users/register", %{"user" => valid_user_attributes(email: email)})

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created"
      refute get_session(conn, :user_token)
    end

    test "renders errors for duplicated email", %{conn: conn} do
      user = user_fixture(%{email: "test@email.com"})

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      html = html_response(conn, 200)
      assert html =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      html = html_response(conn, 200)

      assert html =~ ~p"/users/log-in"
      assert html =~ "Sign in"
    end
  end
end
