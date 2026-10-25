defmodule HabitTrackerWeb.DownloadController do
  use HabitTrackerWeb, :controller

  def photo(conn, %{"id" => id, "variant" => variant})
      when variant in ~w(display.jpg thumb.jpg) do
    path = HabitTracker.Media.ready_path!(conn.assigns.current_scope.user, id, variant)

    conn
    |> put_resp_header("cache-control", "private, no-store")
    |> put_resp_content_type("image/jpeg")
    |> send_file(200, path)
  end

  def photo(conn, _), do: send_resp(conn, 404, "Not found")

  def export(conn, params) do
    with {:ok, from} <- Date.from_iso8601(params["from"] || ""),
         {:ok, to} <- Date.from_iso8601(params["to"] || ""),
         true <- Date.compare(from, to) != :gt,
         {:ok, path} <-
           HabitTracker.HealthJournal.Export.build(conn.assigns.current_scope.user, from, to) do
      try do
        conn
        |> put_resp_header("cache-control", "private, no-store")
        |> send_download({:file, path}, filename: "health-journal.zip")
      after
        File.rm(path)
      end
    else
      _ -> send_resp(conn, 422, "Choose a valid date range.")
    end
  end
end
