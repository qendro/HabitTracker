defmodule HabitTracker.JournalFixtures do
  @moduledoc """
  This module defines test helpers for creating journal entries.
  """

  alias HabitTracker.AccountsFixtures
  alias HabitTracker.Journal

  def valid_journal_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      content: "Today I made progress on my habits."
    })
  end

  def journal_entry_fixture(
        user \\ AccountsFixtures.user_fixture(),
        date \\ Date.utc_today(),
        attrs \\ %{}
      ) do
    {:ok, entry} = Journal.upsert_entry(user, date, valid_journal_attributes(attrs))
    entry
  end
end
