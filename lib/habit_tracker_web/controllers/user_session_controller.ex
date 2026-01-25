defmodule HabitTrackerWeb.UserSessionController do
  use HabitTrackerWeb, :controller

  alias HabitTracker.Accounts
  alias HabitTracker.Security
  alias HabitTrackerWeb.UserAuth
  alias HabitTrackerWeb.RateLimiter

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params
    ip = Security.get_client_ip(conn)

    case RateLimiter.check_login(ip) do
      :deny ->
        Security.log_event(:rate_limit_exceeded, %{
          endpoint: "login",
          ip: ip,
          identifier: email
        })

        conn
        |> put_status(:too_many_requests)
        |> put_flash(:error, "Too many login attempts. Please try again later.")
        |> redirect(to: ~p"/users/log-in")

      :allow ->
        if user = Accounts.get_user_by_email_and_password(email, password) do
          Security.log_event(:successful_login, %{
            user_id: user.id,
            email: email,
            ip: ip
          })

          conn
          |> put_flash(:info, info)
          |> UserAuth.log_in_user(user, user_params)
        else
          # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
          Security.log_event(:failed_login, %{
            email: email,
            ip: ip,
            user_agent: Security.get_user_agent(conn)
          })

          conn
          |> put_flash(:error, "Invalid email or password")
          |> put_flash(:email, String.slice(email, 0, 160))
          |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {updated_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # Log password change
    Security.log_event(:password_changed, %{
      user_id: user.id,
      ip: Security.get_client_ip(conn)
    })

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> put_flash(:info, "Password updated successfully!")
    |> UserAuth.log_in_user(updated_user, params["user"])
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
