defmodule HabitTracker.HealthJournalTest do
  use HabitTracker.DataCase, async: true
  alias HabitTracker.HealthJournal, as: HJ
  alias HabitTracker.HealthJournal.{Entry, Time}
  import HabitTracker.AccountsFixtures

  setup do
    %{user: user_fixture(), other: user_fixture()}
  end

  def attrs(kind \\ "stool", extra \\ %{}) do
    Map.merge(
      %{
        "kind" => kind,
        "event_timezone" => "America/Chicago",
        "occurred_at" => DateTime.utc_now(),
        "client_entry_id" => Ecto.UUID.generate(),
        "details" => %{}
      },
      extra
    )
  end

  test "multiple same-day events and retries are independent and immutable", %{user: u} do
    a = attrs()
    assert {:ok, e1} = HJ.create_entry(u, a)
    assert {:ok, e2} = HJ.create_entry(u, attrs())
    assert e1.id != e2.id
    assert {:ok, retry} = HJ.create_entry(u, Map.put(a, "notes", "different content"))
    assert retry.id == e1.id
    assert retry.notes == nil
    assert length(HJ.list_entries(u)) == 2

    for _ <- 1..2,
        do:
          assert(
            {:ok, _} = HJ.create_entry(u, attrs("check_in", %{"details" => %{"stress" => 0}}))
          )

    assert length(HJ.list_entries(u)) == 4
  end

  test "all queries and mutations enforce ownership", %{user: u, other: other} do
    {:ok, e} = HJ.create_entry(u, attrs())
    assert HJ.list_entries(other) == []
    assert_raise Ecto.NoResultsError, fn -> HJ.get_entry!(other, e.id) end
    assert_raise Ecto.NoResultsError, fn -> HJ.update_entry(other, e.id, 1, %{}) end
    assert_raise Ecto.NoResultsError, fn -> HJ.delete_entry(other, e.id) end
    assert {:ok, _} = HJ.delete_entry(u, e.id)
    assert HJ.list_entries(u) == []
  end

  test "missing differs from zero, ratings and note requirements", %{user: u} do
    assert {:error, _} = HJ.create_entry(u, attrs("check_in"))
    assert {:ok, e} = HJ.create_entry(u, attrs("check_in", %{"details" => %{"bloating" => "0"}}))
    assert e.details["bloating"] == 0
    assert e.details["energy"] == nil

    for {field, value} <- [{"bloating", -1}, {"stress", 11}, {"energy", 0}, {"overall", 6}],
        do:
          assert(
            {:error, _} = HJ.create_entry(u, attrs("check_in", %{"details" => %{field => value}}))
          )

    assert {:error, _} = HJ.create_entry(u, attrs("stool", %{"details" => %{"bristol" => 8}}))
    assert {:error, _} = HJ.create_entry(u, attrs("stool", %{"details" => %{"energy" => 1}}))

    assert {:error, _} =
             HJ.create_entry(
               u,
               attrs("note", %{"notes" => "   ", "details" => %{"category" => "general"}})
             )

    assert {:ok, _} =
             HJ.create_entry(
               u,
               attrs("note", %{"notes" => "饭 💚", "details" => %{"category" => "meal"}})
             )

    assert {:error, _} = HJ.create_entry(u, attrs("invalid"))
    assert {:error, _} = HJ.create_entry(u, attrs("stool", %{"event_timezone" => "Mars/Local"}))

    assert {:error, _} =
             HJ.create_entry(
               u,
               attrs("stool", %{"occurred_at" => DateTime.add(DateTime.utc_now(), 180)})
             )

    assert {:ok, _} =
             HJ.create_entry(
               u,
               attrs("stool", %{"occurred_at" => DateTime.add(DateTime.utc_now(), 60)})
             )

    assert {:error, _} =
             HJ.create_entry(u, attrs("stool", %{"notes" => String.duplicate("a", 10001)}))
  end

  test "backdating, local day filtering, stable pagination and stale writes", %{user: u} do
    {:ok, u} = HabitTracker.Accounts.update_user_timezone(u, %{timezone: "America/Chicago"})

    {:ok, e} =
      HJ.create_entry(u, attrs("stool", %{"occurred_at" => ~U[2026-03-08 06:00:00.123456Z]}))

    {:ok, outside} =
      HJ.create_entry(u, attrs("stool", %{"occurred_at" => ~U[2026-03-08 05:59:59Z]}))

    assert [day] = HJ.list_entries(u, from: ~D[2026-03-08], to: ~D[2026-03-08])
    assert day.id == e.id
    assert {:ok, updated} = HJ.update_entry(u, e.id, 1, %{"notes" => "edited"})
    assert updated.occurred_at == e.occurred_at
    assert updated.inserted_at != updated.occurred_at
    assert {:error, :stale} = HJ.update_entry(u, e.id, 1, %{"notes" => "overwrite"})
    assert [older] = HJ.list_entries(u, before: {e.occurred_at, e.id})
    assert older.id == outside.id
    {a, b} = Time.day_range(~D[2026-03-08], "America/Chicago")
    assert DateTime.diff(b, a, :hour) == 23
    {a, b} = Time.day_range(~D[2026-11-01], "America/Chicago")
    assert DateTime.diff(b, a, :hour) == 25
    assert {:error, _} = Time.parse_local("2026-03-08T02:30:00", "America/Chicago")
    assert {:error, _} = Time.parse_local("2026-11-01T01:30:00", "America/Chicago")
  end

  test "private fields redact schema inspection" do
    refute inspect(%Entry{notes: "secret-notes", details: %{"stress" => 7}}) =~ "secret-notes"

    assert HabitTracker.Privacy.filter(%{msg: {:report, %{socket: "secret"}}, meta: %{}}, nil).msg ==
             {:string, ~c"Runtime report omitted to protect private journal data"}

    assert Application.fetch_env!(:phoenix, :filter_parameters) == {:keep, []}
  end

  test "pagination uses ID to break ties and retry IDs are scoped to users", %{
    user: u,
    other: other
  } do
    time = DateTime.utc_now()

    entries =
      for _ <- 1..31 do
        {:ok, e} = HJ.create_entry(u, attrs("stool", %{"occurred_at" => time}))
        e
      end

    page = HJ.list_entries(u)
    assert length(page) == 30
    last = List.last(page)
    assert [oldest] = HJ.list_entries(u, before: {last.occurred_at, last.id})
    assert oldest.id == hd(entries).id
    e = hd(entries)

    assert {:ok, independent} =
             HJ.create_entry(other, attrs("stool", %{"client_entry_id" => e.client_entry_id}))

    assert independent.user_id == other.id

    assert {:ok, retried} =
             HJ.create_entry(u, %{"client_entry_id" => e.client_entry_id, "kind" => "invalid"})

    assert retried.id == e.id
  end
end
