defmodule HabitTrackerWeb.EntryFormLive do
  use HabitTrackerWeb, :live_view
  alias HabitTracker.HealthJournal
  alias HabitTracker.HealthJournal.{Entry, Time}

  def mount(params, _, socket) do
    user = socket.assigns.current_scope.user

    entry =
      if params["id"],
        do: HealthJournal.get_entry!(user, params["id"]),
        else: %Entry{
          kind: params["kind"],
          occurred_at: DateTime.utc_now(),
          event_timezone: user.timezone,
          client_entry_id: Ecto.UUID.generate()
        }

    if entry.kind not in ~w(stool check_in note), do: raise(Ecto.NoResultsError, queryable: Entry)

    values = values_for(entry)

    socket =
      socket
      |> assign(
        entry: entry,
        values: values,
        error: nil,
        restored: false,
        draft_key: "#{user.id}:#{entry.id || entry.kind}"
      )
      |> allow_upload(:photos,
        accept: ~w(.jpg .jpeg .png .heic .heif),
        max_entries: 3,
        max_file_size: Application.fetch_env!(:habit_tracker, :max_photo_bytes),
        auto_upload: true
      )

    {:ok, socket}
  end

  defp values_for(entry) do
    %{
      "kind" => entry.kind,
      "notes" => entry.notes || "",
      "local_time" => Time.input_value(entry.occurred_at, entry.event_timezone),
      "event_timezone" => entry.event_timezone,
      "client_entry_id" => entry.client_entry_id,
      "details" => entry.details,
      "lock_version" => entry.lock_version
    }
  end

  def handle_event("reload-current", _, socket) do
    entry = HealthJournal.get_entry!(socket.assigns.current_scope.user, socket.assigns.entry.id)

    socket =
      Enum.reduce(socket.assigns.uploads.photos.entries, socket, fn photo, acc ->
        cancel_upload(acc, :photos, photo.ref)
      end)

    {:noreply,
     socket
     |> assign(entry: entry, values: values_for(entry), error: nil, restored: false)
     |> push_event("draft-saved", %{})}
  end

  def handle_event("change", %{"entry" => values}, socket) do
    values =
      if values["kind"] != socket.assigns.values["kind"],
        do: Map.put(values, "details", %{}),
        else: values

    {:noreply, assign(socket, values: Map.merge(socket.assigns.values, values))}
  end

  def handle_event("restore-draft", %{"values" => flat}, socket) do
    values =
      Enum.reduce(flat, %{"details" => %{}}, fn {key, value}, acc ->
        case Regex.run(~r/^entry\[([a-z_]+)\](?:\[([a-z_]+)\])?$/, key) do
          [_, "details", field] ->
            put_in(acc, ["details", field], value)

          [_, field]
          when field in ~w(kind notes local_time event_timezone client_entry_id lock_version) ->
            Map.put(acc, field, value)

          _ ->
            acc
        end
      end)

    if values["kind"] in ~w(stool check_in note) do
      {:noreply, assign(socket, restored: true, values: Map.merge(socket.assigns.values, values))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :photos, ref)}

  def handle_event("save", %{"entry" => values}, socket),
    do: save(socket, Map.merge(socket.assigns.values, values), true)

  def handle_event("save-text", _, socket), do: save(socket, socket.assigns.values, false)

  defp save(socket, values, photos?) do
    entry = socket.assigns.entry
    # Keep full UTC precision when local time and zone have not been changed.
    result =
      if entry.id &&
           values["local_time"] == Time.input_value(entry.occurred_at, entry.event_timezone) &&
           values["event_timezone"] == entry.event_timezone do
        {:ok, entry.occurred_at}
      else
        Time.parse_local(values["local_time"], values["event_timezone"])
      end

    with {:ok, dt} <- result do
      attrs = values |> Map.put("occurred_at", dt)

      result =
        if entry.id,
          do:
            HealthJournal.update_entry(
              socket.assigns.current_scope.user,
              entry.id,
              values["lock_version"],
              attrs
            ),
          else: HealthJournal.create_entry(socket.assigns.current_scope.user, attrs)

      case result do
        {:ok, saved} ->
          results =
            if photos?,
              do:
                consume_uploaded_entries(socket, :photos, fn %{path: path}, _upload ->
                  {:ok, HabitTracker.Media.add(socket.assigns.current_scope.user, saved.id, path)}
                end),
              else: []

          message =
            cond do
              Enum.any?(results, &match?({:error, :photo_limit}, &1)) ->
                "Entry saved. Three-photo limit reached: remove an existing photo before adding another."

              Enum.any?(results, &match?({:error, _}, &1)) or not photos? ->
                "Entry saved. Reselect any unfinished photos on the edit screen."

              results == [] ->
                "Entry saved."

              true ->
                "Entry saved. Photos are processing."
            end

          {:noreply,
           socket
           |> push_event("draft-saved", %{})
           |> put_flash(:info, message)
           |> push_navigate(to: ~p"/app/entries/#{saved.id}")}

        {:error, :stale} ->
          {:noreply,
           assign(socket,
             error:
               "This entry changed in another tab. Copy any changes you want to keep, then load the current entry."
           )}

        {:error, cs} ->
          {:noreply, assign(socket, error: errors(cs))}
      end
    else
      _ ->
        {:noreply,
         assign(socket,
           error:
             "Choose a valid date/time and IANA timezone. Daylight-saving gaps or repeated times need a different time or UTC timezone."
         )}
    end
  end

  defp errors(cs),
    do: Enum.map_join(cs.errors, "; ", fn {field, {message, _}} -> "#{field}: #{message}" end)

  def ratings("stool"), do: [{"discomfort", "Discomfort (0 = none, 10 = worst)", 0..10}]

  def ratings("check_in"),
    do: [
      {"overall", "Overall feeling (1 = poor, 5 = excellent)", 1..5},
      {"bloating", "Bloating (0 = none, 10 = worst)", 0..10},
      {"discomfort", "Abdominal discomfort (0 = none, 10 = worst)", 0..10},
      {"energy", "Energy (1 = very low, 5 = very high)", 1..5},
      {"stress", "Stress (0 = none, 10 = worst)", 0..10}
    ]

  def ratings(_), do: []

  def render(assigns) do
    ~H"""
    <span id="connection-monitor" phx-hook="Connection" hidden></span>
    <h1>{if @entry.id, do: "Edit", else: "Log"} {HabitTrackerWeb.TimelineLive.label(@entry.kind)}</h1>
    <p :if={@error} role="alert">{@error}</p>
    <button
      :if={@error && @entry.id}
      type="button"
      phx-click="reload-current"
      data-confirm="Discard this draft and load the current entry?"
    >
      Discard draft and load current entry
    </button>
    <p id="draft-status" aria-live="polite">
      {if @restored,
        do: "Text draft restored. Review it before saving; reselect unfinished photos.",
        else:
          "Text drafts stay in this tab for 24 hours. Photos must be reselected after interruption."}
    </p>
    <.form
      for={%{}}
      id="entry-form"
      phx-hook="Draft"
      data-user={@current_scope.user.id}
      data-draft-key={@draft_key}
      phx-change="change"
      phx-submit="save"
    >
      <input type="hidden" name="entry[lock_version]" value={@values["lock_version"]} />
      <input type="hidden" name="entry[client_entry_id]" value={@values["client_entry_id"]} />
      <label>
        Entry type<select name="entry[kind]"><option
            :for={k <- ~w(stool check_in note)}
            value={k}
            selected={@values["kind"] == k}
          >{HabitTrackerWeb.TimelineLive.label(k)}</option></select>
      </label>
      <label>
        Date and time<input
          type="datetime-local"
          step="1"
          name="entry[local_time]"
          value={@values["local_time"]}
          required
        />
      </label>
      <label>
        Event timezone<input name="entry[event_timezone]" value={@values["event_timezone"]} required />
      </label>
      <label :if={@values["kind"] == "stool"}>
        Bristol type<select name="entry[details][bristol]">
        <option value="">Not recorded</option>
        <option
            :for={
              {v, text} <- [
                {1, "Separate hard lumps"},
                {2, "Lumpy sausage"},
                {3, "Sausage with cracks"},
                {4, "Smooth, soft sausage"},
                {5, "Soft blobs"},
                {6, "Fluffy, mushy pieces"},
                {7, "Watery"}
              ]
            }
            value={v}
            selected={to_string(@values["details"]["bristol"]) == to_string(v)}
          >{v} — {text}</option>
      </select>
      </label>
      <label :if={@values["kind"] == "stool"}>
        Urgency<select name="entry[details][urgency]"><option value="">Not recorded</option><option
            :for={v <- ~w(none mild moderate severe)}
            value={v}
            selected={@values["details"]["urgency"] == v}
          >{v}</option></select>
      </label>
      <label :for={{field, label, range} <- ratings(@values["kind"])}>
        {label}<select name={"entry[details][#{field}]"}><option value="">Not recorded</option><option
            :for={v <- range}
            value={v}
            selected={to_string(@values["details"][field]) == to_string(v)}
          >{v}</option></select>
      </label>
      <label :if={@values["kind"] == "note"}>
        Category<select name="entry[details][category]"><option
            :for={v <- ~w(general meal supplement)}
            value={v}
            selected={(@values["details"]["category"] || "general") == v}
          >{v}</option></select>
      </label>
      <label>
        Notes<textarea name="entry[notes]" maxlength="10000" rows="4">{@values["notes"]}</textarea>
      </label>
      <section :if={@values["kind"] == "stool"}>
        <h2>Optional photos</h2>
        <p>
          Choose camera or photo library. Up to 3 per entry; {div(
            Application.fetch_env!(:habit_tracker, :max_photo_bytes),
            1024 * 1024
          )} MiB each. Normalized images are retained without location metadata.
        </p>
        <.live_file_input upload={@uploads.photos} />
        <p :for={err <- upload_errors(@uploads.photos)} role="alert">
          Photo: {err}. Remove it and select a supported image.
        </p>
        <div :for={photo <- @uploads.photos.entries}>
          <.live_img_preview entry={photo} />
          <progress value={photo.progress} max="100">
            {photo.progress}%
          </progress>
          <p :for={err <- upload_errors(@uploads.photos, photo)} role="alert">
            Photo: {err}. Reselect to retry.
          </p>
          <button type="button" phx-click="cancel-upload" phx-value-ref={photo.ref}>
            Remove selected photo
          </button>
        </div>
      </section>
      <button type="submit" phx-disable-with="Saving…">Save entry</button>
      <button
        :if={@uploads.photos.entries != []}
        type="button"
        phx-click="save-text"
        phx-disable-with="Saving…"
      >
        Save text without photos
      </button>
      <.link navigate={~p"/app/today"}>Cancel</.link>
    </.form>
    """
  end
end
