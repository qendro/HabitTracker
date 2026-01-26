defmodule HabitTracker.Journal do
  @moduledoc """
  Journal context for daily entries.
  """

  alias HabitTracker.Accounts.User
  alias HabitTracker.Journal.JournalEntry
  alias HabitTracker.Repo

  def get_entry_for_date(%User{} = user, %Date{} = local_date) do
    Repo.get_by(JournalEntry, user_id: user.id, local_date: local_date)
  end

  def upsert_entry(%User{} = user, local_date, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope),
         {:ok, local_date} <- normalize_local_date(local_date, user.timezone) do
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

  defp today_in_timezone(timezone) do
    case DateTime.shift_zone(DateTime.utc_now(:second), timezone) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> DateTime.utc_now(:second) |> DateTime.to_date()
    end
  end

  defp normalize_local_date(%Date{} = date, _timezone), do: {:ok, date}

  defp normalize_local_date(%DateTime{} = dt, timezone) do
    case DateTime.shift_zone(dt, timezone) do
      {:ok, shifted} -> {:ok, DateTime.to_date(shifted)}
      _ -> {:ok, DateTime.to_date(dt)}
    end
  end

  defp normalize_local_date(%NaiveDateTime{} = dt, timezone) do
    case DateTime.from_naive(dt, timezone) do
      {:ok, zoned} -> {:ok, DateTime.to_date(zoned)}
      _ -> {:ok, NaiveDateTime.to_date(dt)}
    end
  end

  defp normalize_local_date(date, _timezone) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> {:error, :invalid_date}
    end
  end

  defp normalize_local_date(nil, timezone), do: {:ok, today_in_timezone(timezone)}
  defp normalize_local_date(_date, _timezone), do: {:error, :invalid_date}
end
