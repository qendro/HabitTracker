defmodule HabitTrackerWeb.SettingsLive do
  use HabitTrackerWeb, :live_view

  def mount(_, _, socket),
    do:
      {:ok,
       assign(socket,
         today: HabitTracker.HealthJournal.Time.today(socket.assigns.current_scope.user.timezone)
       )}

  def handle_event("preferences", %{"user" => attrs}, socket) do
    case HabitTracker.Accounts.update_user_timezone(socket.assigns.current_scope.user, attrs) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_scope, HabitTracker.Accounts.Scope.for_user(user))
         |> put_flash(:info, "Settings saved.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Choose a valid IANA timezone.")}
    end
  end

  def render(assigns) do
    ~H"""
    <span id="connection-monitor" phx-hook="Connection" hidden></span>
    <h1>Settings</h1>
    <Layouts.flash_group flash={@flash} />
    <.form for={%{}} phx-submit="preferences" id="preferences">
      <label>
        Timezone<input
          name="user[timezone]"
          value={@current_scope.user.timezone}
          list="timezones"
          required
        />
      </label>
      <datalist id="timezones"><option :for={zone <- Tzdata.zone_list()} value={zone} /></datalist>
      <input type="hidden" name="user[hide_previews]" value="false" />
      <label>
        <input
          type="checkbox"
          name="user[hide_previews]"
          value="true"
          checked={@current_scope.user.hide_previews}
        /> Hide image previews
      </label>
      <button>Save preferences</button>
    </.form>
    <h2>Change password</h2>
    <.form for={%{}} action={~p"/users/update-password"} id="password-form">
      <label>
        Current password<input
          type="password"
          name="user[current_password]"
          autocomplete="current-password"
          required
        />
      </label>
      <label>
        New password<input
          type="password"
          name="user[password]"
          autocomplete="new-password"
          minlength="8"
          maxlength="72"
          required
        />
      </label>
      <label>
        Confirm new password<input
          type="password"
          name="user[password_confirmation]"
          autocomplete="new-password"
          required
        />
      </label>
      <button>Change password</button>
    </.form>
    <h2>Export your data</h2>
    <.form for={%{}} action={~p"/export"} method="get" id="export-form">
      <label>From<input type="date" name="from" required /></label>
      <label>Through<input type="date" name="to" value={@today} required /></label>
      <button>Download ZIP</button>
    </.form>
    <h2>Home-screen app and drafts</h2>
    <p>
      In Safari, use Share → Add to Home Screen. Saving requires a connection. Text, ratings and time drafts are stored in this tab for 24 hours, isolated per account. Photos are not stored in drafts: reselect them after reload or interrupted upload.
    </p>
    <.link href={~p"/users/log-out"} method="delete" data-logout="true">
      Log out and clear drafts in this tab
    </.link>
    """
  end
end
