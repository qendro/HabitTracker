defmodule HabitTrackerWeb.UserRegistrationController do
  use HabitTrackerWeb, :controller

  alias HabitTracker.Accounts
  alias HabitTracker.Security
  alias HabitTrackerWeb.RateLimiter

  require Logger

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%Accounts.User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    client_ip = Security.get_client_ip(conn)

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
            case Accounts.deliver_user_confirmation_instructions(
                   user,
                   &url(~p"/users/confirm/#{&1}")
                 ) do
              {:ok, _} ->
                conn
                |> put_flash(
                  :info,
                  "Account created successfully! Please check #{user.email} for a confirmation link."
                )
                |> redirect(to: ~p"/users/log-in")

              {:error, reason} ->
                Logger.error("Failed to send confirmation email",
                  user_id: user.id,
                  email: user.email,
                  reason: inspect(reason)
                )

                conn
                |> put_flash(
                  :error,
                  "Account created, but we couldn't send the confirmation email. Please try again later."
                )
                |> redirect(to: ~p"/users/log-in")
            end

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, :new, changeset: changeset)
        end
    end
  end
end
