defmodule HabitTracker.Media do
  @moduledoc "Persist uploads before enqueueing. Failed rows can be retried; deletion uses durable tombstones."
  import Ecto.Query
  alias HabitTracker.{Repo, HealthJournal}
  alias HabitTracker.HealthJournal.Attachment
  alias HabitTracker.Storage.Local

  def attachment!(user, id),
    do:
      Repo.one!(
        from a in Attachment,
          where: a.id == ^id and a.user_id == ^user.id and a.state != "deleting"
      )

  def add(user, entry_id, source) do
    entry = HealthJournal.get_entry!(user, entry_id)

    Repo.transaction(fn ->
      Repo.one!(from e in HealthJournal.Entry, where: e.id == ^entry.id, lock: "FOR UPDATE")

      count =
        Repo.aggregate(
          from(a in Attachment, where: a.entry_id == ^entry.id and a.state != "deleting"),
          :count
        )

      if entry.kind != "stool" or count >= 3, do: Repo.rollback(:photo_limit)
      size = File.stat!(source).size

      if size > Application.fetch_env!(:habit_tracker, :max_photo_bytes),
        do: Repo.rollback(:too_large)

      key = Ecto.UUID.generate()
      Local.prepare(key)
      File.cp!(source, Local.path(key, "input"))
      a = Repo.insert!(%Attachment{entry_id: entry.id, user_id: user.id, storage_key: key})
      %{id: a.id} |> HabitTracker.Media.Job.new() |> Oban.insert!()
      a
    end)
  end

  def retry(user, id) do
    a = attachment!(user, id)

    if a.state == "failed" do
      Repo.transaction(fn ->
        Repo.update!(Ecto.Changeset.change(a, state: "pending"))
        %{id: a.id} |> HabitTracker.Media.Job.new() |> Oban.insert!()
      end)
    else
      {:error, :not_failed}
    end
  end

  def delete_attachment(user, id) do
    a = attachment!(user, id)

    Repo.transaction(fn ->
      Repo.update!(Ecto.Changeset.change(a, state: "deleting"))
      %{id: a.id} |> HabitTracker.Media.Job.new() |> Oban.insert!()
    end)
  end

  def ready_path!(user, id, variant) when variant in ~w(display.jpg thumb.jpg) do
    a = attachment!(user, id)
    if a.state != "ready", do: raise(Ecto.NoResultsError, queryable: Attachment)
    Local.path(a.storage_key, variant)
  end
end
