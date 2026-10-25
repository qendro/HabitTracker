defmodule HabitTracker.Media.Reconcile do
  use Oban.Worker, queue: :media, max_attempts: 3
  import Ecto.Query
  alias HabitTracker.{Repo, HealthJournal.Attachment}
  alias HabitTracker.Storage.Local
  @impl true
  def perform(_) do
    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)

    Repo.all(
      from a in Attachment,
        where: a.state in ["pending", "deleting"] and a.updated_at < ^cutoff,
        limit: 100
    )
    |> Enum.each(fn a -> %{id: a.id} |> HabitTracker.Media.Job.new() |> Oban.insert!() end)

    # Bounded per run, only UUID directories under this app's objects root.
    paths = Path.wildcard(Path.join([Local.root(), "objects", "*"]))
    cursor_path = Path.join(Local.root(), ".reconcile-cursor")

    cursor =
      case File.read(cursor_path) do
        {:ok, value} -> value
        _ -> ""
      end

    remaining = Enum.filter(paths, &(Path.basename(&1) > cursor))

    batch =
      if length(paths) <= 1000 or remaining == [],
        do: Enum.take(paths, 1000),
        else: Enum.take(remaining, 1000)

    if batch != [], do: File.write!(cursor_path, Path.basename(List.last(batch)))

    batch
    |> Enum.each(fn path ->
      key = Path.basename(path)

      with {:ok, ^key} <- Ecto.UUID.cast(key),
           {:ok, stat} <- File.stat(path, time: :posix),
           true <- stat.mtime < System.os_time(:second) - 86400,
           nil <- Repo.get_by(Attachment, storage_key: key) do
        Local.remove(key)
      else
        _ -> :ok
      end
    end)

    HabitTracker.HealthJournal.Export.expire()
    :ok
  end
end
