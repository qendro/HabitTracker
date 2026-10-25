defmodule HabitTracker.Media.Job do
  use Oban.Worker, queue: :media, max_attempts: 5
  import Ecto.Query
  alias HabitTracker.{Repo, HealthJournal.Attachment}
  alias HabitTracker.Storage.Local
  @impl true
  def perform(%Oban.Job{args: %{"id" => id}}) do
    case Repo.get(Attachment, id) do
      nil ->
        :ok

      %{state: "deleting"} = a ->
        case Local.remove(a.storage_key) do
          {:ok, _} ->
            Repo.delete!(a)
            :ok

          _ ->
            {:error, :cleanup_failed}
        end

      %{state: "ready"} = a ->
        File.rm(Local.path(a.storage_key, "input"))
        :ok

      a ->
        process(a)
    end
  end

  defp process(a) do
    # Hold a row lock through processing so concurrent deletion cannot revive a tombstone.
    Repo.transaction(
      fn ->
        a = Repo.one!(from row in Attachment, where: row.id == ^a.id, lock: "FOR UPDATE")

        if a.state in ["pending", "failed"] do
          case normalize(a.storage_key) do
            {:ok, attrs} ->
              Repo.update!(Ecto.Changeset.change(a, attrs ++ [state: "ready"]))

            {:error, _} ->
              Repo.update!(Ecto.Changeset.change(a, state: "failed"))
          end
        end
      end,
      timeout: 400_000
    )

    # Never remove the staged source before the ready transaction has committed.
    if Repo.get!(Attachment, a.id).state == "ready",
      do: File.rm(Local.path(a.storage_key, "input"))

    :ok
  end

  def normalize(key) do
    input = Local.path(key, "input")

    with {:ok, stat} <- File.stat(input),
         true <- stat.size <= Application.fetch_env!(:habit_tracker, :max_photo_bytes),
         true <- supported?(input),
         {info, 0} <- command("identify", ["-ping", "-format", "%m %w %h\n", input <> "[0]"]),
         [format, width, height] <- String.split(info),
         true <- format in ~w(JPEG PNG HEIC),
         {w, ""} <- Integer.parse(width),
         {h, ""} <- Integer.parse(height),
         true <- w * h <= Application.fetch_env!(:habit_tracker, :max_photo_pixels),
         {_, 0} <-
           command("convert", [
             input <> "[0]",
             "-auto-orient",
             "-strip",
             "-resize",
             "4096x4096>",
             "-quality",
             "92",
             Local.path(key, "display.jpg")
           ]),
         {_, 0} <-
           command("convert", [
             Local.path(key, "display.jpg"),
             "-thumbnail",
             "360x360>",
             "-strip",
             Local.path(key, "thumb.jpg")
           ]),
         {dimensions, 0} <-
           command("identify", ["-format", "%w %h", Local.path(key, "display.jpg")]) do
      [dw, dh] = String.split(dimensions) |> Enum.map(&String.to_integer/1)
      data = File.read!(Local.path(key, "display.jpg"))

      {:ok,
       [
         content_type: "image/jpeg",
         byte_size: byte_size(data),
         width: dw,
         height: dh,
         checksum: Base.encode16(:crypto.hash(:sha256, data), case: :lower)
       ]}
    else
      _ -> {:error, :invalid_image}
    end
  rescue
    _ -> {:error, :processing_failed}
  end

  defp command(cmd, args) do
    System.cmd(
      "timeout",
      [
        "90",
        cmd,
        "-limit",
        "memory",
        "128MiB",
        "-limit",
        "map",
        "256MiB",
        "-limit",
        "disk",
        "512MiB",
        "-limit",
        "thread",
        "1"
      ] ++ args,
      stderr_to_stdout: true,
      env: [{"MAGICK_THREAD_LIMIT", "1"}]
    )
  end

  defp supported?(path) do
    File.open!(path, [:read, :binary], fn file ->
      case IO.binread(file, 32) do
        <<255, 216, 255, _::binary>> ->
          true

        <<137, 80, 78, 71, 13, 10, 26, 10, _::binary>> ->
          true

        <<_size::32, "ftyp", brand::binary-size(4), _::binary>> ->
          brand in ~w(heic heix hevc hevx mif1 msf1)

        _ ->
          false
      end
    end)
  end
end
