defmodule HabitTrackerWeb.AdminSessionController do
  use HabitTrackerWeb, :controller

  alias HabitTracker.Admin
  alias HabitTracker.Security
  alias HabitTrackerWeb.AdminAuth

  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    ip = Security.get_client_ip(conn)

    if admin = Admin.get_admin_by_email_and_password(email, password) do
      Security.log_event(:successful_login, %{
        user_id: admin.id,
        email: email,
        ip: ip
      })

      AdminAuth.log_in_admin(conn, admin)
    else
      Security.log_event(:failed_login, %{
        email: email,
        ip: ip,
        user_agent: Security.get_user_agent(conn)
      })

      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.trim(email))
      |> redirect(to: ~p"/admin/login")
    end
  end

  def delete(conn, _params) do
    AdminAuth.log_out_admin(conn)
  end

  def stop_impersonation(conn, _params) do
    # Get the impersonated user ID before clearing session
    impersonating_user_id = get_session(conn, :impersonating_user_id)

    # Log the impersonation end
    if admin = conn.assigns[:current_scope][:admin] do
      Admin.log_impersonation_end(admin, impersonating_user_id)
    end

    # Clear impersonation state
    conn
    |> delete_session(:impersonating_user_id)
    |> delete_session(:readonly_mode)
    |> put_flash(:info, "Stopped viewing as user")
    |> redirect(to: ~p"/admin/users/#{impersonating_user_id}")
  end
end
