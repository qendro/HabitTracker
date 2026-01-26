defmodule HabitTracker.Journal do
  @moduledoc """
  Journal context for daily entries.
  """

  alias HabitTracker.Accounts.User
  alias HabitTracker.Journal.JournalEntry
  alias HabitTracker.Repo
  alias HabitTracker.Tracker.Time

  def get_entry_for_date(%User{} = user, %Date{} = local_date) do
    Repo.get_by(JournalEntry, user_id: user.id, local_date: local_date)
  end

  def upsert_entry(%User{} = user, local_date, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope),
         {:ok, local_date} <- Time.normalize_local_date(local_date, user.timezone) do
      case get_entry_for_date(user, local_date) do
        nil ->
          %JournalEntry{user_id: user.id, local_date: local_date}
          |> JournalEntry.changeset(attrs)
          |> Repo.insert()

        %JournalEntry{} = entry ->
          entry
          |> JournalEntry.changeset(attrs)
          |> Repo.update()
      end
    end
  end

  def delete_entry(%JournalEntry{} = entry, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      Repo.delete(entry)
    end
  end

  def change_entry(%JournalEntry{} = entry, attrs \\ %{}) do
    JournalEntry.changeset(entry, attrs)
  end

  def blank_entry(%User{} = user, %Date{} = local_date) do
    %JournalEntry{user_id: user.id, local_date: local_date}
  end

  defp check_readonly_mode(scope) do
    if Map.get(scope, :readonly_mode, false) do
      {:error, :readonly_mode}
    else
      :ok
    end
  end
end
