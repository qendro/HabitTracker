defmodule HabitTracker.MediaTest do
  use HabitTracker.DataCase, async: false
  import HabitTracker.AccountsFixtures
  use Oban.Testing, repo: HabitTracker.Repo
  alias HabitTracker.{Media, HealthJournal, Repo}
  alias HabitTracker.HealthJournal.Attachment
  alias HabitTracker.Storage.Local

  setup do
    user = user_fixture()
    {:ok, entry} = HealthJournal.create_entry(user, HabitTracker.HealthJournalTest.attrs())
    path = Path.join(System.tmp_dir!(), Ecto.UUID.generate() <> ".png")
    {_, 0} = System.cmd("convert", ["-size", "16x10", "xc:red", path], stderr_to_stdout: true)
    on_exit(fn -> File.rm(path) end)
    %{user: user, other: user_fixture(), entry: entry, path: path}
  end

  test "stages, processes, authorizes and deletes a normalized image", %{
    user: u,
    other: other,
    entry: e,
    path: path
  } do
    {:ok, a} = Media.add(u, e.id, path)
    assert a.state == "pending"
    assert_raise Ecto.NoResultsError, fn -> Media.attachment!(other, a.id) end
    assert_raise Ecto.NoResultsError, fn -> Media.ready_path!(u, a.id, "display.jpg") end
    assert :ok = perform_job(Media.Job, %{id: a.id})
    a = Repo.get!(Attachment, a.id)
    assert a.state == "ready"
    assert a.content_type == "image/jpeg"
    assert {a.width, a.height} == {16, 10}
    assert File.exists?(Media.ready_path!(u, a.id, "thumb.jpg"))
    assert_raise Ecto.NoResultsError, fn -> Media.ready_path!(other, a.id, "display.jpg") end
    assert_raise Ecto.NoResultsError, fn -> Media.delete_attachment(other, a.id) end
    assert {:ok, _} = HealthJournal.delete_entry(u, e.id)
    assert Repo.get!(Attachment, a.id).state == "deleting"
    assert :ok = perform_job(Media.Job, %{id: a.id})
    refute File.exists?(Local.path(a.storage_key, "display.jpg"))
    assert :ok = perform_job(Media.Job, %{id: a.id})
  end

  test "content spoofing, failure retry and photo count limits", %{user: u, entry: e, path: path} do
    File.write!(path, "this is not a PNG")
    {:ok, a} = Media.add(u, e.id, path)
    perform_job(Media.Job, %{id: a.id})
    assert Repo.get!(Attachment, a.id).state == "failed"
    assert {:ok, _} = Media.retry(u, a.id)
    {_, 0} = System.cmd("convert", ["-size", "4x4", "xc:blue", path], stderr_to_stdout: true)
    File.cp!(path, Local.path(a.storage_key, "input"))
    perform_job(Media.Job, %{id: a.id})
    assert Repo.get!(Attachment, a.id).state == "ready"
    assert {:ok, _} = Media.add(u, e.id, path)
    assert {:ok, _} = Media.add(u, e.id, path)
    assert {:error, :photo_limit} = Media.add(u, e.id, path)
    assert_raise MatchError, fn -> Local.path("../../etc/passwd", "input") end
  end

  test "HEIC codec and EXIF removal", %{user: u, entry: e, path: path} do
    heic = path <> ".heic"

    {_, 0} =
      System.cmd("convert", [path, "-set", "exif:GPSLatitude", "41", heic],
        stderr_to_stdout: true
      )

    on_exit(fn -> File.rm(heic) end)
    {:ok, a} = Media.add(u, e.id, heic)
    perform_job(Media.Job, %{id: a.id})
    assert Repo.get!(Attachment, a.id).state == "ready"
    {metadata, 0} = System.cmd("identify", ["-verbose", Local.path(a.storage_key, "display.jpg")])
    refute metadata =~ "GPSLatitude"
    refute metadata =~ "Profile-exif"
  end

  test "exports link photos, exclude another user and protect CSV formulas", %{
    user: u,
    other: other,
    entry: e,
    path: path
  } do
    {:ok, e} = HealthJournal.update_entry(u, e.id, 1, %{"notes" => "=SUM(1,2) 饭"})
    {:ok, a} = Media.add(u, e.id, path)
    perform_job(Media.Job, %{id: a.id})
    today = Date.utc_today()
    {:ok, zip} = HealthJournal.Export.build(u, Date.add(today, -1), Date.add(today, 1))
    {json, 0} = System.cmd("unzip", ["-p", zip, "entries.json"])
    assert [%{"id" => id, "attachments" => [%{"id" => aid}]}] = Jason.decode!(json)
    assert id == e.id and aid == a.id
    {csv, 0} = System.cmd("unzip", ["-p", zip, "entries.csv"])
    assert csv =~ "'=SUM(1,2) 饭"
    {photos, 0} = System.cmd("unzip", ["-l", zip])
    assert photos =~ "#{e.id}-#{a.id}.jpg"
    File.rm!(zip)
    {:ok, zip} = HealthJournal.Export.build(other, Date.add(today, -1), Date.add(today, 1))
    {json, 0} = System.cmd("unzip", ["-p", zip, "entries.json"])
    assert Jason.decode!(json) == []
    File.rm!(zip)
  end

  test "orphan cleanup stays bounded to owned UUID objects", %{user: u, entry: e, path: path} do
    {:ok, a} = Media.add(u, e.id, path)
    Repo.update!(Ecto.Changeset.change(a, updated_at: DateTime.add(DateTime.utc_now(), -7200)))
    assert :ok = perform_job(Media.Reconcile, %{})
    assert_enqueued(worker: Media.Job, args: %{id: a.id})
    key = Ecto.UUID.generate()
    Local.prepare(key)
    File.touch!(Path.dirname(Local.path(key, "input")), System.os_time(:second) - 90000)
    perform_job(Media.Reconcile, %{})
    refute File.exists?(Path.dirname(Local.path(key, "input")))
    assert File.exists?(Local.path(a.storage_key, "input"))
  end

  test "oversized bytes and pixels fail safely without losing the entry", %{
    user: u,
    entry: e,
    path: path
  } do
    huge = path <> ".huge"

    File.open!(huge, [:write], fn f ->
      :file.position(f, 26 * 1024 * 1024)
      IO.binwrite(f, <<0>>)
    end)

    on_exit(fn -> File.rm(huge) end)
    assert {:error, :too_large} = Media.add(u, e.id, huge)
    key = Ecto.UUID.generate()
    Local.prepare(key)

    {_, 0} =
      System.cmd(
        "convert",
        [
          "-size",
          "10001x6000",
          "xc:white",
          "-depth",
          "8",
          "-define",
          "png:color-type=0",
          Local.path(key, "input") <> ".png"
        ],
        stderr_to_stdout: true
      )

    File.rename!(Local.path(key, "input") <> ".png", Local.path(key, "input"))
    assert {:error, _} = Media.Job.normalize(key)
    assert HealthJournal.get_entry!(u, e.id)
    Local.remove(key)
  end
end
