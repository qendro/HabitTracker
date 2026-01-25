defmodule HabitTrackerWeb.PageControllerTest do
  use HabitTrackerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/welcome"

    conn = get(conn, ~p"/welcome")
    assert html_response(conn, 200) =~ "Transform Your Life"
  end
end
