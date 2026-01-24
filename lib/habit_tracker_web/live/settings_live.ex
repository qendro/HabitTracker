defmodule HabitTrackerWeb.SettingsLive do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:user, user)
     |> assign(:timezone_form, to_form(Accounts.change_user_timezone(user, %{})))
     |> assign(:theme, user.theme)
     |> assign(:timezones, get_timezones())
     |> assign_reminder_settings(user)}
  end

  defp assign_reminder_settings(socket, user) do
    reminder_settings = HabitTracker.Reminders.get_reminder_settings(user)
    habits = HabitTracker.Tracker.list_active_habits(user)

    socket
    |> assign(:reminder_settings, reminder_settings)
    |> assign(:reminder_form, to_form(HabitTracker.Reminders.ReminderSettings.changeset(reminder_settings, %{})))
    |> assign(:habits, habits)
  end

  @impl true
  def handle_event("update_timezone", %{"user" => user_params}, socket) do
    user = socket.assigns.user

    case Accounts.update_user_timezone(user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Timezone updated successfully")
         |> assign(:user, updated_user)
         |> assign(:timezone_form, to_form(Accounts.change_user_timezone(updated_user, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :timezone_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("update_theme", %{"theme" => theme}, socket) do
    user = socket.assigns.user

    case Accounts.update_user_theme(user, theme) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Theme updated successfully")
         |> assign(:user, updated_user)
         |> assign(:theme, updated_user.theme)
         |> push_event("theme-changed", %{theme: updated_user.theme})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update theme")}
    end
  end

  @impl true
  def handle_event("toggle_reminders", _params, socket) do
    user = socket.assigns.user
    current_enabled = socket.assigns.reminder_settings.enabled

    case HabitTracker.Reminders.update_reminder_settings(user, %{enabled: !current_enabled}) do
      {:ok, updated_settings} ->
        {:noreply,
         socket
         |> put_flash(:info, if(!current_enabled, do: "Reminders enabled", else: "Reminders disabled"))
         |> assign(:reminder_settings, updated_settings)
         |> assign(:reminder_form, to_form(HabitTracker.Reminders.ReminderSettings.changeset(updated_settings, %{})))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update reminder settings")}
    end
  end

  @impl true
  def handle_event("update_reminders", %{"reminder_settings" => reminder_params}, socket) do
    user = socket.assigns.user

    case HabitTracker.Reminders.update_reminder_settings(user, reminder_params) do
      {:ok, updated_settings} ->
        {:noreply,
         socket
         |> put_flash(:info, "Reminder settings updated successfully")
         |> assign(:reminder_settings, updated_settings)
         |> assign(:reminder_form, to_form(HabitTracker.Reminders.ReminderSettings.changeset(updated_settings, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :reminder_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_reminders", %{"reminder_settings" => reminder_params}, socket) do
    reminder_settings = socket.assigns.reminder_settings

    changeset =
      reminder_settings
      |> HabitTracker.Reminders.ReminderSettings.changeset(reminder_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :reminder_form, to_form(changeset))}
  end

  @impl true
  def handle_event("request_deletion", _params, socket) do
    {:noreply, assign(socket, :show_deletion_modal, true)}
  end

  @impl true
  def handle_event("cancel_deletion", _params, socket) do
    {:noreply, assign(socket, :show_deletion_modal, false)}
  end

  @impl true
  def handle_event("confirm_deletion", _params, socket) do
    user = socket.assigns.user

    case Accounts.soft_delete_user(user) do
      {:ok, _deleted_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your account has been deleted. You will be logged out.")
         |> redirect(to: ~p"/users/log-out")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_deletion_modal, false)
         |> put_flash(:error, "Failed to delete account. Please try again.")}
    end
  end

  defp get_timezones do
    Tzdata.zone_list()
    |> Enum.sort()
  end
end
