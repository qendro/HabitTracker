defmodule HabitTrackerWeb.PageController do
  use HabitTrackerWeb, :controller

  def home(conn, _params) do
    # Redirect authenticated users to their today dashboard
    if conn.assigns[:current_scope] do
      redirect(conn, to: ~p"/app/today")
    else
      # Redirect unauthenticated users to login
      redirect(conn, to: ~p"/users/log-in")
    end
  end
end
