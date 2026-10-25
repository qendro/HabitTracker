defmodule HabitTrackerWeb.JournalLiveTest do
  use HabitTrackerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias HabitTracker.HealthJournal
  setup :register_and_log_in_user

  test "photo-free quick logging, editing and history", %{conn: conn, user: user} do
    {:ok, view, _} = live(conn, ~p"/app/entries/new/stool")

    view
    |> form("#entry-form", entry: %{notes: "a note", details: %{bristol: "4"}})
    |> render_submit()

    {path, _flash} = assert_redirect(view)
    assert path =~ "/app/entries/"
    [entry] = HealthJournal.list_entries(user)
    {:ok, edit, _} = live(conn, ~p"/app/entries/#{entry.id}/edit")
    edit |> form("#entry-form", entry: %{notes: "changed"}) |> render_submit()
    assert_redirect(edit)
    assert HealthJournal.get_entry!(user, entry.id).occurred_at == entry.occurred_at
    {:ok, history, html} = live(conn, ~p"/app/history")
    assert html =~ "changed"
    assert has_element?(history, "#entry-#{entry.id}")
    {:ok, _, today} = live(conn, ~p"/app/today")
    assert today =~ "changed"
  end

  test "check-in zero can be saved", %{conn: conn, user: user} do
    {:ok, view, _} = live(conn, ~p"/app/entries/new/check_in")
    view |> form("#entry-form", entry: %{details: %{bloating: "0"}}) |> render_submit()
    assert_redirect(view)
    assert [%{details: %{"bloating" => 0}}] = HealthJournal.list_entries(user)
  end

  test "private route guards and no public signup or admin", %{conn: conn} do
    assert redirect = get(build_conn(), ~p"/app/today")
    assert redirected_to(redirect) == ~p"/users/log-in"

    for path <- ["/users/register", "/admin", "/app/habits"] do
      assert get(conn, path).status == 404
    end
  end

  test "direct entry and photo IDs belonging to another user return 404", %{conn: conn} do
    other = HabitTracker.AccountsFixtures.user_fixture()
    {:ok, entry} = HealthJournal.create_entry(other, HabitTracker.HealthJournalTest.attrs())
    assert_error_sent 404, fn -> get(conn, ~p"/app/entries/#{entry.id}") end
    assert_error_sent 404, fn -> get(conn, ~p"/app/entries/#{entry.id}/edit") end

    a =
      HabitTracker.Repo.insert!(%HabitTracker.HealthJournal.Attachment{
        user_id: other.id,
        entry_id: entry.id,
        storage_key: Ecto.UUID.generate(),
        state: "ready"
      })

    assert_error_sent 404, fn -> get(conn, ~p"/attachments/#{a.id}/display.jpg") end
  end

  test "settings validate timezone", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/app/settings")

    html =
      view
      |> form("#preferences", user: %{timezone: "America/Chicago", hide_previews: "true"})
      |> render_submit()

    assert html =~ "Settings saved"
  end

  test "draft restore preserves retry ID and detects an outdated edit", %{conn: conn, user: user} do
    {:ok, entry} = HealthJournal.create_entry(user, HabitTracker.HealthJournalTest.attrs())
    {:ok, view, _} = live(conn, ~p"/app/entries/#{entry.id}/edit")
    {:ok, _} = HealthJournal.update_entry(user, entry.id, 1, %{"notes" => "another tab"})

    render_hook(view, "restore-draft", %{
      values: %{"entry[kind]" => "stool", "entry[notes]" => "draft", "entry[lock_version]" => "1"}
    })

    html = view |> form("#entry-form", entry: %{notes: "draft"}) |> render_submit()
    assert html =~ "changed in another tab"
    assert HealthJournal.get_entry!(user, entry.id).notes == "another tab"
    assert render_click(view, "reload-current") =~ "another tab"
    view |> form("#entry-form", entry: %{notes: "reviewed current version"}) |> render_submit()
    assert_redirect(view)
    assert HealthJournal.get_entry!(user, entry.id).notes == "reviewed current version"
  end

  test "photo upload stages content and attachment response is private", %{conn: conn, user: user} do
    {:ok, view, _} = live(conn, ~p"/app/entries/new/stool")
    path = Path.join(System.tmp_dir!(), Ecto.UUID.generate() <> ".png")
    {_, 0} = System.cmd("convert", ["-size", "8x8", "xc:green", path], stderr_to_stdout: true)

    image =
      file_input(view, "#entry-form", :photos, [
        %{name: "../../unsafe.png", content: File.read!(path), type: "image/png"}
      ])

    File.rm!(path)
    render_upload(image, "../../unsafe.png")
    view |> form("#entry-form") |> render_submit()
    assert_redirect(view)
    [entry] = HealthJournal.list_entries(user)
    [a] = entry.attachments
    assert a.state == "pending"
    assert :ok = HabitTracker.Media.Job.perform(%Oban.Job{args: %{"id" => a.id}})
    response = get(conn, ~p"/attachments/#{a.id}/display.jpg")
    assert response.status == 200
    assert get_resp_header(response, "cache-control") == ["private, no-store"]
  end
end
