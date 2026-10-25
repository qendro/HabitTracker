defmodule HabitTrackerWeb.EntryDetailLive do
  use HabitTrackerWeb, :live_view
  alias HabitTracker.{HealthJournal, Media}

  def mount(%{"id" => id}, _, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, 2000)

    {:ok,
     assign(socket,
       entry: HealthJournal.get_entry!(socket.assigns.current_scope.user, id),
       reveal: !socket.assigns.current_scope.user.hide_previews
     )}
  end

  def handle_info(:refresh, socket) do
    entry = HealthJournal.get_entry!(socket.assigns.current_scope.user, socket.assigns.entry.id)

    if Enum.any?(entry.attachments, &(&1.state == "pending")),
      do: Process.send_after(self(), :refresh, 2000)

    {:noreply, assign(socket, :entry, entry)}
  rescue
    Ecto.NoResultsError ->
      {:noreply,
       socket |> put_flash(:info, "Entry no longer exists.") |> push_navigate(to: ~p"/app/today")}
  end

  def handle_event("delete", _, socket) do
    {:ok, _} =
      HealthJournal.delete_entry(socket.assigns.current_scope.user, socket.assigns.entry.id)

    {:noreply, push_navigate(socket, to: ~p"/app/today")}
  end

  def handle_event("reveal", _, socket),
    do: {:noreply, assign(socket, :reveal, !socket.assigns.reveal)}

  def handle_event("delete-photo", %{"id" => id}, socket) do
    {:ok, _} = Media.delete_attachment(socket.assigns.current_scope.user, id)

    {:noreply,
     assign(
       socket,
       :entry,
       HealthJournal.get_entry!(socket.assigns.current_scope.user, socket.assigns.entry.id)
     )}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    case Media.retry(socket.assigns.current_scope.user, id) do
      {:ok, _} ->
        Process.send_after(self(), :refresh, 1000)

        {:noreply,
         socket
         |> assign(
           :entry,
           HealthJournal.get_entry!(socket.assigns.current_scope.user, socket.assigns.entry.id)
         )
         |> put_flash(
           :info,
           "Photo queued for retry. If it fails again, remove it and reselect a supported photo."
         )}

      _ ->
        {:noreply,
         put_flash(socket, :error, "This photo is already processing or no longer needs a retry.")}
    end
  end

  def render(assigns) do
    ~H"""
    <span id="connection-monitor" phx-hook="Connection" hidden></span>
    <Layouts.flash_group flash={@flash} />
    <h1>{HabitTrackerWeb.TimelineLive.label(@entry.kind)}</h1>
    <p>
      {Calendar.strftime(
        HabitTracker.HealthJournal.Time.local(@entry.occurred_at, @current_scope.user.timezone),
        "%B %-d, %Y at %H:%M:%S %Z"
      )}
    </p>
    <p>Entered in {@entry.event_timezone}</p>
    <dl :for={{key, value} <- Enum.sort(@entry.details)}>
      <dt>{String.replace(key, "_", " ")}</dt>
      <dd>{if is_nil(value), do: "Not recorded", else: value}</dd>
    </dl>
    <p class="notes">{@entry.notes}</p>
    <.link class="button" navigate={~p"/app/entries/#{@entry.id}/edit"}>
      Edit entry / add photos
    </.link>
    <button phx-click="delete" data-confirm="Delete this entry and all its photos?">
      Delete entry and photos
    </button>
    <button :if={@entry.attachments != []} phx-click="reveal">
      {if @reveal, do: "Hide photos", else: "Reveal photos"}
    </button>
    <article :for={photo <- Enum.reject(@entry.attachments, &(&1.state == "deleting"))}>
      <p>Photo {photo.id}: {photo.state}</p>
      <p :if={photo.state == "failed"}>
        This image could not be processed. Retry, or remove it and choose another JPEG, PNG or HEIC photo.
      </p>
      <.link
        :if={photo.state == "ready" && @reveal}
        href={~p"/attachments/#{photo.id}/display.jpg"}
        target="_blank"
      >
        <img src={~p"/attachments/#{photo.id}/display.jpg"} alt="Stool observation; open full image" />
      </.link>
      <button :if={photo.state == "failed"} phx-click="retry" phx-value-id={photo.id}>
        Retry processing
      </button>
      <button phx-click="delete-photo" phx-value-id={photo.id} data-confirm="Delete this photo?">
        Delete photo
      </button>
    </article>
    """
  end
end
