defmodule HabitTrackerWeb.UserRegistrationController do
  use HabitTrackerWeb, :controller

  alias HabitTracker.Accounts
  alias HabitTrackerWeb.RateLimiter

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%Accounts.User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    client_ip = get_client_ip(conn)

    case RateLimiter.check_registration(client_ip) do
      :deny ->
        conn
        |> put_flash(:error, "Too many registration attempts. Please try again later.")
        |> redirect(to: ~p"/users/register")

      :allow ->
        # Add default timezone if not provided
        user_params = Map.put_new(user_params, "timezone", "UTC")

        case Accounts.register_user(user_params) do
          {:ok, user} ->
            {:ok, _} =
              Accounts.deliver_user_confirmation_instructions(
                user,
                &url(~p"/users/confirm/#{&1}")
              )

            conn
            |> put_flash(
              :info,
              "Account created successfully! Please check #{user.email} for a confirmation link."
            )
            |> redirect(to: ~p"/users/log-in")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, :new, changeset: changeset)
        end
    end
  end

  defp get_client_ip(conn) do
    case Plug.Conn.get_peer_data(conn) do
      %{address: address} -> address |> :inet.ntoa() |> to_string()
      _ -> nil
    end
  end
end
