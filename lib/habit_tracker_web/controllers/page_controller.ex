defmodule HabitTrackerWeb.PageController do
  use HabitTrackerWeb, :controller

  def home(conn, _),
    do:
      redirect(conn,
        to: if(conn.assigns.current_scope, do: ~p"/app/today", else: ~p"/users/log-in")
      )
end
