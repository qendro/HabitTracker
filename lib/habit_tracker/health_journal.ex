defmodule HabitTracker.HealthJournal do
  @moduledoc "Owned health events. Caller identity is always a user, never an attribute from a form."
  import Ecto.Query
  alias HabitTracker.Repo
  alias HabitTracker.Accounts.User
  alias HabitTracker.HealthJournal.{Entry, Time}
  def query(%User{id: id}), do: from(e in Entry, where: e.user_id == ^id)
  def get_entry!(user, id), do: query(user) |> Repo.get!(id) |> Repo.preload(:attachments)

  def list_entries(user, opts \\ []) do
    query = query(user)

    query =
      if date = opts[:from],
        do: where(query, [e], e.occurred_at >= ^Time.boundary(date, user.timezone)),
        else: query

    query =
      if date = opts[:to],
        do: where(query, [e], e.occurred_at < ^Time.boundary(Date.add(date, 1), user.timezone)),
        else: query

    query =
      if opts[:kind] in ~w(stool check_in note),
        do: where(query, [e], e.kind == ^opts[:kind]),
        else: query

    query =
      if cursor = opts[:before] do
        {dt, id} = cursor
        where(query, [e], e.occurred_at < ^dt or (e.occurred_at == ^dt and e.id < ^id))
      else
        query
      end

    query
    |> order_by([e], desc: e.occurred_at, desc: e.id)
    |> limit(^min(opts[:limit] || 30, 100))
    |> Repo.all()
    |> Repo.preload(:attachments)
  end

  def create_entry(%User{id: uid}, attrs) do
    client_id = attrs["client_entry_id"] || attrs[:client_entry_id]

    existing =
      case Ecto.UUID.cast(client_id) do
        {:ok, uuid} -> Repo.get_by(Entry, user_id: uid, client_entry_id: uuid)
        _ -> nil
      end

    if existing do
      {:ok, existing}
    else
      cs = Entry.changeset(%Entry{user_id: uid}, attrs)
      # The unique index also serializes concurrent retries.
      with {:ok, inserted} <-
             Repo.insert(cs, on_conflict: :nothing, conflict_target: [:user_id, :client_entry_id]) do
        {:ok, Repo.get_by!(Entry, user_id: uid, client_entry_id: inserted.client_entry_id)}
      end
    end
  end

  def update_entry(user, id, version, attrs) do
    entry = get_entry!(user, id)

    if to_string(entry.lock_version) != to_string(version) do
      {:error, :stale}
    else
      entry
      |> Entry.changeset(Map.drop(attrs, ["client_entry_id", :client_entry_id]))
      |> Ecto.Changeset.optimistic_lock(:lock_version)
      |> Repo.update(stale_error_field: :lock_version)
      |> case do
        {:error, %{errors: errors} = cs} ->
          if Keyword.has_key?(errors, :lock_version), do: {:error, :stale}, else: {:error, cs}

        result ->
          result
      end
    end
  end

  def delete_entry(user, id) do
    Repo.transaction(fn ->
      entry =
        query(user)
        |> where([e], e.id == ^id)
        |> lock("FOR UPDATE")
        |> Repo.one!()
        |> Repo.preload(:attachments)

      entry.attachments
      |> Enum.reject(&(&1.state == "deleting"))
      |> Enum.each(&HabitTracker.Media.delete_attachment(user, &1.id))

      Repo.delete!(entry)
    end)
  end
end
