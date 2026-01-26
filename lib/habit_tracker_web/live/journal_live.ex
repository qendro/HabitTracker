defmodule HabitTrackerWeb.JournalLive do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Journal
  alias HabitTracker.Journal.JournalEntry
  alias HabitTrackerWeb.HabitComponents

  @impl true
  def mount(params, session, socket) do
    user = socket.assigns.current_scope.user
    timezone = user.timezone
    readonly_mode = Map.get(session, "readonly_mode", false)
    selected_date = parse_date(params["date"], timezone)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:timezone, timezone)
     |> assign(:readonly_mode, readonly_mode)
     |> assign_entry(selected_date)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_date = parse_date(params["date"], socket.assigns.timezone)

    if selected_date != socket.assigns.selected_date do
      {:noreply, assign_entry(socket, selected_date)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_day", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, -1)
    {:noreply, push_patch(socket, to: ~p"/app/journal/#{Date.to_iso8601(new_date)}")}
  end

  @impl true
  def handle_event("next_day", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, 1)
    {:noreply, push_patch(socket, to: ~p"/app/journal/#{Date.to_iso8601(new_date)}")}
  end

  @impl true
  def handle_event("back_to_today", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/journal")}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        {:noreply, push_patch(socket, to: ~p"/app/journal/#{Date.to_iso8601(date)}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid date format")}
    end
  end

  @impl true
  def handle_event("validate", %{"journal_entry" => params}, socket) do
    base_entry = base_entry(socket)

    changeset =
      base_entry
      |> Journal.change_entry(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset, as: "journal_entry"))
     |> assign(:word_count, JournalEntry.word_count(params["content"]))}
  end

  @impl true
  def handle_event("save", %{"journal_entry" => params}, socket) do
    if socket.assigns.readonly_mode do
      {:noreply, put_flash(socket, :error, "Cannot edit journal in read-only mode")}
    else
      case Journal.upsert_entry(
             socket.assigns.user,
             socket.assigns.selected_date,
             params,
             socket.assigns.current_scope
           ) do
        {:ok, entry} ->
          changeset = Journal.change_entry(entry, %{})

          {:noreply,
           socket
           |> assign(:entry, entry)
           |> assign(:form, to_form(changeset, as: "journal_entry"))
           |> assign(:word_count, entry.word_count || 0)
           |> put_flash(:info, "Journal entry saved")}

        {:error, :readonly_mode} ->
          {:noreply, put_flash(socket, :error, "Cannot edit journal in read-only mode")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(:form, to_form(Map.put(changeset, :action, :insert), as: "journal_entry"))
           |> assign(:word_count, JournalEntry.word_count(params["content"]))}
      end
    end
  end

  @impl true
  def handle_event("delete_entry", _params, socket) do
    case socket.assigns.entry do
      nil ->
        {:noreply, socket}

      entry ->
        case Journal.delete_entry(entry, socket.assigns.current_scope) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign_entry(socket.assigns.selected_date)
             |> put_flash(:info, "Journal entry deleted")}

          {:error, :readonly_mode} ->
            {:noreply, put_flash(socket, :error, "Cannot edit journal in read-only mode")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete journal entry")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 via-blue-50/30 to-cyan-50/30 app-container">
      <%!-- Subtle animated background blobs --%>
      <div class="fixed inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-0 right-0 w-96 h-96 bg-gradient-to-br from-blue-200/20 to-cyan-200/20 rounded-full blur-3xl animate-blob"></div>
        <div class="absolute bottom-0 left-0 w-80 h-80 bg-gradient-to-tr from-indigo-200/20 to-blue-200/20 rounded-full blur-3xl animate-blob animation-delay-2000"></div>
        <div class="absolute top-1/2 left-1/2 w-72 h-72 bg-gradient-to-br from-cyan-200/20 to-teal-200/20 rounded-full blur-3xl animate-blob animation-delay-4000"></div>
      </div>

      <div class="relative max-w-5xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6">
          <div>
            <h1 class="text-5xl font-extrabold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-2">
              Journal
            </h1>
            <p class="text-gray-600">A quiet space for daily reflection.</p>
          </div>
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/80 border border-gray-200 text-xs font-semibold text-gray-600 shadow-sm">
            <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
            <span><%= @timezone %></span>
          </div>
        </div>

        <HabitComponents.date_navigator
          selected_date={@selected_date}
          is_today={@is_today}
          timezone={@timezone}
        />

        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <.form id="journal-form" for={@form} phx-submit="save" phx-change="validate">
            <.input
              type="textarea"
              field={@form[:content]}
              label="Entry"
              rows="10"
              class="w-full px-5 py-4 rounded-2xl border-2 border-blue-200/70 bg-white/90 text-gray-900 focus:border-blue-500 focus:ring-4 focus:ring-blue-200 transition-all resize-y shadow-inner min-h-[220px] leading-relaxed"
              placeholder="Write your thoughts..."
              phx-debounce="300"
              readonly={@readonly_mode}
            />

            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 text-sm text-gray-500">
              <span class={if @word_count > @max_words, do: "text-red-600 font-semibold", else: ""}>
                <%= @word_count %> / <%= @max_words %> words
              </span>
              <span :if={@entry}>
                Last updated <%= format_updated_at(@entry.updated_at, @timezone) %>
              </span>
            </div>

            <div class="mt-6 flex flex-wrap items-center gap-3">
              <.button type="submit" variant="primary" disabled={@readonly_mode}>
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M17.414 2.586a2 2 0 00-2.828 0L7 10.172V13h2.828l7.586-7.586a2 2 0 000-2.828z" />
                  <path fill-rule="evenodd" d="M2 5a2 2 0 012-2h4a1 1 0 110 2H4v10h10v-4a1 1 0 112 0v4a2 2 0 01-2 2H4a2 2 0 01-2-2V5z" clip-rule="evenodd" />
                </svg>
                <%= if @entry, do: "Update Entry", else: "Save Entry" %>
              </.button>

              <.button
                :if={@entry}
                type="button"
                class="btn-danger"
                phx-click="delete_entry"
                phx-confirm="Delete this journal entry?"
                disabled={@readonly_mode}
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M6 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm6-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
                  <path fill-rule="evenodd" d="M5 4a1 1 0 00-1 1v1a1 1 0 001 1h10a1 1 0 001-1V5a1 1 0 00-1-1h-2.5l-.71-.71a1 1 0 00-.7-.29h-2.18a1 1 0 00-.7.29L8.5 4H5zm1 4a2 2 0 012-2h4a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8z" clip-rule="evenodd" />
                </svg>
                Delete Entry
              </.button>

              <span :if={@readonly_mode} class="text-sm text-gray-500 italic">
                Read-only mode enabled
              </span>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp assign_entry(socket, selected_date) do
    entry = Journal.get_entry_for_date(socket.assigns.user, selected_date)
    base_entry = entry || Journal.blank_entry(socket.assigns.user, selected_date)
    changeset = Journal.change_entry(base_entry, %{})
    today = today_in_timezone(socket.assigns.timezone)
    is_today = Date.compare(selected_date, today) == :eq

    socket
    |> assign(:selected_date, selected_date)
    |> assign(:entry, entry)
    |> assign(:form, to_form(changeset, as: "journal_entry"))
    |> assign(:word_count, JournalEntry.word_count(base_entry.content))
    |> assign(:max_words, JournalEntry.max_words())
    |> assign(:is_today, is_today)
  end

  defp base_entry(socket) do
    socket.assigns.entry || Journal.blank_entry(socket.assigns.user, socket.assigns.selected_date)
  end

  defp parse_date(date_param, timezone) do
    case normalize_local_date(date_param, timezone) do
      {:ok, date} -> date
      {:error, _} -> today_in_timezone(timezone)
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

  defp format_updated_at(nil, _timezone), do: ""

  defp format_updated_at(%DateTime{} = datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, shifted} -> Calendar.strftime(shifted, "%b %d, %Y · %I:%M %p")
      _ -> Calendar.strftime(datetime, "%b %d, %Y · %I:%M %p")
    end
  end
end
