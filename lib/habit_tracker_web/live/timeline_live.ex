defmodule HabitTrackerWeb.TimelineLive do
  use HabitTrackerWeb, :live_view
  alias HabitTracker.HealthJournal
  alias HabitTracker.HealthJournal.Time
  def mount(_, _, socket), do: {:ok, assign(socket, entries: [], filters: %{}, cursor: nil)}

  def handle_params(params, _, socket) do
    user = socket.assigns.current_scope.user
    today = Time.today(user.timezone)

    filters =
      if socket.assigns.live_action == :today,
        do: %{"from" => Date.to_iso8601(today), "to" => Date.to_iso8601(today), "kind" => ""},
        else: Map.take(params, ~w(from to kind))

    {:noreply, load(assign(socket, filters: filters, today: today), nil)}
  end

  def handle_event("filter", params, socket),
    do: {:noreply, push_patch(socket, to: ~p"/app/history?#{Map.take(params, ~w(from to kind))}")}

  def handle_event("next", _, socket), do: {:noreply, load(socket, socket.assigns.cursor)}

  defp load(socket, cursor) do
    f = socket.assigns.filters
    opts = [from: date(f["from"]), to: date(f["to"]), kind: f["kind"], before: cursor]
    entries = HealthJournal.list_entries(socket.assigns.current_scope.user, opts)
    last = List.last(entries)

    assign(socket,
      entries: entries,
      cursor: if(last, do: {last.occurred_at, last.id}),
      more: length(entries) == 30
    )
  end

  defp date(value) do
    case Date.from_iso8601(value || "") do
      {:ok, date} -> date
      _ -> nil
    end
  end

  def label("stool"), do: "Stool"
  def label("check_in"), do: "How I feel"
  def label("note"), do: "Note"

  def summary(e) do
    e.details
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.sort()
    |> Enum.map_join(" · ", fn {k, v} -> "#{String.replace(k, "_", " ")}: #{v}" end)
  end

  def render(assigns) do
    ~H"""
    <span id="connection-monitor" phx-hook="Connection" hidden></span>
    <Layouts.flash_group flash={@flash} />
    <h1>{if @live_action == :today, do: "Today", else: "History"}</h1>
    <p :if={@live_action == :today}>{Calendar.strftime(@today, "%A, %B %-d, %Y")}</p>
    <div class="actions">
      <.link class="button" navigate={~p"/app/entries/new/stool"}>Log stool</.link>
      <.link class="button" navigate={~p"/app/entries/new/check_in"}>How I feel</.link>
      <.link navigate={~p"/app/entries/new/note"}>Add note</.link>
    </div>
    <.form :if={@live_action == :history} for={%{}} phx-submit="filter" id="history-filter">
      <label>From<input type="date" name="from" value={@filters["from"]} /></label>
      <label>Through<input type="date" name="to" value={@filters["to"]} /></label>
      <label>
        Type<select name="kind"><option value="">All entries</option><option
            :for={kind <- ~w(stool check_in note)}
            value={kind}
            selected={@filters["kind"] == kind}
          >{label(kind)}</option></select>
      </label>
      <button>Filter history</button>
    </.form>
    <p :if={@entries == []}>No entries logged.</p>
    <article :for={entry <- @entries} id={"entry-#{entry.id}"}>
      <.link navigate={~p"/app/entries/#{entry.id}"}>
        <strong>{label(entry.kind)}</strong>
        <time datetime={DateTime.to_iso8601(entry.occurred_at)}>
          {Calendar.strftime(
            Time.local(entry.occurred_at, @current_scope.user.timezone),
            "%b %-d, %H:%M"
          )}
        </time>
        <p>{summary(entry)}</p>
        <p class="preview">{entry.notes}</p>
        <span :if={Enum.any?(entry.attachments, &(&1.state == "ready"))}>Photo attached</span>
        <img
          :for={photo <- Enum.filter(entry.attachments, &(&1.state == "ready")) |> Enum.take(1)}
          :if={!@current_scope.user.hide_previews}
          src={~p"/attachments/#{photo.id}/thumb.jpg"}
          loading="lazy"
          alt="Stool observation thumbnail"
        />
      </.link>
    </article>
    <button :if={@more} phx-click="next">Older entries</button>
    """
  end
end
