defmodule HabitTrackerWeb.AdminAuth do
  use HabitTrackerWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias HabitTracker.Admin

  @doc """
  Logs the admin in and redirects to the admin area.
  """
  def log_in_admin(conn, admin) do
    admin_return_to = get_session(conn, :admin_return_to)
    token = Admin.generate_admin_session_token(admin)

    conn
    |> renew_session()
    |> put_session(:admin_token, token)
    |> redirect(to: admin_return_to || signed_in_path(conn))
  end

  @doc """
  Logs the admin out.
  """
  def log_out_admin(conn) do
    if token = get_session(conn, :admin_token) do
      Admin.delete_admin_session_token(token)
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/admin/login")
  end

  @doc """
  Fetches the current admin from the session.
  """
  def fetch_current_admin(conn, _opts) do
    case get_session(conn, :admin_token) do
      nil ->
        assign(conn, :current_admin, nil)

      token ->
        case Admin.get_admin_by_session_token(token) do
          {admin, _token_inserted_at} -> assign(conn, :current_admin, admin)
          _ -> assign(conn, :current_admin, nil)
        end
    end
  end

  @doc """
  Redirects if the admin is already authenticated.
  """
  def redirect_if_admin_is_authenticated(conn, _opts) do
    if conn.assigns.current_admin do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Requires an authenticated admin.
  """
  def require_authenticated_admin(conn, _opts) do
    if conn.assigns.current_admin do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_admin_return_to()
      |> redirect(to: ~p"/admin/login")
      |> halt()
    end
  end

  @doc """
  Handles mounting and authenticating the current_admin in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_admin` - Assigns current_admin to socket assigns.
    * `:require_authenticated_admin` - Redirects if no admin session exists.
  """
  def on_mount(:mount_current_admin, _params, session, socket) do
    socket = mount_current_admin(socket, session)
    socket = Phoenix.Component.assign(socket, :current_scope, nil)
    {:cont, socket}
  end

  def on_mount(:require_authenticated_admin, _params, session, socket) do
    socket = mount_current_admin(socket, session)
    socket = Phoenix.Component.assign(socket, :current_scope, nil)

    if socket.assigns.current_admin do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/admin/login")

      {:halt, socket}
    end
  end

  defp mount_current_admin(socket, session) do
    Phoenix.Component.assign_new(socket, :current_admin, fn ->
      if admin_token = session["admin_token"] do
        case Admin.get_admin_by_session_token(admin_token) do
          {admin, _token_inserted_at} -> admin
          _ -> nil
        end
      end
    end)
  end

  defp maybe_store_admin_return_to(conn) do
    if conn.method == "GET" do
      put_session(conn, :admin_return_to, current_path(conn))
    else
      conn
    end
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  def signed_in_path(_conn), do: ~p"/admin"
end
