defmodule HabitTracker.JournalTest do
  use HabitTracker.DataCase

  alias HabitTracker.Journal
  alias HabitTracker.Journal.JournalEntry

  import HabitTracker.AccountsFixtures

  describe "journal entries" do
    test "upsert_entry creates and updates entries" do
      user = user_fixture()
      date = ~D[2026-01-02]

      assert {:ok, entry} = Journal.upsert_entry(user, date, %{content: "Hello world"})
      assert entry.local_date == date
      assert entry.word_count == 2

      assert {:ok, updated} = Journal.upsert_entry(user, date, %{content: "New content here"})
      assert updated.id == entry.id
      assert updated.word_count == 3
    end

    test "upsert_entry validates max word count" do
      user = user_fixture()
      date = ~D[2026-01-03]
      max_words = JournalEntry.max_words()
      content = Enum.map_join(1..(max_words + 1), " ", fn _ -> "word" end)

      assert {:error, changeset} = Journal.upsert_entry(user, date, %{content: content})
      assert "must be #{max_words} words or less" in errors_on(changeset).content
    end

    test "delete_entry removes entry" do
      user = user_fixture()
      date = ~D[2026-01-04]

      {:ok, entry} = Journal.upsert_entry(user, date, %{content: "Delete me"})
      assert {:ok, _} = Journal.delete_entry(entry)
      assert Journal.get_entry_for_date(user, date) == nil
    end
  end
end
