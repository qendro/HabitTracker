defmodule HabitTrackerWeb.UserLive.ConfirmationTest do
  use HabitTrackerWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import HabitTracker.AccountsFixtures

  alias HabitTracker.Accounts
  alias HabitTracker.Accounts.UserToken
  alias HabitTracker.Repo

  describe "Confirm user" do
    test "confirms the user with a valid token", %{conn: conn} do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/confirm/#{token}")

      assert html =~ "Account confirmed"
      assert Accounts.get_user!(user.id).confirmed_at
    end

    test "shows error for invalid token", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm/invalid-token")
      assert html =~ "Confirmation link invalid"
    end

    test "shows error for expired token", %{conn: conn} do
      user = unconfirmed_user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {1, nil} = Repo.update_all(from(t in UserToken, where: t.user_id == ^user.id and t.context == "confirm"), set: [inserted_at: ~N[2020-01-01 00:00:00]])

      {:ok, _lv, html} = live(conn, ~p"/users/confirm/#{token}")
      assert html =~ "Confirmation link invalid"
    end
  end
end
