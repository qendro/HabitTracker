defmodule HabitTracker.Storage.Local do
  @moduledoc "Private storage, confined to generated UUID directories. Never accept paths from requests."
  def root, do: Application.fetch_env!(:habit_tracker, :media_root)

  def path(key, variant) when variant in ~w(input display.jpg thumb.jpg) do
    {:ok, ^key} = Ecto.UUID.cast(key)
    Path.join([root(), "objects", key, variant])
  end

  def prepare(key) do
    dir = Path.dirname(path(key, "input"))
    File.mkdir_p!(dir)
    File.chmod!(dir, 0o700)
  end

  def remove(key) do
    File.rm_rf(Path.dirname(path(key, "input")))
  end
end
