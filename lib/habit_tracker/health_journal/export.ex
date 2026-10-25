defmodule HabitTracker.HealthJournal.Export do
  @moduledoc "Disk-backed portable export; photos are copied one at a time, ZIP is never assembled in RAM."
  alias HabitTracker.{HealthJournal, Storage.Local}

  def build(user, from, to) do
    dir = Path.join([Local.root(), "exports", Ecto.UUID.generate()])
    File.mkdir_p!(dir)
    File.chmod!(dir, 0o700)

    try do
      File.write!(
        Path.join(dir, "manifest.json"),
        Jason.encode!(%{
          schema_version: 1,
          timezone: user.timezone,
          from: from,
          to: to,
          photos: "Normalized JPEGs; EXIF removed"
        })
      )

      File.open!(Path.join(dir, "entries.json"), [:write], fn json ->
        File.open!(Path.join(dir, "entries.csv"), [:write], fn csv ->
          IO.binwrite(json, "[")
          IO.binwrite(csv, "id,kind,occurred_at,event_timezone,notes,details,attachment_ids\r\n")
          export_page(user, from, to, nil, dir, json, csv, true)
          IO.binwrite(json, "]")
        end)
      end)

      {_, 0} = System.cmd("zip", ["-q", "-r", "../#{Path.basename(dir)}.zip", "."], cd: dir)
      {:ok, dir <> ".zip"}
    after
      File.rm_rf(dir)
    end
  end

  defp export_page(user, from, to, cursor, dir, json, csv, first) do
    entries = HealthJournal.list_entries(user, from: from, to: to, before: cursor, limit: 100)

    Enum.with_index(entries)
    |> Enum.each(fn {e, index} ->
      attachments = Enum.filter(e.attachments, &(&1.state == "ready"))

      photos =
        Enum.map(attachments, fn a ->
          filename = "#{e.id}-#{a.id}.jpg"
          File.cp!(Local.path(a.storage_key, "display.jpg"), Path.join(dir, filename))

          Map.take(a, [:id, :checksum, :content_type, :byte_size, :width, :height])
          |> Map.put(:filename, filename)
        end)

      row =
        Map.take(e, [
          :id,
          :kind,
          :occurred_at,
          :event_timezone,
          :notes,
          :details,
          :client_entry_id,
          :source,
          :inserted_at,
          :updated_at
        ])
        |> Map.put(:attachments, photos)

      unless first and index == 0, do: IO.binwrite(json, ",")
      IO.binwrite(json, Jason.encode!(row))

      IO.binwrite(
        csv,
        Enum.map_join(
          [
            e.id,
            e.kind,
            DateTime.to_iso8601(e.occurred_at),
            e.event_timezone,
            e.notes,
            Jason.encode!(e.details),
            Enum.map_join(attachments, ";", & &1.id)
          ],
          ",",
          &csv_cell/1
        ) <> "\r\n"
      )
    end)

    if length(entries) == 100 do
      e = List.last(entries)
      export_page(user, from, to, {e.occurred_at, e.id}, dir, json, csv, false)
    end
  end

  def csv_cell(value) do
    value = to_string(value || "")
    value = if Regex.match?(~r/^[\s]*[=+@\-\t\r]/u, value), do: "'" <> value, else: value
    "\"" <> String.replace(value, "\"", "\"\"") <> "\""
  end

  def expire do
    Path.wildcard(Path.join([Local.root(), "exports", "*"]))
    |> Enum.take(1000)
    |> Enum.each(fn path ->
      if File.stat!(path, time: :posix).mtime < System.os_time(:second) - 3600,
        do: File.rm_rf(path)
    end)
  end
end
